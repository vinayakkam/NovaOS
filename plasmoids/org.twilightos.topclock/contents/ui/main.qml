/*
    TwilightOS top bar, centre: date and time. Click for the calendar.

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#8f95ad"

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: "NoBackground"
    toolTipMainText: Qt.formatDate(now, Qt.locale().dateFormat(Locale.LongFormat))
    toolTipSubText: ""

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: { const d = new Date(); if (d.getMinutes() !== root.now.getMinutes()) root.now = d; }
    }

    compactRepresentation: MouseArea {
        id: area
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Layout.minimumWidth: row.implicitWidth + 20
        Layout.preferredWidth: row.implicitWidth + 20
        Layout.fillHeight: true

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 6
            color: area.containsMouse || root.expanded ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Text {
                text: Qt.formatDate(root.now, "ddd d MMM")
                color: root.subtext
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
                color: root.textColor
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    fullRepresentation: PlasmaCalendar.MonthView {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        today: root.now
        showWeekNumbers: false
    }
}
