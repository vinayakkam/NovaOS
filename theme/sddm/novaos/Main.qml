/*
    NovaOS login screen (SDDM, Qt 6, Theme API 2.0).
    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.base || "#0d1428"

    readonly property color accent: config.accent || "#f2683a"
    readonly property color accent2: config.accent2 || "#f3b651"
    readonly property color text: "#f1eee6"
    readonly property color subtext: "#aeb3c8"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false

    // Pull one user's data out of the model through a hidden delegate.
    Repeater {
        id: users
        model: userModel
        delegate: Item {
            required property int index
            required property string name
            required property string realName
            required property string icon
            readonly property string login: name
            readonly property string display: realName !== "" ? realName : name
            readonly property string face: icon
        }
    }
    readonly property Item currentUser: users.count > 0 ? users.itemAt(Math.min(userIndex, users.count - 1)) : null

    function login() {
        if (!currentUser || busy) return;
        busy = true;
        message.text = "";
        sddm.login(currentUser.login, password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            password.text = "";
            password.forceActiveFocus();
            message.text = "That password didn't work. Try again.";
            shake.restart();
        }
        function onLoginSucceeded() { message.text = ""; }
    }

    // ---------- Background ----------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: true
        blur: 0.9
        blurMax: 48
        saturation: -0.1
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.08, 0.16, 0.45) }
            GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.08, 0.16, 0.80) }
        }
    }

    // ---------- Clock ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.1
        spacing: 2
        Text {
            id: clockTime
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.text
            font.family: "Inter"
            font.pixelSize: 96
            font.weight: Font.Light
        }
        Text {
            id: clockDate
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.subtext
            font.family: "Inter"
            font.pixelSize: 22
        }
        Timer {
            interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                const now = new Date();
                clockTime.text = Qt.formatTime(now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""));
                clockDate.text = Qt.formatDate(now, "dddd, d MMMM");
            }
        }
    }

    // ---------- Sign-in card ----------
    ColumnLayout {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.08
        spacing: 14

        SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            RoundButton {
                visible: users.count > 1
                flat: true
                text: "‹"
                font.pixelSize: 28
                palette.buttonText: root.subtext
                onClicked: root.userIndex = (root.userIndex - 1 + users.count) % users.count
            }

            Rectangle {
                width: 132; height: 132; radius: 66
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 2
                border.color: root.accent
                Image {
                    id: face
                    anchors.fill: parent
                    anchors.margins: 4
                    source: root.currentUser && root.currentUser.face !== "" ? "file://" + root.currentUser.face : "file:///usr/share/pixmaps/novaos-avatar.png"
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    onStatusChanged: if (status === Image.Error) source = "file:///usr/share/pixmaps/novaos-avatar.png"
                }
                Rectangle { id: faceMask; anchors.fill: face; radius: width / 2; visible: false; layer.enabled: true }
                MultiEffect {
                    anchors.fill: face
                    source: face
                    maskEnabled: true
                    maskSource: faceMask
                }
            }

            RoundButton {
                visible: users.count > 1
                flat: true
                text: "›"
                font.pixelSize: 28
                palette.buttonText: root.subtext
                onClicked: root.userIndex = (root.userIndex + 1) % users.count
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.currentUser ? root.currentUser.display : ""
            color: root.text
            font.family: "Inter"
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 8

            TextField {
                id: password
                Layout.preferredWidth: 300
                Layout.preferredHeight: 46
                echoMode: TextInput.Password
                placeholderText: "Password"
                placeholderTextColor: root.subtext
                color: root.text
                font.family: "Inter"
                font.pixelSize: 15
                leftPadding: 18
                enabled: !root.busy
                focus: true
                background: Rectangle {
                    radius: 23
                    color: Qt.rgba(1, 1, 1, password.activeFocus ? 0.12 : 0.08)
                    border.width: password.activeFocus ? 2 : 1
                    border.color: password.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.16)
                }
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()
                Component.onCompleted: forceActiveFocus()
            }

            Button {
                id: go
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                enabled: !root.busy
                onClicked: root.login()
                contentItem: Text {
                    text: root.busy ? "…" : "→"
                    color: "#ffffff"
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 23
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.accent }
                        GradientStop { position: 1; color: root.accent2 }
                    }
                    opacity: go.pressed ? 0.8 : (go.hovered ? 1 : 0.92)
                }
            }
        }

        Text {
            id: message
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 20
            color: "#ff6b81"
            font.family: "Inter"
            font.pixelSize: 14
            text: keyboard.capsLock ? "Caps Lock is on" : ""
        }
    }

    // ---------- Bottom bar: session (left), power (right) ----------
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 12

        ComboBox {
            id: session
            Layout.preferredWidth: 240
            model: sessionModel
            textRole: "name"
            currentIndex: root.sessionIndex
            onActivated: (i) => root.sessionIndex = i
            font.family: "Inter"
            contentItem: Text {
                leftPadding: 16
                text: session.displayText
                color: root.text
                font: session.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                implicitHeight: 40
                radius: 20
                color: Qt.rgba(1, 1, 1, session.hovered ? 0.12 : 0.07)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.14)
            }
        }

        Item { Layout.fillWidth: true }

        Repeater {
            model: [
                { icon: "system-suspend",  label: "Sleep",     ok: sddm.canSuspend,  act: () => sddm.suspend() },
                { icon: "system-reboot",   label: "Restart",   ok: sddm.canReboot,   act: () => sddm.reboot() },
                { icon: "system-shutdown", label: "Shut down", ok: sddm.canPowerOff, act: () => sddm.powerOff() }
            ]
            delegate: Button {
                required property var modelData
                visible: modelData.ok
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: modelData.label
                onClicked: modelData.act()
                contentItem: Kirigami.Icon {
                    source: modelData.icon
                    color: root.text
                    isMask: true
                    implicitWidth: 22
                    implicitHeight: 22
                }
                background: Rectangle {
                    radius: 22
                    color: Qt.rgba(1, 1, 1, parent.hovered ? 0.14 : 0.07)
                    border.width: 1
                    border.color: parent.hovered ? root.accent : Qt.rgba(1, 1, 1, 0.14)
                }
            }
        }
    }
}
