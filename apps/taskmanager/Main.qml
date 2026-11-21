/*
    TwilightOS Task Manager: a Windows-style task manager.
      Processes   - apps and background processes with live CPU / memory, End task
      Performance - CPU, memory, disk and network graphs
      Startup     - apps that start at sign-in (opens the KDE module)
    Uses KDE's ksystemstats sensors and the ksysguard process model (the same data
    as System Monitor), so numbers are real-time and accurate.

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.process as Process
import org.kde.ksysguard.formatter as Formatter
import org.kde.plasma.plasma5support as P5Support

QQC2.ApplicationWindow {
    id: app
    width: 1060
    height: 700
    minimumWidth: 760
    minimumHeight: 480
    visible: true
    title: "Task Manager"
    color: base

    readonly property color base: "#0d1428"
    readonly property color side: "#0a1022"
    readonly property color card: Qt.rgba(1, 1, 1, 0.045)
    readonly property color border: Qt.rgba(1, 1, 1, 0.07)
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#aeb3c8"
    readonly property color dim: "#727892"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color cpuColor: accent
    readonly property color memColor: "#a46bff"
    readonly property color diskColor: "#5fd39b"
    readonly property color netColor: "#5eb7d0"

    // optional first argument: processes | performance | startup
    property string page: {
        const a = Qt.application.arguments;
        for (let i = 0; i < a.length; i++) if (["processes", "performance", "startup"].includes(a[i])) return a[i];
        return "processes";
    }
    property var selectedPids: []
    property string selectedName: ""
    property string filter: ""

    // ---------------- Data ----------------
    Sensors.Sensor { id: cpuSensor; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Sensors.Sensor { id: memUsed; sensorId: "memory/physical/used"; updateRateLimit: 1000 }
    Sensors.Sensor { id: memTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: memPct; sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Sensors.Sensor { id: diskRead; sensorId: "disk/all/read"; updateRateLimit: 1000 }
    Sensors.Sensor { id: diskWrite; sensorId: "disk/all/write"; updateRateLimit: 1000 }
    Sensors.Sensor { id: netDown; sensorId: "network/all/download"; updateRateLimit: 1000 }
    Sensors.Sensor { id: netUp; sensorId: "network/all/upload"; updateRateLimit: 1000 }

    property var cpuHist: []
    property var memHist: []
    property var diskHist: []
    property var netHist: []
    function push(arr, v) { const a = arr.slice(-59); a.push(v || 0); return a; }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            app.cpuHist = app.push(app.cpuHist, cpuSensor.value);
            app.memHist = app.push(app.memHist, memPct.value);
            app.diskHist = app.push(app.diskHist, (diskRead.value || 0) + (diskWrite.value || 0));
            app.netHist = app.push(app.netHist, (netDown.value || 0) + (netUp.value || 0));
        }
    }
    function bytes(v) { return Formatter.Formatter.formatValueShowNull(v || 0, Formatter.Units.UnitByte); }
    function rate(v) { return Formatter.Formatter.formatValueShowNull(v || 0, Formatter.Units.UnitByteRate); }

    // Every running process with live CPU and memory (the app-grouped model only
    // lists sandboxed/launched apps and missed Plasma, KWin and services).
    Process.ProcessDataModel {
        id: appsModel
        enabled: app.page === "processes"
        flatList: true
        // columns: 0 name, 1 CPU, 2 memory
        enabledAttributes: ["name", "usage", "vmPSS"]
    }
    Process.ProcessController { id: controller; window: app }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
        function run(cmd) { connectSource("setsid -f " + cmd + " >/dev/null 2>&1"); }
    }

    function endTask() {
        if (app.selectedPids.length === 0) return;
        controller.sendSignal(app.selectedPids, 4);   // Signal.TerminateSignal
        app.selectedPids = [];
        app.selectedName = "";
    }

    // ================= Components =================
    component Label: Text {
        color: app.textColor
        font.family: "Inter"
        font.pixelSize: 13
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
    component Sub: Label { color: app.subtext; font.pixelSize: 12 }

    component Button: Rectangle {
        id: b
        property string text
        property string iconName
        property bool primary: false
        property bool enabledState: true
        signal clicked()
        implicitWidth: br.implicitWidth + 24
        implicitHeight: 32
        radius: 6
        opacity: enabledState ? 1 : 0.45
        color: b.primary ? (ba.containsMouse ? Qt.lighter(app.accent, 1.08) : app.accent)
                         : (ba.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06))
        border.color: b.primary ? "transparent" : app.border
        RowLayout {
            id: br
            anchors.centerIn: parent
            spacing: 8
            Kirigami.Icon { visible: b.iconName !== ""; source: b.iconName; isMask: true; color: b.primary ? "#ffffff" : app.textColor; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
            Label { text: b.text; color: b.primary ? "#ffffff" : app.textColor }
        }
        MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; enabled: b.enabledState; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    // Line graph over the last 60 samples
    component Graph: Canvas {
        id: g
        property var values: []
        property color color: app.accent
        property real maximum: 100   // 0 = auto
        onValuesChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, n = 60;
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06);
            ctx.lineWidth = 1;
            for (let i = 1; i < 4; i++) { ctx.beginPath(); ctx.moveTo(0, h * i / 4); ctx.lineTo(w, h * i / 4); ctx.stroke(); }
            if (values.length < 2) return;
            const max = maximum > 0 ? maximum : Math.max(1, ...values) * 1.15;
            const x = i => w - (values.length - 1 - i) * (w / (n - 1));
            const y = v => h - Math.min(1, v / max) * (h - 2) - 1;
            ctx.beginPath();
            ctx.moveTo(x(0), h);
            for (let i = 0; i < values.length; i++) ctx.lineTo(x(i), y(values[i]));
            ctx.lineTo(x(values.length - 1), h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(g.color.r, g.color.g, g.color.b, 0.18);
            ctx.fill();
            ctx.beginPath();
            for (let i = 0; i < values.length; i++) i === 0 ? ctx.moveTo(x(i), y(values[i])) : ctx.lineTo(x(i), y(values[i]));
            ctx.strokeStyle = g.color;
            ctx.lineWidth = 2;
            ctx.stroke();
        }
    }

    // ================= Layout =================
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Sidebar ----------
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: app.side
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                RowLayout {
                    Layout.bottomMargin: 14
                    Layout.leftMargin: 6
                    Layout.topMargin: 6
                    spacing: 10
                    Kirigami.Icon { source: "utilities-system-monitor"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    Label { text: "Task Manager"; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
                Repeater {
                    model: [
                        { id: "processes", title: "Processes", icon: "view-app-grid" },
                        { id: "performance", title: "Performance", icon: "office-chart-line" },
                        { id: "startup", title: "Startup apps", icon: "system-run" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: app.page === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 6
                        color: current ? Qt.rgba(1, 1, 1, 0.07) : (na.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                        Rectangle { visible: parent.current; width: 3; height: 16; radius: 1.5; color: app.accent; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            spacing: 12
                            Kirigami.Icon { source: modelData.icon; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                            Label { text: modelData.title; Layout.fillWidth: true }
                        }
                        MouseArea { id: na; anchors.fill: parent; hoverEnabled: true; onClicked: app.page = modelData.id }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ---------- Content ----------
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["processes", "performance", "startup"].indexOf(app.page)

            // ===== Processes =====
            ColumnLayout {
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 20
                    Layout.bottomMargin: 12
                    spacing: 10
                    Label { text: "Processes"; font.pixelSize: 24; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 240
                        Layout.preferredHeight: 32
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: search.activeFocus ? app.accent : app.border
                        TextInput {
                            id: search
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: app.textColor
                            font.family: "Inter"
                            font.pixelSize: 13
                            clip: true
                            onTextChanged: app.filter = text
                            Text { visible: !search.text; text: "Type a name to search"; color: app.dim; font: search.font; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Button { text: "Run new task"; iconName: "list-add"; onClicked: exec.run("krunner") }
                    Button { text: "End task"; iconName: "dialog-cancel"; primary: true; enabledState: app.selectedPids.length > 0; onClicked: app.endTask() }
                }

                // Totals header (Windows-style column headers with live totals)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    color: "transparent"
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: app.border }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 0
                        Sub { text: "Name"; Layout.fillWidth: true }
                        ColumnLayout {
                            Layout.preferredWidth: 110
                            spacing: 0
                            Label { text: Math.round(cpuSensor.value || 0) + "%"; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                            Sub { text: "CPU"; Layout.alignment: Qt.AlignRight }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 140
                            spacing: 0
                            Label { text: Math.round(memPct.value || 0) + "%"; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                            Sub { text: "Memory"; Layout.alignment: Qt.AlignRight }
                        }
                    }
                }

                // Apps (grouped) sorted by CPU
                KItemModels.KSortFilterProxyModel {
                    id: sortedApps
                    sourceModel: appsModel
                    sortColumn: 1               // CPU
                    sortRoleName: "Value"
                    sortOrder: Qt.DescendingOrder
                    filterKeyColumn: 0
                    filterRoleName: "display"
                    filterString: app.filter
                    filterCaseSensitivity: Qt.CaseInsensitive
                }

                TableView {
                    id: table
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: sortedApps
                    columnWidthProvider: (c) => c === 0 ? Math.max(200, table.width - 250 - 40) : (c === 1 ? 110 : (c === 2 ? 140 : 0))
                    rowHeightProvider: () => 38
                    leftMargin: 20
                    rightMargin: 20
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                    delegate: Rectangle {
                        id: cell
                        required property int row
                        required property int column
                        required property var model
                        readonly property bool selected: app.selectedPids.length > 0 && JSON.stringify(app.selectedPids) === JSON.stringify(model.PIDs || [])
                        color: selected ? Qt.rgba(app.accent.r, app.accent.g, app.accent.b, 0.22)
                                        : (row % 2 ? Qt.rgba(1, 1, 1, 0.02) : "transparent")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: cell.column === 0 ? 8 : 0
                            anchors.rightMargin: 8
                            spacing: 10
                            Kirigami.Icon {
                                visible: cell.column === 0
                                // a process name usually matches its app icon (firefox, konsole, dolphin...)
                                source: cell.column === 0 ? String(cell.model.display || "").toLowerCase() : ""
                                fallback: "application-x-executable"
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: cell.column === 0 ? Text.AlignLeft : Text.AlignRight
                                text: cell.model.display || ""
                                // heat the CPU / memory cells like Windows does
                                color: cell.column === 1 && (cell.model.Value || 0) > 25 ? "#ffd0c2" : app.textColor
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { app.selectedPids = cell.model.PIDs || []; app.selectedName = cell.model.display || ""; }
                            onDoubleClicked: app.page = "performance"
                        }
                    }
                }
            }

            // ===== Performance =====
            Flickable {
                contentHeight: perf.implicitHeight + 40
                clip: true
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                ColumnLayout {
                    id: perf
                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: 14
                    Label { text: "Performance"; font.pixelSize: 24; font.weight: Font.DemiBold }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width > 760 ? 2 : 1
                        columnSpacing: 14
                        rowSpacing: 14

                        Repeater {
                            model: [
                                { title: "CPU", color: app.cpuColor, kind: "cpu" },
                                { title: "Memory", color: app.memColor, kind: "mem" },
                                { title: "Disk", color: app.diskColor, kind: "disk" },
                                { title: "Network", color: app.netColor, kind: "net" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 230
                                radius: 10
                                color: app.card
                                border.color: app.border
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Rectangle { width: 10; height: 10; radius: 5; color: modelData.color }
                                        Label { text: modelData.title; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                                        Label {
                                            font.pixelSize: 15
                                            color: modelData.color
                                            text: modelData.kind === "cpu" ? Math.round(cpuSensor.value || 0) + "%"
                                                : modelData.kind === "mem" ? Math.round(memPct.value || 0) + "%"
                                                : modelData.kind === "disk" ? app.rate((diskRead.value || 0) + (diskWrite.value || 0))
                                                : app.rate((netDown.value || 0) + (netUp.value || 0))
                                        }
                                    }
                                    Graph {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: modelData.color
                                        maximum: modelData.kind === "cpu" || modelData.kind === "mem" ? 100 : 0
                                        values: modelData.kind === "cpu" ? app.cpuHist : modelData.kind === "mem" ? app.memHist
                                              : modelData.kind === "disk" ? app.diskHist : app.netHist
                                    }
                                    Sub {
                                        text: modelData.kind === "cpu" ? "Utilisation over the last 60 seconds"
                                            : modelData.kind === "mem" ? app.bytes(memUsed.value) + " in use of " + app.bytes(memTotal.value)
                                            : modelData.kind === "disk" ? "Read " + app.rate(diskRead.value) + "  ·  Write " + app.rate(diskWrite.value)
                                            : "Receive " + app.rate(netDown.value) + "  ·  Send " + app.rate(netUp.value)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ===== Startup apps =====
            ColumnLayout {
                spacing: 14
                Label { text: "Startup apps"; font.pixelSize: 24; font.weight: Font.DemiBold; Layout.margins: 20; Layout.bottomMargin: 0 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.preferredHeight: 84
                    radius: 10
                    color: app.card
                    border.color: app.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 16
                        Kirigami.Icon { source: "system-run"; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { text: "Apps that start when you sign in"; font.weight: Font.DemiBold }
                            Sub { text: "Fewer startup apps means a faster sign-in and more free memory." }
                        }
                        Button { text: "Manage"; primary: true; onClicked: exec.run("kcmshell6 kcm_autostart") }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    // Ctrl+Shift+Esc opens this window; Delete ends the selected task, like Windows
    Shortcut { sequence: "Delete"; onActivated: app.endTask() }
}
