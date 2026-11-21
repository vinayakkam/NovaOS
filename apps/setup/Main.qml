/*
    TwilightOS Setup: installs TwilightOS from the live session to a disk.
    A step-by-step window (language, disk, account, summary, progress, done) that
    drives /usr/local/bin/twilightos-install (run as root through sudo).

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

QQC2.ApplicationWindow {
    id: app
    width: 1000
    height: 660
    minimumWidth: 860
    minimumHeight: 600
    visible: true
    readonly property bool appIdentity: { Qt.application.domain = "setup.twilightos.org"; Qt.application.name = "TwilightOS Setup"; return true; }
    title: "TwilightOS Setup"
    color: base

    // ---------------- tokens ----------------
    readonly property color base: Kirigami.Theme.backgroundColor
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color subtext: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.66)
    readonly property color dim: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
    readonly property color card: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.045)
    readonly property color border: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.09)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color danger: "#ff6b81"
    readonly property string backend: "/usr/local/bin/twilightos-install"

    // the launcher passes --rundir=$XDG_RUNTIME_DIR (a private folder for the password hand-off)
    readonly property string runDir: {
        const a = Qt.application.arguments;
        for (let i = 0; i < a.length; i++) if (a[i].startsWith("--rundir=")) return a[i].slice(9);
        return "/tmp";
    }

    // ---------------- choices ----------------
    property int step: 0            // 0 welcome, 1 disk, 2 account, 3 ready, 4 installing, 5 done, 6 failed
    property string locale: "en_US.UTF-8"
    property string keymap: "us"
    property string timezone: "Asia/Kolkata"
    property var timezones: ["Asia/Kolkata"]
    property var disks: []
    property bool disksLoaded: false
    property string disk: ""
    property int percent: 0
    property string status: ""

    readonly property var steps: ["Language and region", "Where to install", "Your account", "Ready to install", "Installing"]
    readonly property var locales: [
        ["en_US.UTF-8", "English (United States)"], ["en_GB.UTF-8", "English (United Kingdom)"],
        ["en_IN.UTF-8", "English (India)"], ["hi_IN.UTF-8", "हिन्दी (भारत)"],
        ["de_DE.UTF-8", "Deutsch"], ["fr_FR.UTF-8", "Français"], ["es_ES.UTF-8", "Español"],
        ["pt_BR.UTF-8", "Português (Brasil)"], ["it_IT.UTF-8", "Italiano"], ["ja_JP.UTF-8", "日本語"]]
    readonly property var keymaps: [
        ["us", "US"], ["gb", "United Kingdom"], ["in", "India"], ["de", "German"], ["fr", "French"],
        ["es", "Spanish"], ["it", "Italian"], ["br", "Portuguese (Brazil)"], ["jp", "Japanese"]]

    // ---------------- shell runner ----------------
    P5Support.DataSource {
        id: sh
        engine: "executable"
        property int seq: 0
        property var callbacks: ({})
        onNewData: (source, data) => {
            const cb = callbacks[source];
            delete callbacks[source];
            disconnectSource(source);
            if (cb) cb(String(data.stdout || "").trim(), data["exit code"]);
        }
        function run(cmd, cb) {
            const src = cmd + "  # " + (++seq);
            callbacks[src] = cb || null;
            connectSource(src);
        }
    }
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    Component.onCompleted: {
        sh.run("timedatectl list-timezones", out => { if (out) app.timezones = out.split("\n"); });
        sh.run("cat /etc/vconsole.conf 2>/dev/null; readlink /etc/localtime", out => {
            const m = out.match(/zoneinfo\/(.+)$/m);
            if (m) app.timezone = m[1];
        });
        loadDisks();
    }
    function loadDisks() {
        disksLoaded = false;
        sh.run("sudo -n " + backend + " --list-disks", out => {
            try { app.disks = JSON.parse(out || "[]"); } catch (e) { app.disks = []; }
            if (app.disks.length === 1) app.disk = app.disks[0].path;
            app.disksLoaded = true;
        });
    }
    function size(bytes) {
        const gb = bytes / 1e9;
        return gb >= 1000 ? (gb / 1000).toFixed(1) + " TB" : Math.round(gb) + " GB";
    }

    // user name from the full name: "Vinayak Kamath" -> "vinayak"
    function suggestUser(full) {
        const first = String(full).trim().split(/\s+/)[0] || "";
        return first.toLowerCase().normalize("NFD").replace(/[^a-z0-9_-]/g, "").replace(/^[^a-z_]+/, "").slice(0, 31);
    }
    readonly property bool userOk: /^[a-z_][a-z0-9_-]{0,30}$/.test(userField.text) && userField.text !== "root"
    readonly property bool hostOk: /^[A-Za-z0-9-]{1,63}$/.test(hostField.text)
    readonly property bool passOk: passField.text.length >= 4 && passField.text === pass2Field.text
    readonly property bool accountOk: nameField.text.trim() !== "" && userOk && hostOk && passOk

    function startInstall() {
        step = 4;
        percent = 0;
        status = "Starting";
        // hand the password over through a private file, never on a command line
        const pw = runDir + "/twilightos-setup.pw";
        const xhr = new XMLHttpRequest();
        xhr.open("PUT", "file://" + pw, false);
        xhr.send(passField.text + "\n");
        const cmd = "umask 077; sudo -n " + backend
            + " --disk " + q(disk) + " --user " + q(userField.text) + " --fullname " + q(nameField.text.trim())
            + " --hostname " + q(hostField.text) + " --timezone " + q(timezone)
            + " --locale " + q(locale) + " --keymap " + q(keymap)
            + " < " + q(pw) + " 2>&1; rc=$?; rm -f " + q(pw) + "; exit $rc";
        sh.run(cmd, (out, code) => {
            if (code !== 0) { app.status = out || "Setup could not start."; app.step = 6; }
            else poll.start();
        });
    }
    Timer {
        id: poll
        interval: 800
        repeat: true
        onTriggered: sh.run("cat /run/twilightos-install/progress 2>/dev/null", out => {
            const i = out.indexOf("|");
            if (i < 0) return;
            const p = parseInt(out.slice(0, i));
            app.status = out.slice(i + 1);
            if (p < 0) { poll.stop(); app.step = 6; return; }
            app.percent = p;
            if (p >= 100) { poll.stop(); app.step = 5; }
        })
    }

    // ---------------- building blocks ----------------
    component Heading: Text {
        color: app.textColor
        font.family: "Inter"
        font.pixelSize: 26
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    component Body: Text {
        color: app.subtext
        font.family: "Inter"
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        lineHeight: 1.15
        Layout.fillWidth: true
    }
    component FieldLabel: Text {
        color: app.textColor
        font.family: "Inter"
        font.pixelSize: 13
        font.weight: Font.Medium
        Layout.topMargin: 6
    }
    component Button: Rectangle {
        id: b
        property string text
        property bool primary: false
        property bool enabledState: true
        signal clicked()
        implicitWidth: Math.max(112, label.implicitWidth + 40)
        implicitHeight: 38
        radius: 8
        opacity: enabledState ? 1 : 0.45
        color: primary ? (ma.containsMouse && enabledState ? Qt.lighter(app.accent, 1.08) : app.accent)
                       : (ma.containsMouse && enabledState ? Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.1) : app.card)
        border.color: primary ? "transparent" : app.border
        Text { id: label; anchors.centerIn: parent; text: b.text; color: b.primary ? "#ffffff" : app.textColor; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: b.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (b.enabledState) b.clicked() }
    }
    component Choice: QQC2.ComboBox {
        Layout.fillWidth: true
        Layout.maximumWidth: 420
        font.family: "Inter"
    }

    // ---------------- layout: brand rail + page ----------------
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // left rail: brand and the list of steps
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 300
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.darker(app.accent, 1.05) }
                GradientStop { position: 1; color: "#0d1428" }
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 0
                Kirigami.Icon { source: "distributor-logo"; Layout.preferredWidth: 56; Layout.preferredHeight: 56 }
                Text { text: "TwilightOS"; color: "#ffffff"; font.family: "Inter"; font.pixelSize: 24; font.weight: Font.Bold; Layout.topMargin: 14 }
                Text { text: "Setup"; color: Qt.rgba(1, 1, 1, 0.75); font.family: "Inter"; font.pixelSize: 15 }
                Item { Layout.preferredHeight: 36 }
                Repeater {
                    model: app.steps
                    delegate: RowLayout {
                        required property string modelData
                        required property int index
                        readonly property bool current: Math.min(app.step, 4) === index
                        readonly property bool done: app.step > index && app.step !== 6
                        Layout.fillWidth: true
                        Layout.bottomMargin: 16
                        spacing: 12
                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: parent.current ? "#ffffff" : parent.done ? Qt.rgba(1, 1, 1, 0.35) : "transparent"
                            border.color: Qt.rgba(1, 1, 1, parent.current || parent.done ? 0 : 0.4)
                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.done ? "✓" : parent.parent.index + 1
                                color: parent.parent.current ? "#0d1428" : "#ffffff"
                                font.family: "Inter"; font.pixelSize: 12; font.weight: Font.Bold
                            }
                        }
                        Text {
                            text: parent.modelData
                            color: Qt.rgba(1, 1, 1, parent.current ? 1 : 0.7)
                            font.family: "Inter"; font.pixelSize: 14
                            font.weight: parent.current ? Font.DemiBold : Font.Normal
                            Layout.fillWidth: true
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { text: "Your files on other disks are not touched."; color: Qt.rgba(1, 1, 1, 0.6); font.family: "Inter"; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }

        // right: the current page and the button row
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 40
            spacing: 0

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: app.step

                // 0 ---- language, region, keyboard
                ColumnLayout {
                    spacing: 10
                    Heading { text: "Let's set up TwilightOS" }
                    Body { text: "Pick your language, time zone and keyboard. You can change all of these later in Settings." }
                    Item { Layout.preferredHeight: 10 }
                    FieldLabel { text: "Language" }
                    Choice {
                        model: app.locales.map(l => l[1])
                        currentIndex: Math.max(0, app.locales.findIndex(l => l[0] === app.locale))
                        onActivated: (i) => app.locale = app.locales[i][0]
                    }
                    FieldLabel { text: "Time zone" }
                    Choice {
                        model: app.timezones
                        currentIndex: Math.max(0, app.timezones.indexOf(app.timezone))
                        onActivated: (i) => app.timezone = app.timezones[i]
                    }
                    FieldLabel { text: "Keyboard layout" }
                    Choice {
                        model: app.keymaps.map(k => k[1])
                        currentIndex: Math.max(0, app.keymaps.findIndex(k => k[0] === app.keymap))
                        onActivated: (i) => app.keymap = app.keymaps[i][0]
                    }
                    Item { Layout.fillHeight: true }
                }

                // 1 ---- disk
                ColumnLayout {
                    spacing: 10
                    Heading { text: "Where do you want to install TwilightOS?" }
                    Body { text: "TwilightOS will use the whole disk you pick. Everything on it will be erased." }
                    Item { Layout.preferredHeight: 6 }
                    Repeater {
                        model: app.disks
                        delegate: Rectangle {
                            id: dcard
                            required property var modelData
                            readonly property bool picked: app.disk === modelData.path
                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            radius: 10
                            color: picked ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.14) : dma.containsMouse ? Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.07) : app.card
                            border.color: picked ? app.accent : app.border
                            border.width: picked ? 2 : 1
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                spacing: 16
                                Kirigami.Icon { source: dcard.modelData.removable ? "drive-removable-media" : "drive-harddisk"; Layout.preferredWidth: 36; Layout.preferredHeight: 36 }
                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Text { text: dcard.modelData.model; color: app.textColor; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: dcard.modelData.path + (dcard.modelData.bus ? "  ·  " + dcard.modelData.bus.toUpperCase() : "") + (dcard.modelData.removable ? "  ·  removable" : ""); color: app.subtext; font.family: "Inter"; font.pixelSize: 12 }
                                }
                                Text { text: app.size(dcard.modelData.size); color: app.textColor; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.Medium }
                            }
                            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.disk = dcard.modelData.path }
                        }
                    }
                    Body {
                        visible: app.disksLoaded && app.disks.length === 0
                        color: app.danger
                        text: "No disk of 20 GB or more was found. Add a disk and click Refresh."
                    }
                    Body { visible: !app.disksLoaded; text: "Looking for disks…" }
                    RowLayout {
                        visible: app.disk !== ""
                        spacing: 10
                        Layout.topMargin: 6
                        Kirigami.Icon { source: "dialog-warning"; Layout.preferredWidth: 20; Layout.preferredHeight: 20; color: app.danger; isMask: true }
                        Body { text: "All files, apps and other systems on " + app.disk + " will be permanently deleted."; color: app.danger }
                    }
                    Item { Layout.fillHeight: true }
                    Button { text: "Refresh"; onClicked: app.loadDisks() }
                }

                // 2 ---- account
                ColumnLayout {
                    spacing: 6
                    Heading { text: "Who's going to use this PC?" }
                    Body { text: "This account can install apps and change settings. Use a password you'll remember." }
                    Item { Layout.preferredHeight: 6 }
                    GridLayout {
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 4
                        Layout.fillWidth: true
                        FieldLabel { text: "Your name" }
                        FieldLabel { text: "User name" }
                        QQC2.TextField {
                            id: nameField
                            Layout.fillWidth: true
                            placeholderText: "e.g. Alex Doe"
                            onTextEdited: if (!userField.touched) userField.text = app.suggestUser(text)
                        }
                        QQC2.TextField {
                            id: userField
                            property bool touched: false
                            Layout.fillWidth: true
                            placeholderText: "lowercase, no spaces"
                            onTextEdited: touched = true
                            color: text === "" || app.userOk ? app.textColor : app.danger
                        }
                        FieldLabel { text: "Password" }
                        FieldLabel { text: "Confirm password" }
                        QQC2.TextField { id: passField; Layout.fillWidth: true; echoMode: TextInput.Password }
                        QQC2.TextField { id: pass2Field; Layout.fillWidth: true; echoMode: TextInput.Password }
                        FieldLabel { text: "Computer name" }
                        Item { width: 1; height: 1 }
                        QQC2.TextField {
                            id: hostField
                            Layout.fillWidth: true
                            text: "twilightos-pc"
                            color: app.hostOk ? app.textColor : app.danger
                        }
                    }
                    Body {
                        Layout.topMargin: 8
                        color: app.danger
                        text: pass2Field.text !== "" && passField.text !== pass2Field.text ? "The passwords don't match."
                            : passField.text !== "" && passField.text.length < 4 ? "Use at least 4 characters for the password."
                            : userField.text !== "" && !app.userOk ? "User names use lowercase letters, numbers, - and _, and start with a letter."
                            : !app.hostOk ? "Computer names use letters, numbers and -." : ""
                        visible: text !== ""
                    }
                    Item { Layout.fillHeight: true }
                }

                // 3 ---- summary
                ColumnLayout {
                    spacing: 10
                    Heading { text: "Ready to install" }
                    Body { text: "Check your choices. When you click Install, the disk is erased and TwilightOS is copied to it. This takes about 5–15 minutes." }
                    Item { Layout.preferredHeight: 6 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: summary.implicitHeight + 32
                        radius: 10
                        color: app.card
                        border.color: app.border
                        GridLayout {
                            id: summary
                            anchors.fill: parent
                            anchors.margins: 16
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 10
                            Repeater {
                                model: [
                                    ["Install to", app.disk + "  (" + (app.disks.find(d => d.path === app.disk) || { model: "" }).model + ")"],
                                    ["Disk layout", "EFI system partition + btrfs with snapshots"],
                                    ["Account", nameField.text.trim() + "  (" + userField.text + ")"],
                                    ["Computer name", hostField.text],
                                    ["Language", (app.locales.find(l => l[0] === app.locale) || ["", app.locale])[1]],
                                    ["Time zone", app.timezone],
                                    ["Keyboard", (app.keymaps.find(k => k[0] === app.keymap) || ["", app.keymap])[1]],
                                    ["Boot menu", "TwilightOS bootloader (GRUB)"]]
                                delegate: Item {
                                    required property var modelData
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    implicitHeight: 20
                                    Text { text: parent.modelData[0]; color: app.subtext; font.family: "Inter"; font.pixelSize: 13; width: 150 }
                                    Text { x: 160; width: parent.width - 160; text: parent.modelData[1]; color: app.textColor; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 10
                        Kirigami.Icon { source: "dialog-warning"; Layout.preferredWidth: 20; Layout.preferredHeight: 20; color: app.danger; isMask: true }
                        Body { text: "Everything on " + app.disk + " will be erased."; color: app.danger }
                    }
                    Item { Layout.fillHeight: true }
                }

                // 4 ---- installing
                ColumnLayout {
                    spacing: 14
                    Item { Layout.fillHeight: true }
                    Heading { text: "Installing TwilightOS"; horizontalAlignment: Text.AlignHCenter }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: app.percent + "%"
                        color: app.accent
                        font.family: "Inter"; font.pixelSize: 56; font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 420
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.1)
                        Rectangle {
                            height: parent.height
                            radius: 3
                            color: app.accent
                            width: parent.width * app.percent / 100
                            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        }
                    }
                    Body { text: app.status; horizontalAlignment: Text.AlignHCenter }
                    Body { text: "Your PC will be ready soon. Keep it plugged in and don't turn it off."; color: app.dim; horizontalAlignment: Text.AlignHCenter }
                    Item { Layout.fillHeight: true }
                }

                // 5 ---- done
                ColumnLayout {
                    spacing: 14
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 72; height: 72; radius: 36
                        color: app.accent
                        Text { anchors.centerIn: parent; text: "✓"; color: "#ffffff"; font.pixelSize: 36; font.weight: Font.Bold }
                    }
                    Heading { text: "TwilightOS is installed"; horizontalAlignment: Text.AlignHCenter }
                    Body { text: "Remove the installation media, then restart to start using your new PC. Sign in as " + userField.text + "."; horizontalAlignment: Text.AlignHCenter }
                    Item { Layout.fillHeight: true }
                }

                // 6 ---- failed
                ColumnLayout {
                    spacing: 12
                    Item { Layout.fillHeight: true }
                    Heading { text: "Setup couldn't finish"; horizontalAlignment: Text.AlignHCenter }
                    Body { text: app.status; color: app.danger; horizontalAlignment: Text.AlignHCenter }
                    Body { text: "Nothing else on your PC was changed. The full log is in /run/twilightos-install/install.log."; horizontalAlignment: Text.AlignHCenter }
                    Item { Layout.fillHeight: true }
                }
            }

            // button row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    text: "Back"
                    visible: app.step >= 1 && app.step <= 3
                    onClicked: app.step--
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    visible: app.step <= 3 || app.step === 6
                    onClicked: Qt.quit()
                }
                Button {
                    primary: true
                    visible: app.step <= 3
                    text: app.step === 3 ? "Install" : "Next"
                    enabledState: app.step === 0 || (app.step === 1 && app.disk !== "") || (app.step === 2 && app.accountOk) || app.step === 3
                    onClicked: app.step === 3 ? app.startInstall() : app.step++
                }
                Button {
                    primary: true
                    visible: app.step === 5
                    text: "Restart now"
                    onClicked: sh.run("systemctl reboot")
                }
                Button {
                    visible: app.step === 5
                    text: "Keep exploring"
                    onClicked: Qt.quit()
                }
            }
        }
    }
}
