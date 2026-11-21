/*
    TwilightOS logout screen (one instance per screen).
    Same interface as Plasma's org.kde.plasma.desktop logout (signals, countdown,
    controls shared between screens); only the look is TwilightOS "Twilight".

    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2026 TwilightOS Project
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window

import org.kde.kirigami as Kirigami

import "timer.js" as AutoTriggerTimer
import "controlsowner.js" as ControlsOwner

Item {
    id: root
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    function sleepRequested() { root.suspendRequested(2) }
    function hibernateRequested() { root.suspendRequested(4) }

    property real timeout: 30
    property real remainingTime: root.timeout
    readonly property bool countingDown: countDownTimer.running

    property var currentAction: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot:
            return () => softwareUpdatePending ? rebootUpdateRequested() : rebootRequested();
        case ShutdownType.ShutdownTypeHalt:
            return () => softwareUpdatePending ? haltUpdateRequested() : haltRequested();
        default:
            return () => logoutRequested();
        }
    }

    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault

    Component {
        id: controlsComponent
        LogoutControls {}
    }

    function ensureControlsExist() {
        if (!ControlsOwner.controls) {
            ControlsOwner.controls = controlsComponent.createObject(root);
        }
    }

    Component.onCompleted: ensureControlsExist()

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if (root.Window.window) {
                    root.Window.window.requestActivate();
                }
                if (ControlsOwner.controls && ControlsOwner.controls.parent !== root) {
                    ControlsOwner.controls.parent = root;
                }
            }
        }
    }

    QQC2.Action {
        onTriggered: root.cancelRequested()
        shortcut: "Escape"
    }

    onRemainingTimeChanged: {
        if (remainingTime <= 0) {
            (currentAction)();
        }
    }

    Timer {
        id: countDownTimer
        running: !showAllOptions
        repeat: true
        interval: 1000
        onTriggered: remainingTime--
        Component.onCompleted: {
            AutoTriggerTimer.addCancelAutoTriggerCallback(function() {
                countDownTimer.running = false;
            });
        }
    }

    // Twilight backdrop: deep navy veil with a warm glow, over the dimmed desktop.
    Rectangle {
        anchors.fill: parent
        opacity: 0.97
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#111a35" }
            GradientStop { position: 1.0; color: "#0a1022" }
        }
    }
    // a single soft glow behind the centre column, in the accent colour
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.9
        height: width
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        opacity: 0.05
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }
}
