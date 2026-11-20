/*
    NovaOS top bar, left: the NovaOS mark and the focused app (name + window title).
    On an empty desktop it simply reads "Desktop". Click toggles minimise.

    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#8f95ad"

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        onActiveTaskChanged: root.refresh()
        onDataChanged: root.refresh()
        onCountChanged: root.refresh()
    }

    property string appName: ""
    property string winTitle: ""
    property bool hasWindow: false

    function refresh() {
        const i = tasks.activeTask;
        const ok = i && i.valid && !tasks.data(i, TaskManager.AbstractTasksModel.IsMinimized);
        hasWindow = !!ok;
        if (!ok) return;
        appName = tasks.data(i, TaskManager.AbstractTasksModel.AppName) || "";
        const t = String(tasks.data(i, Qt.DisplayRole) || "");
        // Most apps end their title with " — App"; drop it, the name is already shown
        const esc = appName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        winTitle = appName ? t.replace(new RegExp("\\s[—–-]\\s" + esc + "$"), "") : t;
        if (winTitle === appName) winTitle = "";
    }

    fullRepresentation: MouseArea {
        id: area
        hoverEnabled: true
        Layout.minimumWidth: row.implicitWidth + 16
        Layout.preferredWidth: row.implicitWidth + 16
        Layout.maximumWidth: Kirigami.Units.gridUnit * 32
        Layout.fillHeight: true
        onClicked: if (root.hasWindow) tasks.requestToggleMinimized(tasks.activeTask)

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 6
            color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            spacing: 8

            // NovaOS mark, small
            Grid {
                columns: 2
                spacing: 1.5
                Layout.alignment: Qt.AlignVCenter
                Rectangle { width: 6; height: 6; radius: 1.8; color: Qt.lighter(root.accent, 1.15) }
                Rectangle { width: 6; height: 6; radius: 3; color: Qt.lighter(root.accent, 1.35) }
                Rectangle { width: 6; height: 6; radius: 1.8; color: root.accent }
                Rectangle { width: 6; height: 6; radius: 1.8; color: Qt.lighter(root.accent, 1.25) }
            }

            Text {
                id: name
                text: root.hasWindow ? root.appName : "Desktop"
                color: root.hasWindow ? root.textColor : root.subtext
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: root.hasWindow ? Font.DemiBold : Font.Medium
                Layout.leftMargin: 2
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            Text {
                visible: root.hasWindow && root.winTitle !== ""
                text: root.winTitle
                color: root.subtext
                font.family: "Inter"
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            }
        }
    }

    Component.onCompleted: refresh()
}
