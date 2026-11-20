/*
    NovaOS logout controls: clock, user, countdown and the action tiles.
    Visibility rules follow Plasma's LogoutControls.qml so every logout type
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
    NumberAnimation {
        id: fadeIn
        target: controls; property: "opacity"; from: 0; to: 1
        duration: 220; easing.type: Easing.OutCubic
    }

    KCoreAddons.KUser { id: kuser }

    SessionsModel {
        id: otherSessionsModel
        includeUnusedSessions: false
        includeOwnSession: false
    }

    // ---------- Clock ----------
    Column {
        id: clockColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.1
        spacing: 2

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#f1eee6"
            font.family: "Inter"
            font.pixelSize: 84
            font.weight: Font.Light
            text: Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""))
        }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#aeb3c8"
            font.family: "Inter"
            font.pixelSize: 20
            text: Qt.formatDate(new Date(), "dddd, d MMMM")
        }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                timeText.text = Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat).replace(/:ss/, ""));
                dateText.text = Qt.formatDate(new Date(), "dddd, d MMMM");
            }
        }
    }

    // ---------- User + actions ----------
    ColumnLayout {
        id: column
        anchors.centerIn: parent
        anchors.verticalCenterOffset: parent.height * 0.06
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.gridUnit * 5 + 6
            implicitHeight: implicitWidth
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: "#f2683a"
            Kirigami.Avatar {
                anchors.centerIn: parent
                width: Kirigami.Units.gridUnit * 5
                height: width
                source: kuser.faceIconUrl.toString() !== "" ? kuser.faceIconUrl : "file:///usr/share/pixmaps/novaos-avatar.png"
                name: kuser.fullName || kuser.loginName
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            color: "#f1eee6"
            font.family: "Inter"
            font.pixelSize: 22
            font.weight: Font.DemiBold
            text: kuser.fullName || kuser.loginName
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            color: "#f3b651"
            font.family: "Inter"
            font.pixelSize: 15
            opacity: controls.hostRoot.countingDown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            text: {
                switch (sdtype) {
                case ShutdownType.ShutdownTypeReboot:
                    return i18ndp(controls.domain, "Restarting in 1 second", "Restarting in %1 seconds", controls.hostRoot.remainingTime);
                case ShutdownType.ShutdownTypeNone:
                    return i18ndp(controls.domain, "Logging out in 1 second", "Logging out in %1 seconds", controls.hostRoot.remainingTime);
                case ShutdownType.ShutdownTypeHalt:
                default:
                    return i18ndp(controls.domain, "Shutting down in 1 second", "Shutting down in %1 seconds", controls.hostRoot.remainingTime);
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#f2c36b"
            font.family: "Inter"
            font.pixelSize: 14
            visible: otherSessionsModel.count > 0 && (sdtype !== ShutdownType.ShutdownTypeNone || controls.showAllOptions)
            text: i18ndp(controls.domain,
                         "One other user is currently logged in. If the computer is shut down or restarted, that user may lose work.",
                         "%1 other users are currently logged in. If the computer is shut down or restarted, those users may lose work.",
                         otherSessionsModel.count)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            color: "#aeb3c8"
            font.family: "Inter"
            font.pixelSize: 14
            visible: rebootToFirmwareSetup || rebootToBootLoaderMenu
            text: rebootToFirmwareSetup
                  ? i18nd(controls.domain, "When restarted, the computer will enter the firmware setup screen.")
                  : i18nd(controls.domain, "When restarted, the computer will enter the boot loader menu.")
        }

        RowLayout {
            id: actions
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.gridUnit

            LogoutButton {
                id: lockButton
                icon.name: "system-lock-screen"
                text: i18nd(controls.domain, "Lock")
                onClicked: controls.hostRoot.lockScreenRequested()
                visible: controls.showAllOptions
            }
            LogoutButton {
                id: suspendButton
                icon.name: "system-suspend"
                text: i18ndc(controls.domain, "Suspend to RAM", "Slee&p")
                onClicked: controls.hostRoot.sleepRequested()
                visible: spdMethods.SuspendState && controls.showAllOptions
            }
            LogoutButton {
                id: hibernateButton
                icon.name: "system-suspend-hibernate"
                text: i18nd(controls.domain, "&Hibernate")
                onClicked: controls.hostRoot.hibernateRequested()
                visible: spdMethods.HibernateState && controls.showAllOptions
            }
            LogoutButton {
                id: rebootButton
                icon.name: "system-reboot"
                text: softwareUpdatePending ? i18ndc(controls.domain, "@action:button Keep short", "Install Updates and Restart")
                                            : i18nd(controls.domain, "&Restart")
                onClicked: softwareUpdatePending ? controls.hostRoot.rebootUpdateRequested() : controls.hostRoot.rebootRequested()
                focus: sdtype === ShutdownType.ShutdownTypeReboot
                visible: maysd && (sdtype === ShutdownType.ShutdownTypeReboot || controls.showAllOptions)
            }
            LogoutButton {
                id: shutdownButton
                danger: true
                icon.name: "system-shutdown"
                text: softwareUpdatePending ? i18ndc(controls.domain, "@action:button Keep short", "Install Updates and Shut Down")
                                            : i18nd(controls.domain, "&Shut Down")
                onClicked: softwareUpdatePending ? controls.hostRoot.haltUpdateRequested() : controls.hostRoot.haltRequested()
                focus: sdtype === ShutdownType.ShutdownTypeHalt || controls.showAllOptions
                visible: maysd && (sdtype === ShutdownType.ShutdownTypeHalt || controls.showAllOptions)
            }
            LogoutButton {
                id: logoutButton
                icon.name: "system-log-out"
                text: i18nd(controls.domain, "&Log Out")
                onClicked: controls.hostRoot.logoutRequested()
                focus: sdtype === ShutdownType.ShutdownTypeNone
                visible: canLogout && (sdtype === ShutdownType.ShutdownTypeNone || controls.showAllOptions)
            }
        }

        // Cancel: a quiet text button under the tiles (Esc or a click anywhere also cancels)
        Rectangle {
            id: cancel
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            implicitWidth: cancelText.implicitWidth + Kirigami.Units.gridUnit * 2
            implicitHeight: cancelText.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: height / 2
            color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Text {
                id: cancelText
                anchors.centerIn: parent
                text: i18nd(controls.domain, "&Cancel").replace("&", "")
                color: "#aeb3c8"
                font.family: "Inter"
                font.pixelSize: 14
            }
            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: controls.hostRoot.cancelRequested()
            }
        }
    }
}
