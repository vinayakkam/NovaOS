// NovaOS Start menu - skeleton. The default layout still uses Kickoff;
// add this widget to the panel manually to try it.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    toolTipMainText: i18n("Start")

    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon || "novaos-start"
            active: parent.containsMouse
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 34
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        spacing: Kirigami.Units.largeSpacing

        PlasmaComponents.TextField {
            Layout.fillWidth: true
            placeholderText: i18n("Search for apps, settings and documents")
            // TODO: hook up KRunner (org.kde.milou / KRunner models)
        }

        Kirigami.Heading { level: 4; text: i18n("Pinned") }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 12
            PlasmaComponents.Label {
                anchors.centerIn: parent
                opacity: 0.7
                text: i18n("Pinned apps grid - TODO")
            }
        }

        Kirigami.Heading { level: 4; text: i18n("Recommended") }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            PlasmaComponents.Label {
                anchors.centerIn: parent
                opacity: 0.7
                text: i18n("Recent files - TODO")
            }
        }
    }
}
