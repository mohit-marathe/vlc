/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

import org.videolan.vlc 0.1

import "qrc:///style/"
import "qrc:///widgets/" as Widgets

Control {
    id: navigationBox

    padding: VLCStyle.focus_border

    property alias showNavigationBox: navigationBox.show

    property bool show: false

    Drag.active: mouseArea.drag.active

    function toggleVisibility() {
        show = !show
    }


    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.ToolButton
    }

    Connections {
        target: MainCtx
        onNavBoxToggled: navigationBox.toggleVisibility()
    }

    contentItem: GridLayout {
        columns: 3
        rows: 2
        columnSpacing: VLCStyle.margin_xxsmall
        rowSpacing: VLCStyle.margin_xxsmall

        Widgets.IconButton {
            id: closeButton
            Layout.alignment: Qt.AlignRight | Qt.AlignTop
            Layout.column: 2
            Layout.row: 0
            iconText: VLCIcons.window_close
            onClicked: {
                navigationBox.toggleVisibility()
            }
        }

        Widgets.ActionButtonOverlay {
            id: upButton
            Layout.column: 1
            Layout.row: 0
            iconTxt: VLCIcons.ic_fluent_chevron_up
            iconSize: VLCStyle.icon_large
            onClicked: Player.navigateUp()
        }

        Widgets.ActionButtonOverlay {
            id: leftButton
            Layout.column: 0
            Layout.row: 1
            iconTxt: VLCIcons.ic_fluent_chevron_left
            iconSize: VLCStyle.icon_large
            onClicked: Player.navigateLeft()
        }

        Widgets.ActionButtonOverlay {
            id: selectButton
            Layout.column: 1
            Layout.row: 1
            text: I18n.qtr("OK")
            font.pixelSize: VLCStyle.fontSize_large
            iconSize: VLCStyle.icon_large
            onClicked: Player.navigateActivate()
        }

        Widgets.ActionButtonOverlay {
            id: rightButton
            Layout.column: 2
            Layout.row: 1
            iconTxt: VLCIcons.ic_fluent_chevron_right
            iconSize: VLCStyle.icon_large
            onClicked: Player.navigateRight()
        }

        Widgets.ActionButtonOverlay {
            id: downButton
            Layout.column: 1
            Layout.row: 2
            iconTxt: VLCIcons.ic_fluent_chevron_down
            iconSize: VLCStyle.icon_large
            onClicked: Player.navigateDown()
        }
    }

    background: Rectangle {
        id: navBoxBackgound
        color: "black"
        opacity: 0.4
        radius: VLCStyle.navBoxButton_radius

        MouseArea {
            id: mouseArea

            anchors.fill: parent

            cursorShape: (mouseArea.drag.active || mouseArea.pressed) ? Qt.DragMoveCursor : Qt.OpenHandCursor

            drag.target: navigationBox

            drag.smoothed: false

            hoverEnabled: true

            drag.onActiveChanged: {
                if (drag.active) {
                    drag.target.Drag.start()
                } else {
                    drag.target.Drag.drop()
                }
            }
        }
    }
}
