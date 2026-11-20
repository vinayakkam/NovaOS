/*
    NovaOS logout controls (Windows Ctrl+Alt+Del style): user, a list of actions,
    Cancel. Visibility rules follow Plasma's LogoutControls.qml so every logout type
    (log out, restart, shut down, "all options") behaves the same.

    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 NovaOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami

import org.kde.plasma.private.sessions

Item {
    id: controls
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    anchors.fill: parent

    readonly property Item hostRoot: parent
    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault
    readonly property string domain: "plasma_shell_org.kde.plasma.desktop"

    opacity: 0
    onHostRootChanged: fadeIn.restart()
    ParallelAnimation {
        id: fadeIn
        NumberAnimation { target: controls; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: column; property: "anchors.verticalCenterOffset"; from: 24; to: 0; duration: 280; easing.type: Easing.OutCubic }
    }

    KCoreAddons.KUser { id: kuser }
    SessionsModel {
        id: otherSessionsModel
        includeUnusedSessions: false
        includeOwnSession: false
    }

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 380)
        spacing: 6

        // ---- who ----
        Kirigami.Avatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 88
            Layout.preferredHeight: 88
            source: kuser.faceIconUrl.toString() !== "" ? kuser.faceIconUrl : "file:///usr/share/pixmaps/novaos-avatar.png"
            name: kuser.fullName || kuser.loginName
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            text: kuser.fullName || kuser.loginName
            color: "#f1eee6"
            font.family: "Inter"
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        // countdown / warnings
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 22
            color: "#f3b651"
            font.family: "Inter"
            font.pixelSize: 14
            opacity: controls.hostRoot.countingDown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            text: {
                switch (sdtype) {
                case ShutdownType.ShutdownTypeReboot:
                    return i18ndp(controls.domain, "Restarting in 1 second", "Restarting in %1 seconds", controls.hostRoot.remainingTime);
                case ShutdownType.ShutdownTypeNone:
                    return i18ndp(controls.domain, "Logging out in 1 second", "Logging out in %1 seconds", controls.hostRoot.remainingTime);
                default:
                    return i18ndp(controls.domain, "Shutting down in 1 second", "Shutting down in %1 seconds", controls.hostRoot.remainingTime);
                }
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#f2c36b"
            font.family: "Inter"
            font.pixelSize: 13
            visible: otherSessionsModel.count > 0 && (sdtype !== ShutdownType.ShutdownTypeNone || controls.showAllOptions)
            text: i18ndp(controls.domain,
                         "One other user is currently logged in. If the computer is shut down or restarted, that user may lose work.",
                         "%1 other users are currently logged in. If the computer is shut down or restarted, those users may lose work.",
                         otherSessionsModel.count)
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#aeb3c8"
            font.family: "Inter"
            font.pixelSize: 13
            visible: rebootToFirmwareSetup || rebootToBootLoaderMenu
            text: rebootToFirmwareSetup
                  ? i18nd(controls.domain, "When restarted, the computer will enter the firmware setup screen.")
                  : i18nd(controls.domain, "When restarted, the computer will enter the boot loader menu.")
        }

        // ---- session actions ----
        LogoutButton {
            id: lockButton
            Layout.topMargin: 10
            icon.name: "system-lock-screen"
            text: i18nd(controls.domain, "Lock")
            visible: controls.showAllOptions
            onClicked: controls.hostRoot.lockScreenRequested()
            KeyNavigation.down: logoutButton
        }
        LogoutButton {
            id: logoutButton
            icon.name: "system-log-out"
            text: i18nd(controls.domain, "Sign out")
            visible: canLogout && (sdtype === ShutdownType.ShutdownTypeNone || controls.showAllOptions)
            highlighted: sdtype === ShutdownType.ShutdownTypeNone
            focus: sdtype === ShutdownType.ShutdownTypeNone
            onClicked: controls.hostRoot.logoutRequested()
            KeyNavigation.up: lockButton
            KeyNavigation.down: suspendButton.visible ? suspendButton : rebootButton
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            color: Qt.rgba(1, 1, 1, 0.1)
            visible: controls.showAllOptions
        }

        // ---- power actions ----
        LogoutButton {
            id: suspendButton
            icon.name: "system-suspend"
            text: i18ndc(controls.domain, "Suspend to RAM", "Slee&p")
            visible: spdMethods.SuspendState && controls.showAllOptions
            onClicked: controls.hostRoot.sleepRequested()
            KeyNavigation.up: logoutButton
            KeyNavigation.down: hibernateButton.visible ? hibernateButton : rebootButton
        }
        LogoutButton {
            id: hibernateButton
            icon.name: "system-suspend-hibernate"
            text: i18nd(controls.domain, "&Hibernate")
            visible: spdMethods.HibernateState && controls.showAllOptions
            onClicked: controls.hostRoot.hibernateRequested()
            KeyNavigation.up: suspendButton
            KeyNavigation.down: rebootButton
        }
        LogoutButton {
            id: rebootButton
            icon.name: "system-reboot"
            text: softwareUpdatePending ? i18ndc(controls.domain, "@action:button Keep short", "Install Updates and Restart")
                                        : i18nd(controls.domain, "&Restart")
            visible: maysd && (sdtype === ShutdownType.ShutdownTypeReboot || controls.showAllOptions)
            highlighted: sdtype === ShutdownType.ShutdownTypeReboot
            focus: sdtype === ShutdownType.ShutdownTypeReboot
            onClicked: softwareUpdatePending ? controls.hostRoot.rebootUpdateRequested() : controls.hostRoot.rebootRequested()
            KeyNavigation.up: hibernateButton.visible ? hibernateButton : (suspendButton.visible ? suspendButton : logoutButton)
            KeyNavigation.down: shutdownButton
        }
        LogoutButton {
            id: shutdownButton
            danger: true
            icon.name: "system-shutdown"
            text: softwareUpdatePending ? i18ndc(controls.domain, "@action:button Keep short", "Install Updates and Shut Down")
                                        : i18nd(controls.domain, "&Shut Down")
            visible: maysd && (sdtype === ShutdownType.ShutdownTypeHalt || controls.showAllOptions)
            highlighted: sdtype === ShutdownType.ShutdownTypeHalt
            focus: sdtype === ShutdownType.ShutdownTypeHalt || controls.showAllOptions
            onClicked: softwareUpdatePending ? controls.hostRoot.haltUpdateRequested() : controls.hostRoot.haltRequested()
            KeyNavigation.up: rebootButton
            KeyNavigation.down: cancel
        }

        // ---- cancel ----
        Rectangle {
            id: cancel
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 18
            implicitWidth: 140
            implicitHeight: 40
            radius: 20
            color: cancelArea.containsMouse || activeFocus ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: activeFocus ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.16)
            activeFocusOnTab: true
            Keys.onReturnPressed: controls.hostRoot.cancelRequested()
            Keys.onEnterPressed: controls.hostRoot.cancelRequested()
            KeyNavigation.up: shutdownButton
            Text {
                anchors.centerIn: parent
                text: i18nd(controls.domain, "&Cancel").replace("&", "")
                color: "#f1eee6"
                font.family: "Inter"
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true; onClicked: controls.hostRoot.cancelRequested() }
        }
    }

    // Clock, quiet, bottom-left (as on the Windows security screen)
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 0
        Text {
            id: t
            color: "#f1eee6"
            font.family: "Inter"
            font.pixelSize: 40
            font.weight: Font.Light
        }
        Text {
            id: d
            color: "#aeb3c8"
            font.family: "Inter"
            font.pixelSize: 15
        }
        Timer {
            interval: 1000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                const now = new Date();
                t.text = Qt.formatTime(now, Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""));
                d.text = Qt.formatDate(now, "dddd, d MMMM");
            }
        }
    }
}
