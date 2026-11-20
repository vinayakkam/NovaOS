/*
    NovaOS logout action: a round glass tile with an icon and a label.
    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "timer.js" as AutoTriggerTimer

QQC2.AbstractButton {
    id: button

    property color accent: "#f2683a"
    property bool danger: false

    Layout.alignment: Qt.AlignTop
    implicitWidth: Kirigami.Units.gridUnit * 6
    implicitHeight: tile.height + label.implicitHeight + Kirigami.Units.largeSpacing
    hoverEnabled: true
    activeFocusOnTab: true
    focusPolicy: Qt.StrongFocus

    readonly property bool lit: hovered || activeFocus

    Keys.onPressed: (event) => {
        AutoTriggerTimer.cancelAutoTrigger();
        event.accepted = false;
    }
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    onHoveredChanged: if (hovered) AutoTriggerTimer.cancelAutoTrigger()

    contentItem: Item {
        Rectangle {
            id: tile
            width: Kirigami.Units.gridUnit * 4
            height: width
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: button.lit ? Qt.rgba(1, 1, 1, button.pressed ? 0.16 : 0.11) : Qt.rgba(1, 1, 1, 0.055)
            border.width: button.lit ? 2 : 1
            border.color: button.lit ? (button.danger ? "#ff6b81" : button.accent) : Qt.rgba(1, 1, 1, 0.12)
            scale: button.pressed ? 0.95 : (button.lit ? 1.04 : 1)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.large
                height: width
                source: button.icon.name
                color: "#f1eee6"
                isMask: true
            }
        }
        Text {
            id: label
            anchors.top: tile.bottom
            anchors.topMargin: Kirigami.Units.largeSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            width: button.implicitWidth
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: button.text.replace("&", "")
            color: button.lit ? "#f1eee6" : "#aeb3c8"
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: button.lit ? Font.DemiBold : Font.Normal
        }
    }
}
