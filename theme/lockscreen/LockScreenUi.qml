/*
    NovaOS lock screen (Windows-style).

    Idle:   the wallpaper with a large clock and date.
    Active: any key or click slides the clock away, blurs the wallpaper and shows the
            account picture, name and password field.

    Talks to kscreenlocker through the same objects as Plasma's own lock screen
    (authenticator, kscreenlocker_userName/Image, wallpaper, root.notification,
    root.clearPassword), so authentication behaves exactly as in stock Plasma.

    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

import org.kde.plasma.private.sessions
import org.kde.breeze.components

Item {
    id: ui

    readonly property color accent: "#f2683a"
    readonly property color accent2: "#f3b651"
    readonly property color textColor: "#f1eee6"
    readonly property color subtext: "#c9cde0"

    property bool expectingPrompt: true
    property bool showPrompt: false
    property bool noPasswordUnlock: false
    property string pendingPassword

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    component CornerButton: Button {
        id: cb
        property string iconName
        property string tip
        implicitWidth: 44
        implicitHeight: 44
        hoverEnabled: true
        ToolTip.visible: hovered
        ToolTip.text: tip
        contentItem: Kirigami.Icon { source: cb.iconName; color: "#ffffff"; isMask: true; implicitWidth: 22; implicitHeight: 22 }
        background: Rectangle { radius: 8; color: cb.hovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent" }
    }

    function handleMessage(msg) {
        if (!msg) return;
        if (!root.notification) root.notification = msg;
        else if (root.notification.includes(msg)) root.notificationRepeated();
        else root.notification += "\n" + msg;
        lockRoot.uiVisible = true;
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return;     // non-interactive authenticators
            ui.handleMessage(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed"));
            root.clearPassword();
            authenticator.startAuthenticating();
            notificationTimer.restart();
            shake.restart();
        }
        function onSucceeded() {
            authenticator.stopAuthenticating();
            if (!ui.expectingPrompt || authenticator.hadPrompt) {
                Qt.quit();
            } else {
                ui.noPasswordUnlock = true;   // e.g. the passwordless live user
                lockRoot.uiVisible = true;
                unlockButton.forceActiveFocus();
            }
        }
        function onInfoMessageChanged() { ui.handleMessage(authenticator.infoMessage); }
        function onErrorMessageChanged() { ui.handleMessage(authenticator.errorMessage); }
        function onPromptChanged() { ui.handleMessage(authenticator.prompt); }
        function onPromptForSecretChanged() {
            password.forceActiveFocus();
            if (ui.showPrompt) ui.handleMessage(authenticator.promptForSecret);
        }
        function onPamTimeoutChanged() {
            if (!authenticator.pamTimeout && ui.pendingPassword.length > 0) {
                authenticator.respond(ui.pendingPassword);
                ui.pendingPassword = "";
                password.enabled = true;
            }
        }
    }

    Connections {
        target: root
        function onClearPassword() { password.text = ""; password.forceActiveFocus(); }
    }

    SessionManagement { id: sessionManagement }
    Connections {
        target: sessionManagement
        function onAboutToSuspend() { root.clearPassword(); }
    }
    KeyboardIndicator.KeyState { id: capsLock; key: Qt.Key_CapsLock }

    // Pick the default authenticator (password, fingerprint, smartcard...) like Plasma does.
    Repeater {
        id: authenticators
        model: ScreenLocker.AuthenticatorModel
        delegate: Item {
            required property int type
            required property bool passwordField
            required property bool expectingPrompt
            required property bool showPrompt
            Component.onCompleted: {
                if (authenticator.authenticator === type) {
                    ui.expectingPrompt = expectingPrompt;
                    ui.showPrompt = showPrompt;
                }
            }
        }
    }

    MouseArea {
        id: lockRoot
        anchors.fill: parent
        hoverEnabled: true
        property bool uiVisible: false
        property bool seenMove: false
        readonly property bool busy: password.text.length > 0 || ui.noPasswordUnlock
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor

        onPressed: uiVisible = true
        onPositionChanged: { uiVisible = seenMove || uiVisible; seenMove = true; }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
                password.forceActiveFocus();
                idleTimer.restart();
            }
            authenticator.startAuthenticating();
        }
        Keys.onEscapePressed: {
            if (uiVisible) { uiVisible = false; root.clearPassword(); }
        }
        Keys.onPressed: (event) => {
            if (!uiVisible) {
                uiVisible = true;
                // Let the first key land in the password field, like Windows
                if (event.text && event.text.length === 1 && event.text >= " ") {
                    password.text += event.text;
                    event.accepted = true;
                    return;
                }
            }
            idleTimer.restart();
            event.accepted = false;
        }

        ScreenLocker.ActiveScreenMonitor {
            lockscreenState: ScreenLocker.LockscreenState
            window: lockRoot.Window.window
            onActiveChanged: if (!active) lockRoot.uiVisible = false
        }
        Timer {   // keep the backend alive while the prompt is visible
            interval: 1000
            running: !authenticator.unlocked && lockRoot.uiVisible
            repeat: true
            onTriggered: authenticator.startAuthenticating()
        }
        Timer {
            id: idleTimer
            interval: 10000
            onTriggered: if (!lockRoot.busy) lockRoot.uiVisible = false
        }
        Timer {
            id: notificationTimer
            interval: 3500
            onTriggered: root.notification = ""
        }

        // ---------------- Wallpaper ----------------
        ShaderEffectSource {
            id: wallSource
            anchors.fill: parent
            sourceItem: wallpaper
            hideSource: true
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wallSource
            blurEnabled: true
            blurMax: 64
            blur: lockRoot.uiVisible ? 1.0 : 0.0
            brightness: lockRoot.uiVisible ? -0.18 : 0.0
            Behavior on blur { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
            Behavior on brightness { NumberAnimation { duration: 380 } }
        }
        Rectangle {   // soft navy scrim, stronger while signing in
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.08, 0.16, lockRoot.uiVisible ? 0.45 : 0.10) }
                GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.08, 0.16, lockRoot.uiVisible ? 0.70 : 0.35) }
            }
        }

        // ---------------- Clock ----------------
        Column {
            id: clockBlock
            anchors.horizontalCenter: parent.horizontalCenter
            y: lockRoot.uiVisible ? -height - 40 : parent.height * 0.12
            opacity: lockRoot.uiVisible ? 0 : 1
            spacing: 0
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 300 } }

            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                color: ui.textColor
                font.family: "Inter"
                font.pixelSize: Math.round(ui.height * 0.13)
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                color: ui.textColor
                font.family: "Inter"
                font.pixelSize: Math.round(ui.height * 0.028)
                font.weight: Font.Medium
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    const now = new Date();
                    timeText.text = Qt.formatTime(now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""));
                    dateText.text = Qt.formatDate(now, "dddd, d MMMM");
                }
            }
        }

        // ---------------- Sign-in ----------------
        ColumnLayout {
            id: signIn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: lockRoot.uiVisible ? -20 : 60
            opacity: lockRoot.uiVisible ? 1 : 0
            visible: opacity > 0
            spacing: 16
            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 300 } }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: signIn; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                NumberAnimation { target: signIn; property: "anchors.horizontalCenterOffset"; to: 14; duration: 70 }
                NumberAnimation { target: signIn; property: "anchors.horizontalCenterOffset"; to: -7; duration: 60 }
                NumberAnimation { target: signIn; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }

            // Account picture
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 168
                implicitHeight: 168
                Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.08); border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.35) }
                Image {
                    id: face
                    anchors.fill: parent
                    anchors.margins: 4
                    sourceSize: Qt.size(320, 320)
                    fillMode: Image.PreserveAspectCrop
                    source: kscreenlocker_userImage !== ""
                            ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                            : "file:///usr/share/pixmaps/novaos-avatar.png"
                    onStatusChanged: if (status === Image.Error) source = "file:///usr/share/pixmaps/novaos-avatar.png"
                    visible: false
                }
                Rectangle { id: faceMask; anchors.fill: face; radius: width / 2; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: face; source: face; maskEnabled: true; maskSource: faceMask }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: kscreenlocker_userName
                color: ui.textColor
                font.family: "Inter"
                font.pixelSize: 30
                font.weight: Font.DemiBold
            }

            // Password row
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                spacing: 0
                visible: !ui.noPasswordUnlock

                TextField {
                    id: password
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 40
                    echoMode: TextInput.Password
                    placeholderText: i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:placeholder in text field", "Password")
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.55)
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: 15
                    leftPadding: 14
                    rightPadding: 14
                    focus: true
                    background: Rectangle {
                        radius: 6
                        color: Qt.rgba(0.05, 0.08, 0.16, 0.55)
                        border.width: 1
                        border.color: password.activeFocus ? ui.accent : Qt.rgba(1, 1, 1, 0.35)
                        Rectangle {   // Windows-style accent underline
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 1
                            height: 2
                            radius: 1
                            color: ui.accent
                            visible: password.activeFocus
                        }
                    }
                    onTextChanged: idleTimer.restart()
                    onAccepted: submit.clicked()
                    Keys.onEscapePressed: (e) => { if (text.length) text = ""; else lockRoot.uiVisible = false; }
                }
                Button {
                    id: submit
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.leftMargin: 6
                    onClicked: {
                        if (authenticator.pamTimeout) {
                            ui.pendingPassword = password.text;
                            password.enabled = false;
                        } else {
                            authenticator.respond(password.text);
                        }
                    }
                    contentItem: Kirigami.Icon { source: "go-next"; color: "#ffffff"; isMask: true; implicitWidth: 18; implicitHeight: 18 }
                    background: Rectangle {
                        radius: 6
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: ui.accent }
                            GradientStop { position: 1; color: ui.accent2 }
                        }
                        opacity: submit.pressed ? 0.8 : (submit.hovered ? 1 : 0.92)
                    }
                }
            }

            // Passwordless accounts (e.g. the live session): one Unlock button
            Button {
                id: unlockButton
                visible: ui.noPasswordUnlock
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 200
                Layout.preferredHeight: 40
                onClicked: Qt.quit()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                contentItem: Text { text: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button no-password unlock", "Unlock"); color: "#ffffff"; font.family: "Inter"; font.pixelSize: 15; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 6; color: unlockButton.hovered ? Qt.lighter(ui.accent, 1.08) : ui.accent }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 420
                Layout.preferredHeight: 22
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: root.notification ? "#ffd0c2" : ui.subtext
                font.family: "Inter"
                font.pixelSize: 14
                text: {
                    const parts = [];
                    if (capsLock.locked) parts.push(i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Caps Lock is on"));
                    if (root.notification) parts.push(root.notification);
                    return parts.join("  •  ");
                }
            }

            // Other sign-in options (fingerprint, smartcard) when more than one is available
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: authenticators.count > 1
                spacing: 8
                Repeater {
                    model: ScreenLocker.AuthenticatorModel
                    delegate: PlasmaComponents3.ToolButton {
                        required property int type
                        required property string iconName
                        required property bool passwordField
                        required property bool expectingPrompt
                        required property bool showPrompt
                        required property string tooltip
                        icon.name: iconName
                        checkable: true
                        checked: authenticator.authenticator === type
                        onClicked: {
                            authenticator.authenticator = type;
                            root.notification = "";
                            ui.expectingPrompt = expectingPrompt;
                            ui.showPrompt = showPrompt;
                        }
                        PlasmaComponents3.ToolTip.text: tooltip
                        PlasmaComponents3.ToolTip.visible: hovered
                    }
                }
            }
        }

        // ---------------- Bottom corners ----------------
        RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 6

            Battery { visible: !lockRoot.uiVisible }
            CornerButton {
                visible: lockRoot.uiVisible && sessionManagement.canSwitchUser
                iconName: "system-switch-user"
                tip: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Switch &User").replace("&", "")
                onClicked: sessionManagement.switchUser()
            }
            CornerButton {
                visible: lockRoot.uiVisible && sessionManagement.canSuspend
                iconName: "system-suspend"
                tip: i18ndc("plasma_shell_org.kde.plasma.desktop", "@action:button", "Slee&p").replace("&", "")
                onClicked: sessionManagement.suspend()
            }
        }

        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.gridUnit
        }

        Component.onCompleted: fadeIn.start()
        NumberAnimation { id: fadeIn; target: lockRoot; property: "opacity"; from: 0; to: 1; duration: 400 }
    }
}
