/*
    TwilightOS top bar: CPU and RAM as thin labelled bars (they glide to new values and
    warm up under load). Click opens a monitor box: 60-second graphs, the busiest
    apps, and a button for Task Manager.

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.process as Process
import org.kde.ksysguard.formatter as Formatter
import org.kde.kitemmodels as KItemModels
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color memColor: "#a46bff"
    readonly property color hot: "#ff6b81"
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#8f95ad"

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: "NoBackground"
    toolTipMainText: i18n("CPU %1% · Memory %2%", Math.round(cpu.value || 0), Math.round(ram.value || 0))
    toolTipSubText: i18n("Click for details")

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Sensors.Sensor { id: ramUsed; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramTotal; sensorId: "memory/physical/total" }

    // 60 s of history, recorded all the time (two numbers a second) so the graphs
    // are already full when the box opens
    property var cpuHist: []
    property var ramHist: []
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.cpuHist = root.cpuHist.slice(-59).concat([cpu.value || 0]);
            root.ramHist = root.ramHist.slice(-59).concat([ram.value || 0]);
            if (root.expanded) root.refreshTop();
        }
    }

    // Busiest processes by live CPU. The process model exists only while the box is
    // open (created fresh each time: a model switched on later never filled).
    Loader {
        id: procLoader
        active: root.expanded
        sourceComponent: Component {
            Process.ProcessDataModel {
                enabled: true
                flatList: true
                enabledAttributes: ["name", "usage", "vmPSS"]
            }
        }
    }
    KItemModels.KSortFilterProxyModel {
        id: busiest
        sourceModel: procLoader.item
        sortColumn: 1
        sortRoleName: "Value"
        sortOrder: Qt.DescendingOrder
    }
    property var busiestRows: []      // ("top" is a built-in property)
    function refreshTop() {
        const rows = [];
        if (!procLoader.item) { busiestRows = rows; return; }
        const n = Math.min(5, busiest.rowCount());
        for (let r = 0; r < n; r++) {
            rows.push({
                name: busiest.data(busiest.index(r, 0), Qt.DisplayRole) || "",
                cpu: busiest.data(busiest.index(r, 1), Qt.DisplayRole) || "0%",
                mem: busiest.data(busiest.index(r, 2), Qt.DisplayRole) || ""
            });
        }
        busiestRows = rows;
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
        function run(cmd) { connectSource("setsid -f " + cmd + " >/dev/null 2>&1"); root.expanded = false; }
    }

    component Meter: RowLayout {
        id: m
        property string label
        property real value: 0
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        spacing: 6
        Text { text: m.label; color: root.subtext; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.4 }
        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 4
            Layout.alignment: Qt.AlignVCenter
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.12)
            Rectangle {
                height: parent.height
                radius: 2
                width: Math.max(3, parent.width * Math.min(100, m.shown) / 100)
                color: m.value > 85 ? root.hot : root.accent
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
        Text { text: Math.round(m.value) + "%"; color: root.textColor; font.family: "Inter"; font.pixelSize: 11; font.weight: Font.Medium; font.features: { "tnum": 1 }; Layout.preferredWidth: 28 }
    }

    compactRepresentation: MouseArea {
        id: area
        hoverEnabled: true
        Layout.minimumWidth: row.implicitWidth + 16
        Layout.preferredWidth: row.implicitWidth + 16
        Layout.fillHeight: true
        onClicked: root.expanded = !root.expanded

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
            spacing: 14
            Meter { label: "CPU"; value: cpu.value || 0 }
            Meter { label: "RAM"; value: ram.value || 0 }
        }
    }


    // ---------------- The monitor box ----------------
    component Graph: Canvas {
        id: g
        property var values: []
        property color tint: root.accent
        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            if (values.length < 2) return;
            // stretch whatever history there is across the full width
            const step = w / (values.length - 1);
            const x = i => i * step;
            const y = v => h - Math.min(1, Math.max(0, v) / 100) * (h - 3) - 1.5;
            ctx.beginPath();
            ctx.moveTo(0, h);
            for (let i = 0; i < values.length; i++) ctx.lineTo(x(i), y(values[i]));
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(g.tint.r, g.tint.g, g.tint.b, 0.18);
            ctx.fill();
            ctx.beginPath();
            for (let i = 0; i < values.length; i++) i === 0 ? ctx.moveTo(x(i), y(values[i])) : ctx.lineTo(x(i), y(values[i]));
            ctx.strokeStyle = g.tint;
            ctx.lineWidth = 2;
            ctx.stroke();
        }
    }

    component Card: Rectangle {
        id: card
        property string title
        property string value
        property string detail
        property color tint      // not "color": that would replace the card's background
        property var history: []
        Layout.fillWidth: true
        Layout.preferredHeight: 124
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Rectangle { width: 8; height: 8; radius: 4; color: card.tint }
                Text { text: card.title; color: root.textColor; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Text { text: card.value; color: card.tint; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            Graph { Layout.fillWidth: true; Layout.fillHeight: true; tint: card.tint; values: card.history }
            Text { text: card.detail; visible: text !== ""; color: root.subtext; font.family: "Inter"; font.pixelSize: 11 }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: implicitHeight
        spacing: 10

        Card {
            title: "CPU"
            value: Math.round(cpu.value || 0) + "%"
            tint: root.accent
            history: root.cpuHist
        }
        Card {
            title: "Memory"
            value: Math.round(ram.value || 0) + "%"
            detail: Formatter.Formatter.formatValueShowNull(ramUsed.value || 0, Formatter.Units.UnitByte)
                    + " of " + Formatter.Formatter.formatValueShowNull(ramTotal.value || 0, Formatter.Units.UnitByte)
            tint: root.memColor
            history: root.ramHist
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Text { text: "Busiest processes"; color: root.textColor; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Text { text: "CPU"; color: root.subtext; font.family: "Inter"; font.pixelSize: 11; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
            Text { text: "Memory"; color: root.subtext; font.family: "Inter"; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
        }
        Repeater {
            model: root.busiestRows
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 10
                Rectangle { width: 6; height: 6; radius: 3; color: index === 0 ? root.accent : Qt.rgba(1, 1, 1, 0.3) }
                Text { text: modelData.name; color: root.textColor; font.family: "Inter"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData.cpu; color: root.textColor; font.family: "Inter"; font.pixelSize: 12; font.features: { "tnum": 1 }; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                Text { text: modelData.mem; color: root.subtext; font.family: "Inter"; font.pixelSize: 12; font.features: { "tnum": 1 }; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
            }
        }
        Text { visible: root.busiestRows.length === 0; text: "Reading processes…"; color: root.subtext; font.family: "Inter"; font.pixelSize: 12 }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 34
            radius: 8
            color: tmArea.containsMouse ? Qt.lighter(root.accent, 1.08) : root.accent
            Text { anchors.centerIn: parent; text: "Open Task Manager"; color: "#ffffff"; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold }
            MouseArea { id: tmArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: exec.run("twilightos-taskmanager") }
        }
    }
}