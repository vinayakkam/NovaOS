/*
    NovaOS Start menu, a Plasma port of the Twilight desktop's Start menu:
    search (KRunner: apps, settings, files, calculator), pinned grid,
    recent items, alphabetical "All apps", and a user / power strip.

    SPDX-FileCopyrightText: 2026 NovaOS Project
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
    readonly property color accent: "#f2683a"
    readonly property color accent2: "#f3b651"
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#aeb3c8"
    readonly property color dim: "#727892"
    readonly property color card: Qt.rgba(1, 1, 1, 0.055)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.09)
    readonly property color border: Qt.rgba(1, 1, 1, 0.09)

    preferredRepresentation: compactRepresentation
    activationTogglesExpanded: true
    hideOnWindowDeactivate: true
    Plasmoid.icon: Plasmoid.configuration.icon || "novaos-start"
    toolTipMainText: i18n("Start")
    toolTipSubText: ""

    property string page: "home"   // home | all
    property string query: ""

    onExpandedChanged: {
        if (expanded) {
            query = "";
            page = "home";
        }
    }

    function isPinned(id) {
        const strip = s => String(s || "").replace(/^applications:/, "");
        const want = strip(id);
        return (Plasmoid.configuration.pinned || []).some(p => strip(p) === want);
    }
    function togglePin(id) {
        const strip = s => String(s || "").replace(/^applications:/, "");
        const want = strip(id);
        const cur = (Plasmoid.configuration.pinned || []).slice();
        const i = cur.findIndex(p => strip(p) === want);
        if (i >= 0) cur.splice(i, 1); else cur.push(want);
        Plasmoid.configuration.pinned = cur;
    }

    // ---------- Data ----------
    Kicker.AppsModel {
        id: appsModel
        autoPopulate: true
        flat: true
        sorted: true
        showSeparators: false
        showTopLevelItems: true
        paginate: false
        appletInterface: root
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
            "krunner_recentdocuments", "locations", "baloosearch", "krunner_sessions", "krunner_powerdevil"
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
            readonly property real gap: root.expanded ? size * 0.16 : (compact.containsMouse ? size * 0.13 : size * 0.09)
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
                readonly property real d: mark.tile * (compact.containsMouse || root.expanded ? 0.92 : 0.8)
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
    fullRepresentation: Item {
        id: menu
        Layout.preferredWidth: Kirigami.Units.gridUnit * 36
        Layout.preferredHeight: Kirigami.Units.gridUnit * 38
        Layout.minimumWidth: Kirigami.Units.gridUnit * 30
        Layout.minimumHeight: Kirigami.Units.gridUnit * 30

        property int selected: 0

        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    search.text = "";
                    search.forceActiveFocus();
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            anchors.bottomMargin: strip.height + Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.gridUnit

            // ---- Search ----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: Qt.rgba(1, 1, 1, 0.07)
                border.color: search.activeFocus ? Qt.rgba(0.95, 0.41, 0.23, 0.55) : root.border

                Kirigami.Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    source: "edit-find"
                    color: root.subtext
                    isMask: true
                }
                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.textColor
                    selectionColor: root.accent
                    font.family: "Inter"
                    font.pixelSize: 14
                    clip: true
                    onTextChanged: { root.query = text.trim(); menu.selected = 0; }
                    Keys.onEscapePressed: root.expanded = false
                    Keys.onDownPressed: menu.selected = Math.min(menu.selected + 1, (root.results ? root.results.count : 1) - 1)
                    Keys.onUpPressed: menu.selected = Math.max(menu.selected - 1, 0)
                    Keys.onReturnPressed: menu.runResult(menu.selected)
                    Keys.onEnterPressed: menu.runResult(menu.selected)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: i18n("Search for apps, settings and files")
                        color: root.dim
                        font.family: "Inter"
                        font.pixelSize: 14
                    }
                }
            }

            // ---- Content ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ======== Search results ========
                ListView {
                    id: resultsView
                    anchors.fill: parent
                    visible: root.query !== ""
                    model: root.results
                    currentIndex: menu.selected
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Tile {
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
                            Kirigami.Icon { source: model.decoration; Layout.preferredWidth: 30; Layout.preferredHeight: 30 }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text { text: model.display; color: root.textColor; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: model.description || ""; visible: text !== ""; color: root.subtext; font.family: "Inter"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !runnerModel.querying && (!root.results || root.results.count === 0)
                        text: i18n("No results for “%1”", root.query)
                        color: root.subtext
                        font.family: "Inter"
                    }
                }

                // ======== All apps ========
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.query === "" && root.page === "all"
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: i18n("All apps"); color: root.textColor; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Pill { label: i18n("Back"); iconName: "go-previous"; iconFirst: true; onClicked: root.page = "home" }
                    }
                    ListView {
                        id: allList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: appsModel
                        boundsBehavior: Flickable.StopAtBounds
                        section.property: "display"
                        section.criteria: ViewSection.FirstCharacter
                        section.delegate: Text {
                            required property string section
                            text: section.toUpperCase()
                            color: root.accent
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            leftPadding: 12
                            height: 30
                            verticalAlignment: Text.AlignVCenter
                        }
                        delegate: Tile {
                            required property int index
                            required property var model
                            width: allList.width - 8
                            height: 42
                            onActivated: { appsModel.trigger(index, "", null); root.expanded = false; }
                            onContextRequested: root.togglePin(model.favoriteId)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 14
                                Kirigami.Icon { source: model.decoration; Layout.preferredWidth: 26; Layout.preferredHeight: 26 }
                                Text { text: model.display; color: root.textColor; font.family: "Inter"; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                                Kirigami.Icon {
                                    visible: root.isPinned(model.favoriteId)
                                    source: "novaos-start"
                                    Layout.preferredWidth: 14; Layout.preferredHeight: 14
                                    Layout.rightMargin: 12
                                    opacity: 0.8
                                }
                            }
                        }
                    }
                }

                // ======== Home: pinned + recommended ========
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.query === "" && root.page === "home"
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: i18n("Pinned"); color: root.textColor; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; leftPadding: 4 }
                        Pill { label: i18n("All apps"); iconName: "go-next"; onClicked: root.page = "all" }
                    }

                    // Pinned apps: every app row is a cheap Loader; only pinned ones load a tile.
                    Flow {
                        id: pinnedFlow
                        Layout.fillWidth: true
                        readonly property real cell: width / 6
                        Repeater {
                            model: appsModel
                            delegate: Loader {
                                required property int index
                                required property var model
                                active: root.isPinned(model.favoriteId)
                                visible: active
                                width: active ? pinnedFlow.cell : 0
                                height: active ? 92 : 0
                                sourceComponent: Tile {
                                    width: pinnedFlow.cell - 6
                                    height: 86
                                    onActivated: { appsModel.trigger(index, "", null); root.expanded = false; }
                                    onContextRequested: root.togglePin(model.favoriteId)
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Kirigami.Icon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            source: model.decoration
                                            width: 38; height: 38
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: pinnedFlow.cell - 14
                                            horizontalAlignment: Text.AlignHCenter
                                            text: model.display
                                            color: root.textColor
                                            font.family: "Inter"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text { text: i18n("Recommended"); color: root.textColor; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold; leftPadding: 4; Layout.topMargin: 6 }

                    GridView {
                        id: recent
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        interactive: false
                        cellWidth: width / 2
                        cellHeight: 56
                        model: recentModel
                        delegate: Tile {
                            required property int index
                            required property var model
                            width: recent.cellWidth - 6
                            height: recent.cellHeight - 4
                            visible: index < 6
                            onActivated: { recentModel.trigger(index, "", null); root.expanded = false; }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 12
                                Kirigami.Icon { source: model.decoration; Layout.preferredWidth: 30; Layout.preferredHeight: 30 }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    Text { text: model.display; color: root.textColor; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: model.description || ""; visible: text !== ""; color: root.subtext; font.family: "Inter"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }
                        }
                        Text {
                            visible: recent.count === 0
                            width: parent.width
                            leftPadding: 4
                            wrapMode: Text.WordWrap
                            text: i18n("Apps you open and files you use will appear here.")
                            color: root.subtext
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        // ---- Bottom strip: user, files, settings, lock, power ----
        Rectangle {
            id: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 68
            color: Qt.rgba(0, 0, 0, 0.18)
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.border }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.gridUnit
                anchors.rightMargin: Kirigami.Units.gridUnit
                spacing: 6

                Kirigami.Avatar {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    source: kuser.faceIconUrl.toString() !== "" ? kuser.faceIconUrl : "file:///usr/share/pixmaps/novaos-avatar.png"
                    name: kuser.fullName || kuser.loginName
                }
                Text {
                    text: kuser.fullName || kuser.loginName
                    color: root.textColor
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    elide: Text.ElideRight
                }
                StripButton { iconName: "system-file-manager"; tip: i18n("Files"); onClicked: exec.run("dolphin") }
                StripButton { iconName: "systemsettings"; tip: i18n("Settings"); onClicked: exec.run("novaos-settings") }
                StripButton { iconName: "system-lock-screen"; mask: true; tip: i18n("Lock"); onClicked: exec.run("loginctl lock-session") }
                StripButton {
                    iconName: "system-shutdown"; mask: true; tip: i18n("Power")
                    onClicked: exec.run("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptAll")
                }
            }
        }

        function runResult(i) {
            if (root.results && i >= 0 && i < root.results.count) {
                root.results.trigger(i, "", null);
                root.expanded = false;
            }
        }
    }

    // ---------- Small components ----------
    // Generic hover tile used by every list
    component Tile: Rectangle {
        id: t
        property bool active: false
        signal activated()
        signal contextRequested(real x, real y)
        radius: 12
        color: area.pressed ? Qt.rgba(1, 1, 1, 0.14) : (area.containsMouse || active ? root.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => m.button === Qt.RightButton ? t.contextRequested(m.x, m.y) : t.activated()
        }
    }

    component Pill: Rectangle {
        id: pill
        property string label
        property string iconName
        property bool iconFirst: false
        signal clicked()
        implicitWidth: pillRow.implicitWidth + 22
        implicitHeight: 28
        radius: 14
        color: pillArea.containsMouse ? root.hover : root.card
        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4
            layoutDirection: pill.iconFirst ? Qt.RightToLeft : Qt.LeftToRight
            Text { text: pill.label; color: root.textColor; font.family: "Inter"; font.pixelSize: 12 }
            Kirigami.Icon { source: pill.iconName; implicitWidth: 14; implicitHeight: 14; color: root.textColor; isMask: true }
        }
        MouseArea { id: pillArea; anchors.fill: parent; hoverEnabled: true; onClicked: pill.clicked() }
    }

    component StripButton: Rectangle {
        id: sb
        property string iconName
        property string tip
        property bool mask: false
        signal clicked()
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 20
        color: sbArea.containsMouse ? root.hover : "transparent"
        Kirigami.Icon {
            anchors.centerIn: parent
            width: sb.mask ? 20 : 24
            height: width
            source: sb.iconName
            isMask: sb.mask
            color: root.textColor
        }
        MouseArea { id: sbArea; anchors.fill: parent; hoverEnabled: true; onClicked: sb.clicked() }
        QQC2.ToolTip.visible: sbArea.containsMouse
        QQC2.ToolTip.text: sb.tip
        QQC2.ToolTip.delay: 600
    }
}
