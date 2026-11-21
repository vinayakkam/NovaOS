/*
    TwilightOS "Dusk" launcher.
      Left  - the "now" panel: clock, search, recent items, you, lock/settings/power.
      Right - the app shelf: category tabs (Favourites, All, Internet, Office, ...)
              over a grid of app bubbles; search results replace the shelf.

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

PlasmoidItem {
    id: root

    // ---------- Twilight tokens ----------
    // Follows the system accent colour (Settings > Personalisation)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accent2: Qt.lighter(accent, 1.3)
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color subtext: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.66)
    readonly property color dim: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
    readonly property color card: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.055)
    readonly property color hover: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.09)
    readonly property color border: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.09)

    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: true
    hideOnWindowDeactivate: true
    Plasmoid.icon: Plasmoid.configuration.icon || "twilightos-start"
    toolTipMainText: i18n("Start")
    toolTipSubText: ""

    property int shelf: -1          // -1 favourites, 0 all apps, n>0 a category row of rootModel
    property string query: ""

    onExpandedChanged: () => {
        if (root.expanded) {
            root.query = "";
            root.shelf = -1;
        }
    }

    // ---------- Data (the same models Kickoff uses) ----------
    // RootModel row 0 is the flat, sorted "All applications" list; its
    // favoritesModel stores the pins (Plasma's activity-aware favourites).
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: root
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: true    // rows after "All applications" are the categories
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        Component.onCompleted: refresh()
    }
    readonly property var appsModel: rootModel.count > 0 ? rootModel.modelForRow(0) : null

    // Pins: a plain list in this widget's config (defaults in config/main.xml),
    // shown through Kicker's simple favourites model (no activity service needed).
    function pinId(id) {
        const s = String(id || "").replace(/^applications:/, "").replace(/^.*\//, "");
        return s.endsWith(".desktop") ? s : s + ".desktop";
    }
    readonly property var pinList: (Plasmoid.configuration.pinned || []).map(p => "applications:" + pinId(p))
    Kicker.SimpleFavoritesModel {
        id: pinsModel
        favorites: root.pinList
    }

    function isPinned(id) { return (Plasmoid.configuration.pinned || []).some(p => pinId(p) === pinId(id)); }
    function togglePin(id) {
        if (!id) return;
        const want = pinId(id);
        const cur = (Plasmoid.configuration.pinned || []).map(p => pinId(p));
        const i = cur.indexOf(want);
        if (i >= 0) cur.splice(i, 1); else cur.push(want);
        Plasmoid.configuration.pinned = cur;
    }

    Kicker.RecentUsageModel {
        id: recentModel
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: root
        mergeResults: true
        query: root.query
        runners: [
            "krunner_services", "krunner_systemsettings", "calculator", "unitconverter",
            "krunner_recentdocuments", "locations", "krunner_sessions", "krunner_powerdevil"
        ]
    }
    readonly property var results: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source) => disconnectSource(source)
        function run(cmd) { connectSource(cmd); root.expanded = false; }
    }

    KCoreAddons.KUser { id: kuser }

    // ---------- Panel button: the Twilight start mark ----------
    // Three rounded tiles and an "orbit" dot; spreads on hover, turns 45° while open.
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property real thickness: vertical ? width : height
        Layout.minimumWidth: vertical ? -1 : thickness
        Layout.preferredWidth: vertical ? -1 : thickness
        Layout.maximumWidth: vertical ? -1 : thickness
        Layout.minimumHeight: vertical ? thickness : -1
        Layout.preferredHeight: vertical ? thickness : -1
        Layout.maximumHeight: vertical ? thickness : -1

        Rectangle {
            anchors.centerIn: parent
            width: compact.thickness * 0.86
            height: width
            radius: width * 0.28
            color: compact.containsMouse || root.expanded ? root.hover : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Item {
            id: mark
            anchors.centerIn: parent
            readonly property real size: Math.round(compact.thickness * 0.5)
            property real gap: root.expanded ? size * 0.16 : (compact.containsMouse ? size * 0.13 : size * 0.09)
            readonly property real tile: (size - gap) / 2
            width: size
            height: size
            rotation: root.expanded ? 45 : 0
            scale: compact.pressed ? 0.86 : (compact.containsMouse ? 1.06 : 1)
            Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on gap { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                x: 0; y: 0
                width: mark.tile; height: width; radius: width * 0.32
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(root.accent, 1.15) }
                    GradientStop { position: 1; color: root.accent }
                }
            }
            Rectangle {
                property real d: mark.tile * (compact.containsMouse || root.expanded ? 0.92 : 0.8)
                width: d; height: d; radius: d / 2
                x: mark.size - mark.tile + (mark.tile - d) / 2
                y: (mark.tile - d) / 2
                color: Qt.lighter(root.accent2, 1.1)
                Behavior on d { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }
            Rectangle {
                x: 0; y: mark.size - mark.tile
                width: mark.tile; height: width; radius: width * 0.32
                gradient: Gradient {
                    GradientStop { position: 0; color: root.accent }
                    GradientStop { position: 1; color: Qt.darker(root.accent, 1.15) }
                }
            }
            Rectangle {
                x: mark.size - mark.tile; y: mark.size - mark.tile
                width: mark.tile; height: width; radius: width * 0.32
                gradient: Gradient {
                    GradientStop { position: 0; color: root.accent2 }
                    GradientStop { position: 1; color: Qt.darker(root.accent2, 1.1) }
                }
            }
        }
    }



    // ---------- Popup ----------
    // the command runs through a shell, so $HOME expands there (KUser has no home folder property)
    function openPath(sub) { exec.run("dolphin \"$HOME" + (sub ? "/" + sub : "") + "\""); }
    function logoutPrompt(kind) {
        exec.run("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt." + kind);
    }
    readonly property var shelfModel: shelf < 0 ? pinsModel : (rootModel.count > shelf ? rootModel.modelForRow(shelf) : null)
    property date now: new Date()
    Timer { interval: 10000; running: root.expanded; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    fullRepresentation: Item {
        id: menu
        Layout.preferredWidth: Kirigami.Units.gridUnit * 46
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        Layout.minimumWidth: Kirigami.Units.gridUnit * 40
        Layout.minimumHeight: Kirigami.Units.gridUnit * 26

        property int selected: 0
        property bool powerOpen: false

        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    search.text = "";
                    menu.powerOpen = false;
                    root.shelf = -1;
                    search.forceActiveFocus();
                }
            }
        }
        function runResult(i) {
            if (root.results && i >= 0 && i < root.results.count) {
                root.results.trigger(i, "", null);
                root.expanded = false;
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ================= Now panel =================
            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                Layout.fillHeight: true
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.30) }
                    GradientStop { position: 0.55; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
                }
                border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit
                    spacing: 10

                    // clock
                    Text {
                        text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
                        color: root.textColor
                        font.family: "Inter"
                        font.pixelSize: 46
                        font.weight: Font.Light
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        Layout.topMargin: -6
                        text: Qt.formatDate(root.now, "dddd, d MMMM")
                        color: root.subtext
                        font.family: "Inter"
                        font.pixelSize: 13
                    }

                    // search
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.preferredHeight: 42
                        radius: 21
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.width: search.activeFocus ? 2 : 1
                        border.color: search.activeFocus ? root.accent : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
                        Kirigami.Icon {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16
                            source: "system-search"
                            color: search.activeFocus ? root.accent : root.subtext
                            isMask: true
                        }
                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.textColor
                            selectionColor: root.accent
                            font.family: "Inter"
                            font.pixelSize: 14
                            clip: true
                            onTextChanged: { root.query = text.trim(); menu.selected = 0; }
                            Keys.onEscapePressed: text ? text = "" : root.expanded = false
                            Keys.onDownPressed: menu.selected = Math.min(menu.selected + 1, (root.results ? root.results.count : 1) - 1)
                            Keys.onUpPressed: menu.selected = Math.max(menu.selected - 1, 0)
                            Keys.onReturnPressed: menu.runResult(menu.selected)
                            Keys.onEnterPressed: menu.runResult(menu.selected)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !search.text
                                text: i18n("Search or calculate")
                                color: root.dim
                                font: search.font
                            }
                        }
                    }

                    // recent
                    Text {
                        Layout.topMargin: 8
                        text: i18n("Recent")
                        color: root.subtext
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        font.capitalization: Font.AllUppercase
                    }
                    ListView {
                        id: recentList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        interactive: false
                        spacing: 2
                        model: recentModel
                        delegate: HoverCard {
                            required property int index
                            required property var model
                            width: recentList.width
                            height: 34
                            radius: 8
                            visible: index < 7
                            onActivated: { recentModel.trigger(index, "", null); root.expanded = false; }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                spacing: 10
                                Kirigami.Icon { source: model.decoration; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                                Text { text: model.display; color: root.textColor; font.family: "Inter"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        Text {
                            visible: recentList.count === 0
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: i18n("Apps and files you open show up here.")
                            color: root.dim
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }

                    // you + session
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1) }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Kirigami.Avatar {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            source: kuser.faceIconUrl.toString() !== "" ? kuser.faceIconUrl : "file:///usr/share/pixmaps/twilightos-avatar.png"
                            name: kuser.fullName || kuser.loginName
                        }
                        Text {
                            text: kuser.fullName || kuser.loginName
                            color: root.textColor
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RoundButton { iconName: "system-lock-screen"; tip: i18n("Lock"); onClicked: exec.run("loginctl lock-session") }
                        RoundButton { iconName: "configure"; tip: i18n("Settings"); onClicked: exec.run("twilightos-settings") }
                        RoundButton { iconName: "system-shutdown"; tip: i18n("Power"); lit: menu.powerOpen; onClicked: menu.powerOpen = !menu.powerOpen }
                    }
                }
            }

            // ================= App shelf =================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.gridUnit
                Layout.topMargin: 4
                spacing: 12

                // category tabs
                ListView {
                    id: tabs
                    visible: root.query === ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    // -1 Favourites, 0 All, 1.. categories (names from the model)
                    model: {
                        const out = [{ row: -1, name: i18n("Favourites") }, { row: 0, name: i18n("All") }];
                        // Only a few broad shelves (everything else is under All / search).
                        const keep = { "Internet": i18n("Internet"), "Office": i18n("Office"), "Multimedia": i18n("Media"), "System": i18n("System") };
                        for (let r = 1; r < rootModel.count; r++) {
                            const name = String(rootModel.labelForRow(r) || "").trim();
                            if (keep[name] !== undefined) out.push({ row: r, name: keep[name] });
                        }
                        return out;
                    }
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: root.shelf === modelData.row
                        height: 34
                        width: tabText.implicitWidth + 28
                        radius: 17
                        color: current ? root.accent : (tabArea.containsMouse ? root.hover : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05))
                        border.color: current ? "transparent" : root.border
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData.name
                            color: parent.current ? "#ffffff" : root.textColor
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: parent.current ? Font.DemiBold : Font.Normal
                        }
                        MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.shelf = modelData.row }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // ---- shelf grid ----
                    GridView {
                        id: shelfGrid
                        anchors.fill: parent
                        visible: root.query === ""
                        clip: true
                        cellWidth: Math.floor(width / 5)
                        cellHeight: 112
                        model: root.shelfModel
                        boundsBehavior: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                        delegate: Bubble {
                            required property int index
                            required property var model
                            width: shelfGrid.cellWidth
                            height: shelfGrid.cellHeight
                            iconSource: model.decoration
                            label: model.display
                            pinned: root.shelf >= 0 && root.isPinned(model.favoriteId)
                            onActivated: { root.shelfModel.trigger(index, "", null); root.expanded = false; }
                            onContext: root.togglePin(model.favoriteId)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: shelfGrid.count === 0
                            text: root.shelf < 0 ? i18n("Right-click any app in “All” to add it here.") : ""
                            color: root.subtext
                            font.family: "Inter"
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        visible: root.query === ""
                        text: root.shelf < 0 ? i18n("right-click to unpin") : i18n("right-click to pin")
                        color: root.dim
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    // ---- search results ----
                    ListView {
                        id: resultsView
                        anchors.fill: parent
                        visible: root.query !== ""
                        model: root.results
                        currentIndex: menu.selected
                        spacing: 2
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        header: Text {
                            width: resultsView.width
                            bottomPadding: 8
                            text: i18n("Results for “%1”", root.query)
                            color: root.subtext
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                        delegate: HoverCard {
                            required property int index
                            required property var model
                            width: resultsView.width
                            height: 52
                            active: index === menu.selected
                            onActivated: { root.results.trigger(index, "", null); root.expanded = false; }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 14
                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: 10
                                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                    Kirigami.Icon { anchors.centerIn: parent; source: model.decoration; width: 26; height: 26 }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    Text { text: model.display; color: root.textColor; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: model.description || ""; visible: text !== ""; color: root.subtext; font.family: "Inter"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                                Rectangle {
                                    visible: index === menu.selected
                                    Layout.preferredWidth: enterText.implicitWidth + 14
                                    Layout.preferredHeight: 22
                                    radius: 6
                                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
                                    Text { id: enterText; anchors.centerIn: parent; text: i18n("Enter"); color: root.subtext; font.family: "Inter"; font.pixelSize: 10 }
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !runnerModel.querying && (!root.results || root.results.count === 0)
                            text: i18n("Nothing found")
                            color: root.subtext
                            font.family: "Inter"
                        }
                    }
                }
            }
        }

        // ================= Power flyout =================
        MouseArea {
            anchors.fill: parent
            visible: menu.powerOpen
            onClicked: menu.powerOpen = false
        }
        Rectangle {
            visible: menu.powerOpen
            x: Kirigami.Units.gridUnit * 16 - width - 8
            y: parent.height - height - 56
            width: 190
            height: powerCol.implicitHeight + 12
            radius: 12
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
            ColumnLayout {
                id: powerCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2
                Repeater {
                    model: [
                        { icon: "system-suspend", label: i18n("Sleep"), run: () => exec.run("systemctl suspend") },
                        { icon: "system-reboot", label: i18n("Restart"), run: () => root.logoutPrompt("promptReboot") },
                        { icon: "system-shutdown", label: i18n("Shut down"), run: () => root.logoutPrompt("promptShutDown") },
                        { icon: "system-log-out", label: i18n("Sign out"), run: () => root.logoutPrompt("promptLogout") }
                    ]
                    delegate: HoverCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        onActivated: { menu.powerOpen = false; modelData.run(); }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12
                            Kirigami.Icon { source: modelData.icon; isMask: true; color: root.textColor; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                            Text { text: modelData.label; color: root.textColor; font.family: "Inter"; font.pixelSize: 13; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // ---------- Components ----------
    component HoverCard: Rectangle {
        id: hc
        property bool active: false
        signal activated()
        signal context()
        radius: 12
        color: hcArea.pressed ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.14) : (hcArea.containsMouse || active ? root.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: hcArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => m.button === Qt.RightButton ? hc.context() : hc.activated()
        }
    }

    // An app "bubble": the icon floats in a soft disc that lights up in the accent colour.
    component Bubble: Item {
        id: bb
        property var iconSource
        property string label
        property bool pinned: false
        signal activated()
        signal context()
        readonly property bool hot: bbArea.containsMouse
        Rectangle {
            id: disc
            width: 68; height: 68
            radius: 34
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            color: bb.hot ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.045)
            border.width: bb.hot ? 2 : 1
            border.color: bb.hot ? root.accent : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07)
            scale: bbArea.pressed ? 0.93 : (bb.hot ? 1.06 : 1)
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Kirigami.Icon { anchors.centerIn: parent; source: bb.iconSource; width: 40; height: 40 }
            Rectangle {
                visible: bb.pinned
                width: 10; height: 10; radius: 5
                color: root.accent
                border.width: 2
                border.color: "#0d1428"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 2
            }
        }
        Text {
            anchors.top: disc.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            text: bb.label
            color: bb.hot ? root.textColor : root.subtext
            font.family: "Inter"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        MouseArea {
            id: bbArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => m.button === Qt.RightButton ? bb.context() : bb.activated()
        }
    }

    component RoundButton: Rectangle {
        id: rb
        property string iconName
        property string tip
        property bool lit: false
        signal clicked()
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 16
        color: rb.lit ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3) : (rbArea.containsMouse ? root.hover : "transparent")
        Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; source: rb.iconName; isMask: true; color: root.textColor }
        MouseArea { id: rbArea; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }
        QQC2.ToolTip.visible: rbArea.containsMouse
        QQC2.ToolTip.text: rb.tip
        QQC2.ToolTip.delay: 500
    }
}