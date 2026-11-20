/*
    NovaOS top bar, left island: the focused app (icon, name, window title).
    On an empty desktop it shows the NovaOS mark and a time-of-day greeting.
    Changes cross-fade; a click on the island minimises / restores the window.

    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons

PlasmoidItem {
    id: root

    readonly property color accent: "#f2683a"
    readonly property color accent2: "#f3b651"
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#aeb3c8"

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    KCoreAddons.KUser { id: kuser }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        onActiveTaskChanged: root.refresh()
        onDataChanged: root.refresh()
        onCountChanged: root.refresh()
    }

    property string appName: ""
    property string winTitle: ""
    property var appIcon: ""
    property bool hasWindow: false

    function refresh() {
        const i = tasks.activeTask;
        const ok = i && i.valid && !tasks.data(i, TaskManager.AbstractTasksModel.IsMinimized);
        hasWindow = !!ok;
        if (!ok) return;
        appName = tasks.data(i, TaskManager.AbstractTasksModel.AppName) || "";
        const t = String(tasks.data(i, Qt.DisplayRole) || "");
        // Most apps put " — App" / " - App" at the end of the title; drop it
        winTitle = appName ? t.replace(new RegExp("\\s[—–-]\\s" + appName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$"), "") : t;
        if (winTitle === appName) winTitle = "";
        appIcon = tasks.data(i, Qt.DecorationRole) || "";
    }

    property int hour: new Date().getHours()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.hour = new Date().getHours() }
    readonly property string greeting: (hour < 5 ? "Good night" : hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening")
                                       + ", " + (kuser.fullName || kuser.loginName)

    fullRepresentation: MouseArea {
        id: island
        hoverEnabled: true
        Layout.minimumWidth: pill.width
        Layout.preferredWidth: pill.width
        Layout.maximumWidth: pill.width
        Layout.fillHeight: true
        onClicked: if (root.hasWindow) tasks.requestToggleMinimized(tasks.activeTask)

        Rectangle {
            id: pill
            anchors.verticalCenter: parent.verticalCenter
            height: Math.min(parent.height - 6, 30)
            width: Math.min(content.implicitWidth + 28, Kirigami.Units.gridUnit * 30)
            radius: height / 2
            color: island.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
            clip: true

            RowLayout {
                id: content
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                spacing: 9
                opacity: fade.running ? 0.35 : 1
                Behavior on opacity { NumberAnimation { duration: 140 } }

                // Mark (empty desktop) or app icon
                Item {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Kirigami.Icon {
                        anchors.fill: parent
                        visible: root.hasWindow
                        source: root.appIcon
                    }
                    Grid {
                        anchors.centerIn: parent
                        visible: !root.hasWindow
                        columns: 2
                        spacing: 2
                        Rectangle { width: 7; height: 7; radius: 2.2; color: Qt.lighter(root.accent, 1.15) }
                        Rectangle { width: 7; height: 7; radius: 3.5; color: root.accent2 }
                        Rectangle { width: 7; height: 7; radius: 2.2; color: root.accent }
                        Rectangle { width: 7; height: 7; radius: 2.2; color: Qt.darker(root.accent2, 1.05) }
                    }
                }
                Text {
                    text: root.hasWindow ? root.appName : root.greeting
                    color: root.textColor
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: root.hasWindow && root.winTitle !== ""
                    text: root.winTitle
                    color: root.subtext
                    font.family: "Inter"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                }
            }

            // brief dip when the focused window changes
            NumberAnimation { id: fade; duration: 160 }
            Connections {
                target: root
                function onAppNameChanged() { fade.restart() }
                function onHasWindowChanged() { fade.restart() }
            }
        }
    }

    Component.onCompleted: refresh()
}
