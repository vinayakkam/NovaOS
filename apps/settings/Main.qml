/*
    TwilightOS Settings: a Windows-style settings app for TwilightOS (Plasma).
    Common settings are handled here directly through twilightos-settings-helper;
    deeper options open the matching KDE settings module.

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.plasma5support as P5Support

QQC2.ApplicationWindow {
    id: app
    width: 1120
    height: 740
    minimumWidth: 860
    minimumHeight: 560
    visible: true

    // Wayland app id = reversed organisation domain + executable name ("qml" for both
    // TwilightOS apps), so each app sets its own domain before its window is shown:
    // org.twilightos.settings.qml
    readonly property bool appIdentity: { Qt.application.domain = "settings.twilightos.org"; Qt.application.name = "TwilightOS Settings"; return true; }
    title: "Settings"
    color: base

    // ---------------- Twilight tokens ----------------
    readonly property color base: Kirigami.Theme.backgroundColor
    readonly property color side: Qt.darker(Kirigami.Theme.backgroundColor, 1.06)
    readonly property color card: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.045)
    readonly property color cardHover: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.075)
    readonly property color border: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.07)
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color subtext: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.66)
    readonly property color dim: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
    // Follows the system accent colour, so changes show up immediately
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accent2: Qt.lighter(accent, 1.3)
    readonly property string helper: "/usr/local/bin/twilightos-settings-helper"

    property string page: {
        const a = Qt.application.arguments;
        const known = ["home", "system", "bluetooth", "network", "personalisation", "taskbar", "apps", "accounts", "privacy", "time", "update"];
        for (let i = 0; i < a.length; i++) if (known.includes(a[i])) return a[i];
        return "home";
    }

    // ---------------- State (filled from the helper) ----------------
    property var sys: ({})
    property var net: ({})
    property var wifiList: []
    property string bt: "none"
    property var btDevices: []
    property int volume: 0
    property bool muted: false
    property string sink: ""
    property var display: ({})
    property bool night: false
    property var theme: ({})
    property var wallpapers: []
    property var time: ({})
    property var power: ({})
    property var qs: ({})        // dnd etc. (qs-status)
    property var mic: ({})
    property var privacy: ({})
    property var storage: ({})
    property var panel: ({})

    KCoreAddons.KUser { id: kuser }

    // ---------------- Shell runner ----------------
    P5Support.DataSource {
        id: sh
        engine: "executable"
        property int seq: 0
        property var callbacks: ({})
        onNewData: (source, data) => {
            const cb = callbacks[source];
            delete callbacks[source];
            disconnectSource(source);
            if (cb) cb(String(data.stdout || "").trim());
        }
        function run(args, cb) {
            const src = app.helper + " " + args + "  # " + (++seq);
            callbacks[src] = cb || null;
            connectSource(src);
        }
    }
    function kv(text) {
        const o = {};
        text.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); });
        return o;
    }
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    // kdeglobals stores the accent as "r,g,b"
    function accentHex() {
        const p = String(theme.accent || "242,104,58").split(",").map(v => Math.max(0, Math.min(255, parseInt(v) || 0)));
        return "#" + p.map(v => v.toString(16).padStart(2, "0")).join("");
    }
    function open(cmd) { sh.run("open " + cmd); }
    function kcm(name) { open("kcmshell6 " + name); }

    function refresh(which) {
        if (which === "all" || which === "sys") sh.run("sysinfo", t => app.sys = kv(t));
        if (which === "all" || which === "net") {
            sh.run("net-status", t => app.net = kv(t));
            sh.run("wifi-list", t => app.wifiList = t ? t.split("\n").map(l => { const p = l.split(":"); return { active: p[0] === "*", signal: +p[1], secure: p[2] !== "", ssid: p.slice(3).join(":") }; }) : []);
        }
        if (which === "all" || which === "bt") {
            sh.run("bt-status", t => app.bt = kv(t).bt || "none");
            sh.run("bt-devices", t => app.btDevices = t ? t.split("\n") : []);
        }
        if (which === "all" || which === "sound") sh.run("vol-get", t => { const o = kv(t); app.volume = +o.vol || 0; app.muted = o.muted === "yes"; app.sink = o.sink || ""; });
        if (which === "all" || which === "display") {
            sh.run("display-get", t => app.display = kv(t));
            sh.run("night-get", t => app.night = kv(t).night === "true");
        }
        if (which === "all" || which === "theme") sh.run("theme-get", t => app.theme = kv(t));
        if (which === "all" || which === "wall") sh.run("wallpapers", t => app.wallpapers = t ? t.split("\n") : []);
        if (which === "all" || which === "time") sh.run("time-get", t => app.time = kv(t));
        if (which === "all" || which === "power") sh.run("power-get", t => app.power = kv(t));
        if (which === "all" || which === "qs") sh.run("qs-status", t => app.qs = kv(t));
        if (which === "all" || which === "sound") sh.run("mic-get", t => app.mic = kv(t));
        if (which === "all" || which === "privacy") sh.run("privacy-get", t => app.privacy = kv(t));
        if (which === "all" || which === "storage") sh.run("storage-get", t => app.storage = kv(t));
        if (which === "all" || which === "panel") sh.run("panel-get", t => app.panel = kv(t));
    }
    Component.onCompleted: refresh("all")
    Timer { interval: 8000; running: app.active; repeat: true; onTriggered: { refresh("net"); refresh("bt"); } }

    // ---------------- Navigation model ----------------
    readonly property var pages: [
        { id: "home",            title: "Home",                  icon: "go-home" },
        { id: "system",          title: "System",                icon: "computer" },
        { id: "bluetooth",       title: "Bluetooth & devices",   icon: "preferences-system-bluetooth" },
        { id: "network",         title: "Network & internet",    icon: "network-wireless" },
        { id: "personalisation", title: "Personalisation",       icon: "preferences-desktop-theme-global" },
        { id: "taskbar",         title: "Taskbar",               icon: "preferences-desktop-taskbar" },
        { id: "apps",            title: "Apps",                  icon: "view-app-grid" },
        { id: "accounts",        title: "Accounts",              icon: "system-switch-user" },
        { id: "privacy",         title: "Privacy & security",    icon: "security-high" },
        { id: "time",            title: "Time & language",       icon: "preferences-system-time" },
        { id: "update",          title: "Update",                icon: "system-software-update" }
    ]
    function pageTitle(id) { const p = pages.find(x => x.id === id); return p ? p.title : ""; }

    // ================= Components =================
    component Label: Text {
        color: app.textColor
        font.family: "Inter"
        font.pixelSize: 14
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    component Sub: Label { color: app.subtext; font.pixelSize: 12 }
    component Heading: Label { font.pixelSize: 15; font.weight: Font.DemiBold; Layout.topMargin: 14; Layout.bottomMargin: 2 }

    // A Windows-style settings row: icon, title/subtitle, control on the right.
    component Setting: Rectangle {
        id: row
        property string icon
        property string title
        property string subtitle
        property bool chevron: false
        property bool first: true
        property bool last: true
        default property alias control: slot.data
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: Math.max(64, col.implicitHeight + 24)
        radius: 8
        color: area.containsMouse && row.chevron ? app.cardHover : app.card
        border.color: app.border
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.chevron ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: row.clicked()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 16
            // icon chip: TwilightOS line icon in the accent colour on a soft accent tile
            Rectangle {
                visible: row.icon !== ""
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 10
                color: Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.16)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    source: row.icon + "-symbolic"
                    fallback: row.icon
                    isMask: true
                    color: app.accent
                }
            }
            ColumnLayout {
                id: col
                spacing: 2
                Layout.fillWidth: true
                Label { text: row.title; Layout.fillWidth: true }
                Sub { text: row.subtitle; visible: text !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
            }
            RowLayout { id: slot; spacing: 10 }
            Kirigami.Icon { visible: row.chevron; source: "go-next"; isMask: true; color: app.subtext; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
        }
    }

    // "on" stays bound to the real state; "shown" flips instantly on click and
    // re-syncs whenever the real state is refreshed.
    component Toggle: RowLayout {
        id: tg
        property bool on: false
        property bool shown: on
        onOnChanged: shown = on
        signal toggled(bool on)
        spacing: 10
        Sub { text: tg.shown ? "On" : "Off" }
        Rectangle {
            implicitWidth: 42; implicitHeight: 22; radius: 11
            color: tg.shown ? app.accent : "transparent"
            border.color: tg.shown ? app.accent : app.subtext
            border.width: 1.5
            Behavior on color { ColorAnimation { duration: 140 } }
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: tg.shown ? parent.width - width - 4 : 4
                color: tg.shown ? "#ffffff" : app.subtext
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { tg.shown = !tg.shown; tg.toggled(tg.shown); } }
        }
    }

    component Button: Rectangle {
        id: b
        property string text
        property bool primary: false
        signal clicked()
        implicitWidth: bl.implicitWidth + 28
        implicitHeight: 32
        radius: 6
        color: b.primary ? (ba.containsMouse ? Qt.lighter(app.accent, 1.08) : app.accent) : (ba.containsMouse ? app.cardHover : Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.07))
        border.color: b.primary ? "transparent" : app.border
        Label { id: bl; anchors.centerIn: parent; text: b.text; font.pixelSize: 13; color: b.primary ? "#ffffff" : app.textColor }
        MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    component Choice: Rectangle {
        id: ch
        property string text
        property bool selected: false
        signal clicked()
        implicitWidth: chl.implicitWidth + 24
        implicitHeight: 32
        radius: 16
        color: ch.selected ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.22) : (cha.containsMouse ? app.cardHover : Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.06))
        border.color: ch.selected ? app.accent : app.border
        Label { id: chl; anchors.centerIn: parent; text: ch.text; font.pixelSize: 13 }
        MouseArea { id: cha; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }

    component Page: Flickable {
        default property alias content: pageCol.data
        contentHeight: pageCol.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
        ColumnLayout {
            id: pageCol
            width: Math.min(parent.width - 56, 980)
            x: 28
            y: 4
            spacing: 4
        }
    }

    // ================= Layout =================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Sidebar ----------
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: app.side

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                // Account card
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12
                    spacing: 14
                    Kirigami.Avatar {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        source: kuser.faceIconUrl.toString() !== "" ? kuser.faceIconUrl : "file:///usr/share/pixmaps/twilightos-avatar.png"
                        name: kuser.fullName || kuser.loginName
                    }
                    ColumnLayout {
                        spacing: 2
                        Label { text: kuser.fullName || kuser.loginName; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Sub { text: "Local account"; Layout.fillWidth: true }
                    }
                }

                // Search
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Layout.bottomMargin: 8
                    radius: 6
                    color: Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.06)
                    border.color: findField.activeFocus ? app.accent : app.border
                    Kirigami.Icon { id: findIcon; source: "edit-find"; isMask: true; color: app.subtext; width: 16; height: 16; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter }
                    TextInput {
                        id: findField
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: findIcon.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: app.textColor; font.family: "Inter"; font.pixelSize: 13; clip: true
                        selectionColor: app.accent
                        // Enter jumps to the first page whose title or keywords match
                        readonly property var keywords: ({
                            network: "wifi wi-fi internet ethernet vpn proxy airplane",
                            system: "display screen scale night sound volume audio power battery sleep notifications about storage",
                            bluetooth: "bluetooth mouse touchpad keyboard printer phone devices",
                            personalisation: "theme dark light accent colour color wallpaper background fonts icons effects",
                            apps: "apps default startup wine windows programs",
                            accounts: "account user password sign-in lock",
                            time: "time date clock language region typing accessibility",
                            update: "update upgrade snapshot"
                        })
                        onAccepted: {
                            const t = text.trim().toLowerCase();
                            if (!t) return;
                            const byTitle = app.pages.find(p => p.title.toLowerCase().includes(t));
                            const byWord = Object.keys(keywords).find(k => keywords[k].split(" ").some(w => w.startsWith(t)));
                            const id = byTitle ? byTitle.id : byWord;
                            if (id) app.page = id;
                        }
                        Text { visible: !findField.text; text: "Find a setting"; color: app.dim; font: findField.font; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Repeater {
                    model: app.pages
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: app.page === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 6
                        color: current ? Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.07) : (navArea.containsMouse ? Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.04) : "transparent")
                        Rectangle {
                            visible: parent.current
                            width: 3; height: 16; radius: 1.5
                            color: app.accent
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            spacing: 14
                            Kirigami.Icon {
                                source: modelData.icon + "-symbolic"
                                fallback: modelData.icon
                                isMask: true
                                color: parent.parent.current ? app.accent : app.textColor
                                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                            }
                            Label { text: modelData.title; font.pixelSize: 13; Layout.fillWidth: true }
                        }
                        MouseArea { id: navArea; anchors.fill: parent; hoverEnabled: true; onClicked: app.page = modelData.id }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ---------- Content ----------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Label {
                text: app.pageTitle(app.page)
                font.pixelSize: 28
                font.weight: Font.DemiBold
                Layout.leftMargin: 28
                Layout.topMargin: 26
                Layout.bottomMargin: 8
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: app.pages.findIndex(p => p.id === app.page)

                // ===== Home =====
                Page {
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 150
                        radius: 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#1d2a4d" }
                            GradientStop { position: 1; color: "#3a2234" }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 22
                            Image { source: "file:///usr/share/pixmaps/twilightos-avatar.png"; Layout.preferredWidth: 96; Layout.preferredHeight: 96; sourceSize: Qt.size(192, 192) }
                            ColumnLayout {
                                spacing: 4
                                Label { text: app.sys.hostname || "twilightos"; font.pixelSize: 22; font.weight: Font.DemiBold }
                                Sub { text: (app.sys.product || "TwilightOS") + " " + (app.sys.version || "") + "  ·  Plasma " + (app.sys.plasma || "") }
                                Sub { text: (app.sys.cpu || "") }
                                Button { text: "Rename"; Layout.topMargin: 6; onClicked: app.kcm("kcm_about-distro") }
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10
                        Setting {
                            icon: "network-wireless"; title: "Network"
                            subtitle: app.net.connection ? "Connected to " + app.net.connection : "Not connected"
                            chevron: true; onClicked: app.page = "network"
                        }
                        Setting {
                            icon: "preferences-system-bluetooth"; title: "Bluetooth"
                            subtitle: app.bt === "none" ? "No adapter" : (app.bt === "on" ? "On" : "Off")
                            chevron: true; onClicked: app.page = "bluetooth"
                        }
                        Setting {
                            icon: "preferences-desktop-theme-global"; title: "Personalisation"
                            subtitle: "Theme, accent colour, wallpaper"
                            chevron: true; onClicked: app.page = "personalisation"
                        }
                        Setting {
                            icon: "audio-volume-high"; title: "Volume"
                            subtitle: app.muted ? "Muted" : app.volume + "%"
                            chevron: true; onClicked: app.page = "system"
                        }
                    }
                }

                // ===== System =====
                Page {
                    Heading { text: "Display" }
                    Setting {
                        icon: "preferences-desktop-display"; title: "Scale"
                        subtitle: (app.display.output || "") + (app.display.mode ? "  ·  " + app.display.mode + " Hz" : "")
                        Repeater {
                            model: [1, 1.25, 1.5, 1.75, 2]
                            delegate: Choice {
                                required property var modelData
                                text: Math.round(modelData * 100) + "%"
                                selected: Math.abs((+app.display.scale || 1) - modelData) < 0.01
                                onClicked: sh.run("scale-set " + modelData, () => app.refresh("display"))
                            }
                        }
                    }
                    Setting {
                        icon: "redshift-status-on"; title: "Night light"; subtitle: "Warmer colours to help you sleep"
                        Toggle { on: app.night; onToggled: (v) => sh.run("night-set " + v, () => app.refresh("display")) }
                    }
                    Setting { icon: "preferences-desktop-display"; title: "Advanced display settings"; subtitle: "Resolution, refresh rate, multiple displays"; chevron: true; onClicked: app.kcm("kcm_kscreen") }

                    Heading { text: "Sound" }
                    Setting {
                        icon: app.muted ? "audio-volume-muted" : "audio-volume-high"
                        title: "Volume"; subtitle: app.sink || "Output device"
                        QQC2.Slider {
                            from: 0; to: 100; stepSize: 1
                            value: app.volume
                            Layout.preferredWidth: 220
                            onMoved: { app.volume = value; sh.run("vol-set " + Math.round(value)); }
                        }
                        Label { text: app.volume + "%"; Layout.preferredWidth: 42; font.pixelSize: 13 }
                        Button { text: app.muted ? "Unmute" : "Mute"; onClicked: sh.run("mute-toggle", () => app.refresh("sound")) }
                    }
                    Setting {
                        icon: app.mic.micmuted === "yes" ? "microphone-sensitivity-muted" : "microphone-sensitivity-high"
                        title: "Microphone"; subtitle: "Input volume"
                        QQC2.Slider {
                            from: 0; to: 100; stepSize: 1
                            value: +app.mic.mic || 0
                            Layout.preferredWidth: 220
                            onMoved: sh.run("mic-set " + Math.round(value))
                        }
                        Label { text: (+app.mic.mic || 0) + "%"; Layout.preferredWidth: 42; font.pixelSize: 13 }
                    }
                    Setting { icon: "audio-card"; title: "More sound settings"; subtitle: "Devices, per-app volume"; chevron: true; onClicked: app.kcm("kcm_pulseaudio") }

                    Heading { text: "Notifications" }
                    Setting {
                        icon: app.qs.dnd === "on" ? "notifications-disabled" : "preferences-desktop-notification-bell"
                        title: "Do not disturb"; subtitle: "Silence pop-up notifications (they still go to the bell)"
                        Toggle { on: app.qs.dnd === "on"; onToggled: (v) => sh.run("dnd-set " + (v ? "on" : "off"), () => app.refresh("qs")) }
                    }
                    Setting { icon: "preferences-desktop-notification-bell"; title: "Notification settings"; subtitle: "Which apps can notify, sounds, pop-up position"; chevron: true; onClicked: app.kcm("kcm_notifications") }

                    Heading { text: "Storage" }
                    Setting {
                        icon: "drive-harddisk"
                        title: "System drive"
                        subtitle: (app.storage.root_used || "?") + " used of " + (app.storage.root_size || "?")
                        Rectangle {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 8
                            radius: 4
                            color: Qt.rgba(app.textColor.r, app.textColor.g, app.textColor.b, 0.1)
                            Rectangle {
                                height: parent.height
                                radius: 4
                                width: parent.width * Math.min(1, (parseInt(app.storage.root_pct) || 0) / 100)
                                color: (parseInt(app.storage.root_pct) || 0) > 85 ? "#ff6b81" : app.accent
                            }
                        }
                        Label { text: app.storage.root_pct || ""; font.pixelSize: 13; Layout.preferredWidth: 42 }
                    }
                    Setting {
                        icon: "edit-clear-history"
                        title: "Clean up"
                        subtitle: "Thumbnail cache " + (app.storage.cache || "0") + " · Trash " + (app.storage.trash || "0")
                        Button { text: "Clean now"; onClicked: sh.run("storage-clean", () => app.refresh("storage")) }
                    }

                    Heading { text: "Power" }
                    Setting {
                        icon: "battery-full"; title: "Power mode"
                        subtitle: app.power.battery ? "Battery " + app.power.battery : "Plugged in"
                        visible: app.power.profile !== undefined && app.power.profile !== "none"
                        Repeater {
                            model: [["power-saver", "Efficiency"], ["balanced", "Balanced"], ["performance", "Performance"]]
                            delegate: Choice {
                                required property var modelData
                                text: modelData[1]
                                selected: app.power.profile === modelData[0]
                                onClicked: sh.run("power-set " + modelData[0], () => app.refresh("power"))
                            }
                        }
                    }
                    Setting { icon: "preferences-system-power-management"; title: "Screen and sleep"; subtitle: "When to turn off the screen and sleep"; chevron: true; onClicked: app.kcm("kcm_powerdevilprofilesconfig") }

                    Heading { text: "About" }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: aboutGrid.implicitHeight + 32
                        radius: 8
                        color: app.card
                        border.color: app.border
                        GridLayout {
                            id: aboutGrid
                            anchors.fill: parent
                            anchors.margins: 16
                            columns: 2
                            columnSpacing: 30
                            rowSpacing: 8
                            Repeater {
                                model: [["Device name", "hostname"], ["Processor", "cpu"], ["Cores", "cores"], ["Memory", "ram"], ["Graphics", "gpu"],
                                        ["Storage", "disk"], ["Edition", "product"], ["Version", "version"], ["Kernel", "kernel"], ["Up for", "uptime"]]
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.columnSpan: 2
                                    Sub { text: modelData[0]; Layout.preferredWidth: 140 }
                                    Label { text: app.sys[modelData[1]] || "—"; font.pixelSize: 13; Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }

                // ===== Bluetooth & devices =====
                Page {
                    Setting {
                        icon: "preferences-system-bluetooth"; title: "Bluetooth"
                        subtitle: app.bt === "none" ? "No Bluetooth adapter found" : "Discoverable as \"" + (app.sys.hostname || "twilightos") + "\""
                        Toggle { visible: app.bt !== "none"; on: app.bt === "on"; onToggled: (v) => sh.run("bt-set " + (v ? "on" : "off"), () => app.refresh("bt")) }
                    }
                    Setting { icon: "list-add"; title: "Add device"; subtitle: "Headphones, keyboards, phones and more"; chevron: true; visible: app.bt === "on"; onClicked: app.open("bluedevil-wizard") }
                    Heading { text: "Paired devices"; visible: app.btDevices.length > 0 }
                    Repeater {
                        model: app.btDevices
                        delegate: Setting { required property string modelData; icon: "preferences-system-bluetooth"; title: modelData; chevron: true; onClicked: app.kcm("kcm_bluetooth") }
                    }
                    Heading { text: "Devices" }
                    Setting { icon: "input-mouse"; title: "Mouse"; subtitle: "Pointer speed, buttons, scrolling"; chevron: true; onClicked: app.kcm("kcm_mouse") }
                    Setting { icon: "input-touchpad"; title: "Touchpad"; subtitle: "Tap to click, gestures, natural scrolling"; chevron: true; onClicked: app.kcm("kcm_touchpad") }
                    Setting { icon: "input-keyboard"; title: "Keyboard"; subtitle: "Layouts, repeat rate"; chevron: true; onClicked: app.kcm("kcm_keyboard") }
                    Setting { icon: "printer"; title: "Printers & scanners"; chevron: true; onClicked: app.kcm("kcm_printer_manager") }
                    Setting { icon: "smartphone"; title: "Phone link (KDE Connect)"; subtitle: "Share files, notifications and clipboard with your phone"; chevron: true; onClicked: app.kcm("kcm_kdeconnect") }
                }

                // ===== Network & internet =====
                Page {
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 96
                        radius: 10
                        color: app.card
                        border.color: app.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 18
                            Kirigami.Icon { source: app.net.type === "ethernet" ? "network-wired" : "network-wireless"; Layout.preferredWidth: 48; Layout.preferredHeight: 48 }
                            ColumnLayout {
                                spacing: 2
                                Label { text: app.net.connection || "Not connected"; font.pixelSize: 18; font.weight: Font.DemiBold }
                                Sub { text: app.net.connection ? (app.net.type === "ethernet" ? "Ethernet  ·  Connected" : "Wi-Fi  ·  Connected") : "Choose a network below" }
                            }
                            Item { Layout.fillWidth: true }
                            Button { text: "Properties"; onClicked: app.kcm("kcm_networkmanagement") }
                        }
                    }
                    Setting {
                        icon: "network-wireless"; title: "Wi-Fi"; subtitle: "Connect, manage known networks"
                        Toggle { on: app.net.wifi === "enabled"; onToggled: (v) => sh.run("wifi-set " + (v ? "on" : "off"), () => app.refresh("net")) }
                    }
                    Setting {
                        icon: "airplane-mode"; title: "Airplane mode"; subtitle: "Stop all wireless communication"
                        Toggle { on: app.net.wifi === "disabled" && app.bt !== "on"; onToggled: (v) => sh.run("airplane-set " + (v ? "on" : "off"), () => { app.refresh("net"); app.refresh("bt"); }) }
                    }
                    Heading { text: "Available networks"; visible: app.wifiList.length > 0 }
                    Repeater {
                        model: app.wifiList
                        delegate: Setting {
                            required property var modelData
                            icon: modelData.signal > 66 ? "network-wireless-signal-excellent" : modelData.signal > 33 ? "network-wireless-signal-ok" : "network-wireless-signal-weak"
                            title: modelData.ssid
                            subtitle: (modelData.active ? "Connected  ·  " : "") + (modelData.secure ? "Secured" : "Open")
                            chevron: !modelData.active
                            onClicked: app.kcm("kcm_networkmanagement")
                        }
                    }
                    Heading { text: "More" }
                    Setting { icon: "network-vpn"; title: "VPN"; chevron: true; onClicked: app.kcm("kcm_networkmanagement") }
                    Setting { icon: "preferences-system-network-proxy"; title: "Proxy"; chevron: true; onClicked: app.kcm("kcm_proxy") }
                }

                // ===== Personalisation =====
                Page {
                    Heading { text: "Theme" }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Repeater {
                            model: [["Twilight", "Dark", "#0d1428", "#1d2a4d"], ["TwilightLight", "Light", "#f6f4f0", "#ffffff"]]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool current: (app.theme.scheme || "Twilight") === modelData[0]
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 140
                                radius: 10
                                color: modelData[2]
                                border.width: current ? 2 : 1
                                border.color: current ? app.accent : app.border
                                Rectangle { x: 18; y: 18; width: parent.width - 36; height: 72; radius: 6; color: modelData[3]; border.color: Qt.rgba(0.5, 0.5, 0.5, 0.25)
                                    Rectangle { x: 10; y: 10; width: 60; height: 8; radius: 4; color: app.accent }
                                    Rectangle { x: 10; y: 26; width: 110; height: 6; radius: 3; color: Qt.rgba(0.5, 0.5, 0.6, 0.5) }
                                    Rectangle { x: 10; y: 38; width: 90; height: 6; radius: 3; color: Qt.rgba(0.5, 0.5, 0.6, 0.35) } }
                                Text { text: modelData[1]; x: 18; y: 104; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.Medium; color: modelData[0] === "Twilight" ? "#f1eee6" : "#1b1b1f" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sh.run("theme-set " + modelData[0], () => app.refresh("theme")) }
                            }
                        }
                    }

                    Heading { text: "Accent colour" }
                    Setting {
                        icon: "preferences-desktop-color"; title: "Accent colour"; subtitle: "Used for highlights, selections and toggles"
                        Repeater {
                            model: ["#f2683a", "#f3b651", "#6c8cff", "#5eb7d0", "#5fd39b", "#a46bff", "#ff6b81"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 26; height: 26; radius: 13
                                color: modelData
                                border.width: 2
                                border.color: app.accentHex() === modelData ? "#ffffff" : "transparent"
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sh.run("accent-set " + app.q(modelData), () => app.refresh("theme")) }
                            }
                        }
                    }

                    Heading { text: "Background" }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: app.wallpapers
                            delegate: Rectangle {
                                required property string modelData
                                width: 176; height: 100; radius: 8
                                color: app.card
                                clip: true
                                border.color: wpArea.containsMouse ? app.accent : app.border
                                border.width: wpArea.containsMouse ? 2 : 1
                                Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + modelData; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(352, 200); asynchronous: true }
                                MouseArea { id: wpArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sh.run("wallpaper-set " + app.q(modelData)) }
                            }
                        }
                    }
                    Setting { icon: "preferences-desktop-wallpaper"; title: "Browse for a picture"; subtitle: "Or right-click the desktop › Configure Desktop"; chevron: true; onClicked: app.open("dolphin \"$HOME/Pictures\"") }

                    Heading { text: "More" }
                    Setting { icon: "preferences-desktop-font"; title: "Fonts"; chevron: true; onClicked: app.kcm("kcm_fonts") }
                    Setting { icon: "preferences-desktop-icons"; title: "Icons"; chevron: true; onClicked: app.kcm("kcm_icons") }
                    Setting { icon: "preferences-desktop-effects"; title: "Effects and animations"; subtitle: "Blur, window animations"; chevron: true; onClicked: app.kcm("kcm_kwin_effects") }
                    Setting { icon: "preferences-system-windows"; title: "Window behaviour"; subtitle: "Snapping, focus, title bar buttons"; chevron: true; onClicked: app.kcm("kcm_kwinoptions") }
                }

                // ===== Taskbar =====
                Page {
                    Heading { text: "Top bar" }
                    Setting {
                        icon: "preferences-desktop-panel"
                        title: "Floating top bar"
                        subtitle: "Float with a small gap over the desktop; snaps to the edge when a window is maximised"
                        Toggle { on: app.panel.topfloating === "true"; onToggled: (v) => sh.run("panel top-floating " + (v ? "on" : "off"), () => app.refresh("panel")) }
                    }
                    Heading { text: "Dock" }
                    Setting {
                        icon: "preferences-desktop-taskbar"
                        title: "Dock behaviour"
                        subtitle: "How the dock reacts to windows"
                        Repeater {
                            model: [["always", "none", "Always show"], ["autohide", "autohide", "Auto-hide"], ["dodge", "dodgewindows", "Move out of the way (experimental)"]]
                            delegate: Choice {
                                required property var modelData
                                text: modelData[2]
                                selected: app.panel.dock === modelData[1]
                                onClicked: sh.run("panel dock " + modelData[0], () => app.refresh("panel"))
                            }
                        }
                    }
                    Setting { icon: "view-app-grid"; title: "Pinned apps"; subtitle: "Drag apps onto the dock to pin them; right-click a dock icon to unpin"; chevron: false }
                    Heading { text: "Search" }
                    Setting { icon: "system-search"; title: "Search shortcut"; subtitle: "Meta+Space or start typing on the desktop. Choose what search finds"; chevron: true; onClicked: app.kcm("kcm_plasmasearch") }
                    Setting { icon: "preferences-desktop-effects"; title: "Hot corners and gestures"; subtitle: "Top-left corner opens Overview"; chevron: true; onClicked: app.kcm("kcm_kwinscreenedges") }
                }

                // ===== Apps =====
                Page {
                    Setting { icon: "system-software-install"; title: "Installed apps"; subtitle: "Install, update and remove apps"; chevron: true; onClicked: app.open("plasma-discover --mode installed") }
                    Setting { icon: "preferences-desktop-default-applications"; title: "Default apps"; subtitle: "Browser, email, file manager, terminal"; chevron: true; onClicked: app.kcm("kcm_componentchooser") }
                    Setting { icon: "system-run"; title: "Startup"; subtitle: "Apps that start when you sign in"; chevron: true; onClicked: app.kcm("kcm_autostart") }
                    Setting { icon: "application-x-ms-dos-executable"; title: "Windows apps"; subtitle: "Configure Wine for .exe and .msi programs"; chevron: true; onClicked: app.open("winecfg") }
                    Setting { icon: "preferences-desktop-filetype-association"; title: "File associations"; chevron: true; onClicked: app.kcm("kcm_filetypes") }
                }

                // ===== Accounts =====
                Page {
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 120
                        radius: 10
                        color: app.card
                        border.color: app.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 20
                            Kirigami.Avatar { Layout.preferredWidth: 80; Layout.preferredHeight: 80; source: kuser.faceIconUrl.toString() !== "" ? kuser.faceIconUrl : "file:///usr/share/pixmaps/twilightos-avatar.png"; name: kuser.fullName || kuser.loginName }
                            ColumnLayout {
                                spacing: 2
                                Label { text: kuser.fullName || kuser.loginName; font.pixelSize: 18; font.weight: Font.DemiBold }
                                Sub { text: kuser.loginName + "  ·  Local account  ·  Administrator" }
                            }
                        }
                    }
                    Setting { icon: "user-identity"; title: "Your info"; subtitle: "Name, picture, password"; chevron: true; onClicked: app.kcm("kcm_users") }
                    Setting { icon: "system-lock-screen"; title: "Sign-in options"; subtitle: "Lock screen, automatic locking"; chevron: true; onClicked: app.kcm("kcm_screenlocker") }
                    Setting { icon: "system-users"; title: "Other users"; subtitle: "Add people who use this PC"; chevron: true; onClicked: app.kcm("kcm_users") }
                }

                // ===== Privacy & security =====
                Page {
                    Heading { text: "Screen lock" }
                    Setting {
                        icon: "system-lock-screen"
                        title: "Lock automatically"
                        subtitle: "After this many minutes without activity"
                        Repeater {
                            model: [[0, "Never"], [5, "5 min"], [10, "10 min"], [30, "30 min"]]
                            delegate: Choice {
                                required property var modelData
                                text: modelData[1]
                                selected: modelData[0] === 0 ? app.privacy.autolock === "false"
                                                             : (app.privacy.autolock !== "false" && +app.privacy.locktimeout === modelData[0])
                                onClicked: sh.run("locktimeout-set " + modelData[0], () => app.refresh("privacy"))
                            }
                        }
                    }
                    Heading { text: "Activity" }
                    Setting {
                        icon: "preferences-system-time"
                        title: "Remember recent files and apps"
                        subtitle: "Used by Start › Jump back in"
                        Toggle { on: app.privacy.recent !== "2"; onToggled: (v) => sh.run("recent-set " + (v ? "on" : "off"), () => app.refresh("privacy")) }
                    }
                    Setting {
                        icon: "edit-clear-history"
                        title: "Clear activity history"
                        subtitle: "Forget recent files and app usage"
                        Button { text: "Clear"; onClicked: sh.run("recent-clear") }
                    }
                    Heading { text: "Search" }
                    Setting {
                        icon: "system-search"
                        title: "Index file contents"
                        subtitle: "Faster file search, but uses memory and disk in the background"
                        Toggle { on: app.privacy.indexing === "true"; onToggled: (v) => sh.run("indexing-set " + (v ? "on" : "off"), () => app.refresh("privacy")) }
                    }
                    Heading { text: "Security" }
                    Setting { icon: "network-vpn"; title: "Firewall"; subtitle: "Allow or block network connections"; chevron: true; onClicked: app.kcm("kcm_firewall") }
                    Setting { icon: "security-high"; title: "Passwords and keys"; subtitle: "Saved passwords (KWallet)"; chevron: true; onClicked: app.kcm("kcm_kwallet5") }
                    Setting { icon: "preferences-system-windows"; title: "App permissions"; subtitle: "Flatpak app access to files, devices and network"; chevron: true; onClicked: app.kcm("kcm_flatpak") }
                }

                // ===== Time & language =====
                Page {
                    Setting { icon: "preferences-system-time"; title: "Date & time"; subtitle: (app.time.tz || "") + (app.time.ntp === "yes" ? "  ·  Set automatically" : ""); chevron: true; onClicked: app.kcm("kcm_clock") }
                    Setting { icon: "preferences-desktop-locale"; title: "Language & region"; subtitle: "Display language, formats"; chevron: true; onClicked: app.kcm("kcm_regionandlang") }
                    Setting { icon: "input-keyboard"; title: "Typing"; subtitle: "Keyboard layouts, spell checking"; chevron: true; onClicked: app.kcm("kcm_keyboard") }
                    Setting { icon: "preferences-desktop-accessibility"; title: "Accessibility"; subtitle: "Screen reader, sticky keys, zoom"; chevron: true; onClicked: app.kcm("kcm_access") }
                }

                // ===== Update =====
                Page {
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 110
                        radius: 10
                        color: app.card
                        border.color: app.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 18
                            Kirigami.Icon { source: "system-software-update"; Layout.preferredWidth: 52; Layout.preferredHeight: 52 }
                            ColumnLayout {
                                spacing: 2
                                Label { text: "TwilightOS Update"; font.pixelSize: 18; font.weight: Font.DemiBold }
                                Sub { text: "Apps and system updates are installed with Discover" }
                            }
                            Item { Layout.fillWidth: true }
                            Button { text: "Check for updates"; primary: true; onClicked: app.open("plasma-discover --mode update") }
                        }
                    }
                    Setting { icon: "edit-undo"; title: "Snapshots"; subtitle: "Btrfs snapshots are taken with Snapper before updates (after install)"; chevron: false }
                    Setting { icon: "help-about"; title: "About TwilightOS"; subtitle: (app.sys.product || "TwilightOS") + " " + (app.sys.version || ""); chevron: true; onClicked: app.page = "system" }
                }
            }
        }
    }
}
