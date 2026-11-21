/*
    TwilightOS Quick Settings.
    Top bar: network, volume and battery icons in one button. Click: a panel with
    toggle tiles, volume / brightness sliders, battery, Settings and power.
    State comes from twilightos-settings-helper (one process per refresh).

    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#aeb3c8"
    readonly property string helper: "/usr/local/bin/twilightos-settings-helper"

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: "NoBackground"
    toolTipMainText: i18n("Quick Settings")
    toolTipSubText: (st.conn ? st.conn : i18n("Not connected")) + " · " + i18n("Volume %1%", st.vol || 0)
                    + (st.battery ? " · " + i18n("Battery %1%", st.battery) : "")

    // ---------------- state ----------------
    property var st: ({})
    function kv(text) {
        const o = {};
        text.split("\n").forEach(l => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); });
        return o;
    }
    function set(key, value) { const o = Object.assign({}, st); o[key] = value; st = o; }   // optimistic update

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
            const src = root.helper + " " + args + "  # " + (++seq);
            callbacks[src] = cb || null;
            connectSource(src);
        }
    }
    function refresh() { sh.run("qs-status", t => root.st = root.kv(t)); }
    function act(args) { sh.run(args, () => refreshLater.restart()); }
    function open(cmd) { sh.run("open " + cmd); root.expanded = false; }
    Timer { id: refreshLater; interval: 700; onTriggered: root.refresh() }
    Timer {
        interval: root.expanded ? 2500 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ---------------- icons from state ----------------
    readonly property string netIcon: {
        if (st.type === "ethernet") return "network-wired-activated";
        if (st.type === "wifi") {
            const s = +st.signal || 0;
            return s > 75 ? "network-wireless-signal-excellent" : s > 50 ? "network-wireless-signal-good"
                 : s > 25 ? "network-wireless-signal-ok" : "network-wireless-signal-low";
        }
        if (st.wifi === "disabled") return "network-wireless-disconnected";
        return "network-offline";
    }
    readonly property string volIcon: {
        const v = +st.vol || 0;
        if (st.muted === "yes" || v === 0) return "audio-volume-muted";
        return v > 66 ? "audio-volume-high" : v > 33 ? "audio-volume-medium" : "audio-volume-low";
    }
    readonly property string batIcon: {
        if (st.battery === undefined) return "";
        const lvl = Math.max(0, Math.min(100, Math.round((+st.battery) / 10) * 10));
        const name = "battery-" + String(lvl).padStart(3, "0");
        return st.charging === "Charging" ? name + "-charging" : name;
    }

    // ---------------- top bar button ----------------
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Layout.minimumWidth: icons.implicitWidth + 18
        Layout.preferredWidth: icons.implicitWidth + 18
        Layout.fillHeight: true

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 6
            color: compact.containsMouse || root.expanded ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        RowLayout {
            id: icons
            anchors.centerIn: parent
            spacing: 10
            Kirigami.Icon { source: root.netIcon; isMask: true; color: root.textColor; implicitWidth: 16; implicitHeight: 16 }
            Kirigami.Icon { source: root.volIcon; isMask: true; color: root.textColor; implicitWidth: 16; implicitHeight: 16 }
            Kirigami.Icon { visible: root.batIcon !== ""; source: root.batIcon; isMask: true; color: root.textColor; implicitWidth: 18; implicitHeight: 18 }
        }
    }

    // ---------------- components ----------------
    component Tile: Rectangle {
        id: tile
        property string iconName
        property string label
        property string sub
        property bool on: false
        property string moreCmd: ""
        signal toggled(bool value)
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 14
        color: tile.on ? root.accent : (tileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.065))
        border.color: tile.on ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 160 } }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            anchors.rightMargin: tile.moreCmd !== "" ? 30 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled(!tile.on)
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 10
            Kirigami.Icon {
                source: tile.iconName
                isMask: true
                color: tile.on ? "#ffffff" : root.textColor
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                Text { text: tile.label; color: tile.on ? "#ffffff" : root.textColor; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: tile.sub; visible: text !== ""; color: tile.on ? Qt.rgba(1, 1, 1, 0.85) : root.subtext; font.family: "Inter"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Rectangle {
                visible: tile.moreCmd !== ""
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: moreArea.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"
                Kirigami.Icon { anchors.centerIn: parent; source: "go-next"; isMask: true; color: tile.on ? "#ffffff" : root.subtext; width: 14; height: 14 }
                MouseArea { id: moreArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.open(tile.moreCmd) }
            }
        }
    }

    component SliderRow: RowLayout {
        id: sr
        property string iconName
        property real value: 0
        signal iconClicked()
        signal moved(real v)
        // dragging breaks the slider's binding; follow refreshes again when not dragging
        onValueChanged: if (!slider.pressed) slider.value = sr.value
        spacing: 10
        Layout.fillWidth: true
        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 17
            color: srIcon.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            Kirigami.Icon { anchors.centerIn: parent; source: sr.iconName; isMask: true; color: root.textColor; width: 18; height: 18 }
            MouseArea { id: srIcon; anchors.fill: parent; hoverEnabled: true; onClicked: sr.iconClicked() }
        }
        QQC2.Slider {
            id: slider
            Layout.fillWidth: true
            from: 0; to: 100; stepSize: 1
            value: sr.value
            onMoved: sr.moved(value)
        }
        Text { text: Math.round(slider.value) + "%"; color: root.subtext; font.family: "Inter"; font.pixelSize: 12; font.features: { "tnum": 1 }; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
    }

    // ---------------- panel ----------------
    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: implicitHeight
        spacing: 12

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Tile {
                iconName: root.st.wifi === "enabled" ? "network-wireless" : "network-wireless-disconnected"
                label: i18n("Wi-Fi")
                sub: root.st.type === "wifi" ? root.st.conn : (root.st.type === "ethernet" ? i18n("Ethernet: %1", root.st.conn) : (root.st.wifi === "enabled" ? i18n("Not connected") : i18n("Off")))
                on: root.st.wifi === "enabled"
                moreCmd: "twilightos-settings network"
                onToggled: (value) => { root.set("wifi", value ? "enabled" : "disabled"); root.act("wifi-set " + (value ? "on" : "off")); }
            }
            Tile {
                visible: root.st.bt !== "none"
                iconName: root.st.bt === "on" ? "bluetooth-active" : "bluetooth-disabled"
                label: i18n("Bluetooth")
                sub: root.st.bt === "on" ? i18n("On") : i18n("Off")
                on: root.st.bt === "on"
                moreCmd: "twilightos-settings bluetooth"
                onToggled: (value) => { root.set("bt", value ? "on" : "off"); root.act("bt-set " + (value ? "on" : "off")); }
            }
            Tile {
                iconName: "airplane-mode"
                label: i18n("Airplane mode")
                on: root.st.wifi === "disabled" && root.st.bt !== "on"
                onToggled: (value) => { root.set("wifi", value ? "disabled" : "enabled"); root.act("airplane-set " + (value ? "on" : "off")); }
            }
            Tile {
                iconName: "weather-clear-night"
                label: i18n("Night light")
                sub: on ? i18n("Warm") : ""
                on: root.st.night === "true"
                moreCmd: "twilightos-settings system"
                onToggled: (value) => { root.set("night", value ? "true" : "false"); root.act("night-set " + (value ? "true" : "false")); }
            }
            Tile {
                iconName: root.st.dnd === "on" ? "notifications-disabled" : "notifications"
                label: i18n("Do not disturb")
                sub: on ? i18n("Notifications silenced") : ""
                on: root.st.dnd === "on"
                onToggled: (value) => { root.set("dnd", value ? "on" : "off"); root.act("dnd-set " + (value ? "on" : "off")); }
            }
            Tile {
                iconName: "contrast"
                label: i18n("Dark mode")
                on: root.st.scheme !== "BreezeLight"
                moreCmd: "twilightos-settings personalisation"
                onToggled: (value) => { root.set("scheme", value ? "Twilight" : "BreezeLight"); root.act("dark-set " + (value ? "on" : "off")); }
            }
        }

        SliderRow {
            Layout.topMargin: 4
            iconName: root.volIcon
            value: +root.st.vol || 0
            onIconClicked: { root.set("muted", root.st.muted === "yes" ? "no" : "yes"); root.act("mute-toggle"); }
            onMoved: (v) => { root.set("vol", Math.round(v)); root.sh_volume(Math.round(v)); }
        }
        SliderRow {
            visible: root.st.bright !== undefined
            iconName: "brightness-high"
            value: +root.st.bright || 0
            onMoved: (v) => root.sh_bright(Math.round(v))
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Kirigami.Icon { visible: root.batIcon !== ""; source: root.batIcon; isMask: true; color: root.textColor; Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
            Text {
                visible: root.batIcon !== ""
                text: (root.st.battery || "") + "%" + (root.st.charging === "Charging" ? " · " + i18n("charging") : "")
                color: root.subtext
                font.family: "Inter"
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [
                    { icon: "configure", tip: i18n("All settings"), cmd: "twilightos-settings" },
                    { icon: "system-shutdown", tip: i18n("Power"), cmd: "dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptAll" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: fArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Kirigami.Icon { anchors.centerIn: parent; source: modelData.icon; isMask: true; color: root.textColor; width: 18; height: 18 }
                    MouseArea { id: fArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.open(modelData.cmd) }
                    QQC2.ToolTip.visible: fArea.containsMouse
                    QQC2.ToolTip.text: modelData.tip
                }
            }
        }
    }

    // Slider drags fire many times a second; send at most every 120 ms.
    property int pendingVol: -1
    property int pendingBright: -1
    function sh_volume(v) { pendingVol = v; volThrottle.start(); }
    function sh_bright(v) { pendingBright = v; brightThrottle.start(); }
    Timer { id: volThrottle; interval: 120; onTriggered: if (root.pendingVol >= 0) { sh.run("vol-set " + root.pendingVol); root.pendingVol = -1; } }
    Timer { id: brightThrottle; interval: 120; onTriggered: if (root.pendingBright >= 0) { sh.run("bright-set " + root.pendingBright); root.pendingBright = -1; } }
}
