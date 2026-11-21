/*
    TwilightOS logout action row: icon + label, full-width, Windows Ctrl+Alt+Del style.
    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "timer.js" as AutoTriggerTimer

QQC2.AbstractButton {
    id: button

    property bool danger: false
    property bool highlighted: false     // the action a countdown will run
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property bool lit: hovered || activeFocus

    Layout.fillWidth: true
    implicitHeight: 52
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    Keys.onPressed: (event) => { AutoTriggerTimer.cancelAutoTrigger(); event.accepted = false; }
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    onHoveredChanged: if (hovered) { AutoTriggerTimer.cancelAutoTrigger(); forceActiveFocus(); }

    background: Rectangle {
        radius: 10
        color: button.pressed ? Qt.rgba(1, 1, 1, 0.14)
             : button.lit ? Qt.rgba(1, 1, 1, 0.08)
             : button.highlighted ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.16)
             : "transparent"
        border.width: button.activeFocus || button.highlighted ? 1 : 0
        border.color: button.danger && button.lit ? "#ff6b81" : button.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: RowLayout {
        spacing: 16
        Item { Layout.preferredWidth: 4 }
        Kirigami.Icon {
            source: button.icon.name
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            isMask: true
            color: button.danger && button.lit ? "#ff8fa0" : "#f1eee6"
        }
        Text {
            Layout.fillWidth: true
            text: button.text.replace("&", "")
            color: button.danger && button.lit ? "#ffb3bf" : "#f1eee6"
            font.family: "Inter"
            font.pixelSize: 17
            font.weight: button.lit ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Kirigami.Icon {
            visible: button.lit
            source: "go-next"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            isMask: true
            color: "#aeb3c8"
        }
    }
}
