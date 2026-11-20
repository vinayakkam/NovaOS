/*
    NovaOS top bar, centre island:  ◔ RAM · date · time · CPU ◔
    - rings animate to new values and warm up (amber -> red) under load
    - hovering widens the island to show the exact percentages
    - click for the calendar

    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color accent: "#f2683a"
    readonly property color accent2: "#f3b651"
    readonly property color hot: "#ff6b81"
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#aeb3c8"

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: "NoBackground"
    toolTipMainText: Qt.formatDate(now, Qt.locale().dateFormat(Locale.LongFormat))
    toolTipSubText: i18n("Memory %1% · CPU %2%", Math.round(ram.value || 0), Math.round(cpu.value || 0))

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: { const d = new Date(); if (d.getMinutes() !== root.now.getMinutes()) root.now = d; }
    }

    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: 2000 }
    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }

    function loadColor(v, base) { return v > 85 ? root.hot : (v > 60 ? root.accent : base); }

    component Ring: Item {
        id: ring
        property real value: 0
        property color color: root.accent
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 400 } }
        implicitWidth: 20
        implicitHeight: 20
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, 0.13)
                strokeWidth: 3
                fillColor: "transparent"
                PathAngleArc { centerX: 10; centerY: 10; radiusX: 8; radiusY: 8; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: ring.color
                strokeWidth: 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 10; centerY: 10; radiusX: 8; radiusY: 8; startAngle: -90; sweepAngle: Math.max(3, Math.min(100, ring.shown)) * 3.6 }
            }
        }
    }

    component Percent: Text {
        property real value
        property bool show
        text: Math.round(value) + "%"
        color: root.subtext
        font.family: "Inter"
        font.pixelSize: 12
        font.weight: Font.Medium
        opacity: show ? 1 : 0
        Layout.preferredWidth: show ? implicitWidth : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        clip: true
    }

    compactRepresentation: MouseArea {
        id: island
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Layout.minimumWidth: pill.width
        Layout.preferredWidth: pill.width
        Layout.fillHeight: true

        readonly property bool open: containsMouse || root.expanded

        Rectangle {
            id: pill
            anchors.centerIn: parent
            height: Math.min(parent.height - 6, 30)
            width: row.implicitWidth + 30
            radius: height / 2
            color: island.open ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: island.open ? Qt.rgba(0.95, 0.41, 0.23, 0.45) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 9

                Ring { value: ram.value || 0; color: root.loadColor(ram.value || 0, root.accent2) }
                Percent { value: ram.value || 0; show: island.open }

                Text {
                    Layout.leftMargin: 4
                    text: Qt.formatDate(root.now, "ddd d MMM")
                    color: root.subtext
                    font.family: "Inter"
                    font.pixelSize: 13
                }
                Text {
                    text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
                    color: root.textColor
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    Layout.rightMargin: 4
                }

                Percent { value: cpu.value || 0; show: island.open }
                Ring { value: cpu.value || 0; color: root.loadColor(cpu.value || 0, root.accent) }
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
