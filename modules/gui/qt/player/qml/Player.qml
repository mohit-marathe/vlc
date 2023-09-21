/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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
import QtQml.Models 2.12
import QtGraphicalEffects 1.12
import QtQuick.Window 2.12

import org.videolan.vlc 0.1
import org.videolan.compat 0.1

import "qrc:///style/"
import "qrc:///widgets/" as Widgets
import "qrc:///playlist/" as PL
import "qrc:///util/Helpers.js" as Helpers
import "qrc:///dialogs/" as DG

FocusScope {
    id: rootPlayer

    // Properties

    property bool hasEmbededVideo: MainCtx.hasEmbededVideo

    readonly property int positionSliderY: controlBarView.y + controlBarView.sliderY

    readonly property string coverSource: {
        if (MainPlaylistController.currentItem.artwork &&
            MainPlaylistController.currentItem.artwork.toString())
            MainPlaylistController.currentItem.artwork
        else if (Player.hasVideoOutput)
            VLCStyle.noArtVideoCover
        else
            VLCStyle.noArtAlbumCover

    }

    // Private

    property int _lockAutoHide: 0

    readonly property bool _autoHide: _lockAutoHide == 0
                                      && rootPlayer.hasEmbededVideo
                                      && Player.hasVideoOutput
                                      && playlistpopup.state !== "visible"

    property bool _controlsUnderVideo: (MainCtx.pinVideoControls
                                        &&
                                        (MainCtx.intfMainWindow.visibility !== Window.FullScreen))

    property bool _keyPressed: false

    // Settings

    layer.enabled: (StackView.status === StackView.Deactivating || StackView.status === StackView.Activating)

    Accessible.role: Accessible.Client
    Accessible.name: I18n.qtr("Player")

    // Events

    Component.onCompleted: MainCtx.preferHotkeys = true
    Component.onDestruction: MainCtx.preferHotkeys = false

    Keys.priority: Keys.AfterItem
    Keys.onPressed: {
        if (event.accepted)
            return

        _keyPressed = true

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || controlBarView.state !== "visible")
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        if (event.key === Qt.Key_Menu) {
            toolbarAutoHide.toggleForceVisible()
        } else {
            rootPlayer.Navigation.defaultKeyReleaseAction(event)
        }
    }


    on_AutoHideChanged: {
        if (_autoHide)
            toolbarAutoHide.restart()
    }

    on_ControlsUnderVideoChanged: {
        lockUnlockAutoHide(_controlsUnderVideo)
        if (_controlsUnderVideo)
            toolbarAutoHide.setVisibleControlBar(true)
    }

    Connections {
        target: Player

        onVolumeChanged: animationVolume.restart()
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        _lockAutoHide += lock ? 1 : -1;
        console.assert(_lockAutoHide >= 0)
    }

    // Private

    function _onNavigationCancel() {
        if (rootPlayer.hasEmbededVideo && controlBarView.state === "visible") {
            toolbarAutoHide.setVisibleControlBar(false)
        } else {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
               MainPlaylistController.stop()
            }
            History.previous()
        }
    }

    //we draw both the view and the window here
    ColorContext {
        id: windowTheme

        // NOTE: We force the night theme when playing a video.
        palette: (MainCtx.hasEmbededVideo && MainCtx.pinVideoControls === false)
                 ? VLCStyle.darkPalette
                 : VLCStyle.palette

        colorSet: ColorContext.Window
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onShowPlaylist: {
            MainCtx.playlistVisible = true
        }

        onHidePlaylist: {
            MainCtx.playlistVisible = false
        }
    }

    Connections {
        target: MainCtx

        //playlist
        onPlaylistDockedChanged: playlistVisibility.updatePlaylistDocked()
        onPlaylistVisibleChanged: playlistVisibility.updatePlaylistVisible()
        onHasEmbededVideoChanged: playlistVisibility.updateVideoEmbed()
    }

    VideoSurface {
        id: videoSurface

        ctx: MainCtx
        visible: rootPlayer.hasEmbededVideo
        enabled: rootPlayer.hasEmbededVideo
        anchors.fill: parent
        anchors.topMargin: rootPlayer._controlsUnderVideo ? topcontrolView.height : 0
        anchors.bottomMargin: rootPlayer._controlsUnderVideo ? controlBarView.height : 0

        onMouseMoved: {
            //short interval for mouse events
            if (Player.isInteractive)
            {
                toggleControlBarButtonAutoHide.restart()
                videoSurface.cursorShape = Qt.ArrowCursor
            }
            else
                toolbarAutoHide.setVisible(1000)
        }
    }

    // background image
    Rectangle {
        visible: !rootPlayer.hasEmbededVideo
        focus: false
        color: bgtheme.bg.primary
        anchors.fill: parent

        readonly property ColorContext colorContext: ColorContext {
            id: bgtheme
            colorSet: ColorContext.View
        }

        PlayerBlurredBackground {
            id: backgroundImage

            //destination aspect ratio
            readonly property real dar: parent.width / parent.height

            anchors.centerIn: parent
            width: (cover.sar < dar) ? parent.width :  parent.height * cover.sar
            height: (cover.sar < dar) ? parent.width / cover.sar :  parent.height

            source: cover

            screenColor: VLCStyle.setColorAlpha(bgtheme.bg.primary, .55)
            overlayColor: VLCStyle.setColorAlpha(Qt.tint(bgtheme.fg.primary, bgtheme.bg.primary), 0.4)
        }
    }

    Component {
        id: acrylicBackground

        Widgets.AcrylicBackground {
            width: rootPlayer.width

            visible: (rootPlayer._controlsUnderVideo || topcontrolView.resumeVisible)

            opacity: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? MainCtx.pinOpacity
                                                                               : 1.0

            tintColor: windowTheme.bg.primary
        }
    }

    /* top control bar background */
    Widgets.LoaderFade {
        width: parent.width

        state: topcontrolView.state

        height: item.height

        sourceComponent: {
            if (MainCtx.pinVideoControls)
                return acrylicBackground
            else
                return topcontrolViewBackground
        }

        onItemChanged: {
            if (rootPlayer._controlsUnderVideo)
                item.height = Qt.binding(function () { return topcontrolView.height + topcontrolView.anchors.topMargin; })
        }

        Component {
            id: topcontrolViewBackground

            Rectangle {
                width: rootPlayer.width
                height: VLCStyle.dp(206, VLCStyle.scale)

                visible: rootPlayer.hasEmbededVideo

                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .8) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: controlBarView.bottom
        anchors.left: controlBarView.left
        anchors.right: controlBarView.right

        implicitHeight: VLCStyle.dp(206, VLCStyle.scale)

        opacity: controlBarView.opacity

        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: .64; color: Qt.rgba(0, 0, 0, .8) }
            GradientStop { position: 1; color: "black" }
        }

        visible: (controlBarView.item ? !controlBarView.item.background.visible : true)
    }

    Widgets.LoaderFade {
        id: topcontrolView

        property bool resumeVisible: (item) ? item.resumeVisible : false

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        z: 1

        sourceComponent: TopBar {
            id: topbar

            width: topcontrolView.width
            height: topbar.implicitHeight

            topMargin: VLCStyle.applicationVerticalMargin
            sideMargin: VLCStyle.applicationHorizontalMargin

            textWidth: (MainCtx.playlistVisible) ? rootPlayer.width - playlistpopup.width
                                                 : rootPlayer.width

            // NOTE: With pinned controls, the top controls are hidden when switching to
            //       fullScreen. Except when resume is visible
            visible: (MainCtx.pinVideoControls === false
                      ||
                      MainCtx.intfMainWindow.visibility !== Window.FullScreen
                      ||
                      resumeVisible)

            focus: true
            title: MainPlaylistController.currentItem.title

            pinControls: MainCtx.pinVideoControls

            showCSD: MainCtx.clientSideDecoration && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
            showToolbar: MainCtx.hasToolbarMenu && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)

            Navigation.parentItem: rootPlayer
            Navigation.downItem: playlistpopup.showPlaylist ?
                                     playlistpopup : (audioControls.visible ?
                                                          audioControls : (Player.isInteractive ?
                                                                               toggleControlBarButton : controlBarView))

            onTogglePlaylistVisibility: playlistVisibility.togglePlaylistVisibility()

            onRequestLockUnlockAutoHide: {
                rootPlayer.lockUnlockAutoHide(lock)
            }

            onBackRequested: {
                if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
                   MainPlaylistController.stop()
                }
                History.previous()
            }
        }
    }

    MouseArea {
        id: centerContent

        readonly property ColorContext colorContext: ColorContext {
            id: centerTheme
            colorSet: ColorContext.View
        }

        anchors {
            left: parent.left
            right: parent.right
            top: topcontrolView.bottom
            bottom: controlBarView.top
            topMargin: VLCStyle.margin_xsmall
            bottomMargin: VLCStyle.margin_xsmall
        }

        visible: !rootPlayer.hasEmbededVideo

        onWheel: {
            if (rootPlayer.hasEmbededVideo) {
                wheel.accepted = false

                return
            }

            wheel.accepted = true

            var delta = wheel.angleDelta.y

            if (delta === 0)
                return

            Helpers.applyVolume(Player, delta)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0


            Item {
                id: coverItem
                Layout.preferredHeight: rootPlayer.height / sizeConstant
                Layout.preferredWidth: cover.paintedWidth
                Layout.maximumHeight: centerContent.height
                Layout.alignment: Qt.AlignHCenter

                readonly property real sizeConstant: 2.7182

                Image {
                    id: cover

                    //source aspect ratio
                    readonly property real sar: paintedWidth / paintedHeight
                    readonly property int maximumWidth: MainCtx.screen
                                                          ? Helpers.alignUp((MainCtx.screen.availableGeometry.width / coverItem.sizeConstant), 32)
                                                          : 1024
                    readonly property int maximumHeight: MainCtx.screen
                                                          ? Helpers.alignUp((MainCtx.screen.availableGeometry.height / coverItem.sizeConstant), 32)
                                                          : 1024

                    readonly property int maximumSize: Math.min(maximumWidth, maximumHeight)

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: rootPlayer.coverSource
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    cache: false
                    asynchronous: true

                    sourceSize: Qt.size(maximumSize, maximumSize)

                    Accessible.role: Accessible.Graphic
                    Accessible.name: I18n.qtr("Cover")

                    onStatusChanged: {
                        if (status === Image.Ready)
                            backgroundImage.scheduleUpdate()
                    }
                }

                //don't use a DoubleShadow here as cover size will change
                //dynamically with the window size
                Widgets.CoverShadow {
                    anchors.fill: parent
                    source: cover
                    primaryVerticalOffset: VLCStyle.dp(24)
                    primaryBlurRadius: VLCStyle.dp(54)
                    secondaryVerticalOffset: VLCStyle.dp(5)
                    secondaryBlurRadius: VLCStyle.dp(14)
                }
            }

            Widgets.SubtitleLabel {
                id: albumLabel

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: VLCStyle.margin_xxlarge

                BindingCompat on visible {
                    delayed: true
                    value: centerContent.height > (albumLabel.y + albumLabel.height)
                }

                text: MainPlaylistController.currentItem.album
                font.pixelSize: VLCStyle.fontSize_xxlarge
                horizontalAlignment: Text.AlignHCenter
                color: centerTheme.fg.primary
                Accessible.description: I18n.qtr("album")
            }

            Widgets.MenuLabel {
                id: artistLabel

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: VLCStyle.margin_small

                BindingCompat on visible {
                    delayed: true
                    value: centerContent.height > (artistLabel.y + artistLabel.height)
                }

                text: MainPlaylistController.currentItem.artist
                font.weight: Font.Light
                horizontalAlignment: Text.AlignHCenter
                color: centerTheme.fg.primary
                Accessible.description: I18n.qtr("artist")
            }

            Widgets.NavigableRow {
                id: audioControls

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: VLCStyle.margin_large

                BindingCompat on visible {
                    delayed: true
                    value: Player.videoTracks.count === 0 && centerContent.height > (audioControls.y + audioControls.height)
                }

                focus: visible
                spacing: VLCStyle.margin_xxsmall
                Navigation.parentItem: rootPlayer
                Navigation.upItem: topcontrolView
                Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBarView

                model: ObjectModel {
                    Widgets.IconToolButton {
                        iconText: VLCIcons.skip_back
                        size: VLCStyle.icon_audioPlayerButton
                        onClicked: Player.jumpBwd()
                        text: I18n.qtr("Step back")
                    }

                    Widgets.IconToolButton {
                        iconText: VLCIcons.visualization
                        size: VLCStyle.icon_audioPlayerButton
                        onClicked: Player.toggleVisualization()
                        text: I18n.qtr("Visualization")
                    }

                    Widgets.IconToolButton{
                        iconText: VLCIcons.skip_for
                        size: VLCStyle.icon_audioPlayerButton
                        onClicked: Player.jumpFwd()
                        text: I18n.qtr("Step forward")
                    }
                }
            }
        }

        Widgets.SubtitleLabel {
            id: labelVolume

            anchors.right: parent.right
            anchors.top: parent.top

            anchors.rightMargin: VLCStyle.margin_normal
            anchors.topMargin: VLCStyle.margin_xxsmall

            visible: false

            text: I18n.qtr("Volume %1%").arg(Math.round(Player.volume * 100))

            color: centerTheme.fg.primary

            font.weight: Font.Normal

            SequentialAnimation {
                id: animationVolume

                PropertyAction { target: labelVolume; property: "visible"; value: true }

                PauseAnimation { duration: VLCStyle.duration_humanMoment }

                PropertyAction { target: labelVolume; property: "visible"; value: false }
            }
        }
    }

    Widgets.DrawerExt {
        id: playlistpopup

        property bool showPlaylist: false

        anchors {
            // NOTE: When the controls are pinned we display the playqueue under the topBar.
            top: (rootPlayer._controlsUnderVideo) ? topcontrolView.bottom
                                                  : parent.top

            right: parent.right
            bottom: parent.bottom

            bottomMargin: parent.height - rootPlayer.positionSliderY
        }

        focus: false
        edge: Widgets.DrawerExt.Edges.Right
        state: playlistVisibility.isPlaylistVisible ? "visible" : "hidden"
        component: Rectangle {
            width: Helpers.clamp(rootPlayer.width / resizeHandle.widthFactor
                                 , playlistView.minimumWidth
                                 , (rootPlayer.width + playlistView.rightPadding) / 2)

            height: playlistpopup.height

            color: VLCStyle.setColorAlpha(windowTheme.bg.primary, 0.8)


            PL.PlaylistListView {
                id: playlistView

                useAcrylic: false
                focus: true

                anchors.fill: parent
                rightPadding: VLCStyle.applicationHorizontalMargin
                topPadding:  {
                    if (rootPlayer._controlsUnderVideo)
                        return VLCStyle.margin_normal
                    else
                        // NOTE: We increase the padding accordingly to avoid overlapping the TopBar.
                        return topcontrolView.item.reservedHeight
                }

                Navigation.parentItem: rootPlayer
                Navigation.upItem: topcontrolView
                Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBarView
                Navigation.leftAction: closePlaylist
                Navigation.cancelAction: closePlaylist

                function closePlaylist() {
                    playlistVisibility.togglePlaylistVisibility()
                    if (audioControls.visible)
                        audioControls.forceActiveFocus()
                    else
                        controlBarView.forceActiveFocus()
                }


                Widgets.HorizontalResizeHandle {
                    id: resizeHandle

                    property bool _inhibitMainCtxUpdate: false

                    parent: playlistView

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                    }

                    atRight: false
                    targetWidth: playlistpopup.width
                    sourceWidth: rootPlayer.width

                    onWidthFactorChanged: {
                        if (!_inhibitMainCtxUpdate)
                            MainCtx.playerPlaylistWidthFactor = widthFactor
                    }

                    Component.onCompleted:  _updateFromMainCtx()

                    function _updateFromMainCtx() {
                        if (widthFactor == MainCtx.playerPlaylistWidthFactor)
                            return

                        _inhibitMainCtxUpdate = true
                        widthFactor = MainCtx.playerPlaylistWidthFactor
                        _inhibitMainCtxUpdate = false
                    }

                    Connections {
                        target: MainCtx

                        onPlaylistWidthFactorChanged: {
                            resizeHandle._updateFromMainCtx()
                        }
                    }
                }
            }
        }
        onStateChanged: {
            if (state === "hidden")
                toolbarAutoHide.restart()
        }
    }

    DG.Dialogs {
        z: 10
        bgContent: rootPlayer

        anchors {
            bottom: controlBarView.item.visible ? controlBarView.top : rootPlayer.bottom
            left: parent.left
            right: parent.right

            bottomMargin: (rootPlayer._controlsUnderVideo || !controlBarView.item.visible)
                          ? 0 : - VLCStyle.margin_large
        }
    }

    Timer {
        // toggleControlBarButton's visibility depends on this timer
        id: toggleControlBarButtonAutoHide
        running: true
        repeat: false
        interval: 3000

        onTriggered: {
            // Cursor hides when toggleControlBarButton is not visible
            videoSurface.forceActiveFocus()
            videoSurface.cursorShape = Qt.BlankCursor
        }
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && showNavigationBox
                    && toggleControlBarButtonAutoHide.running
                    || navBox.hovered
        x: 50
        y: 800

        Drag.onDragStarted: {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    // NavigationBox's visibility depends on this timer
    Connections {
        target: MainCtx
        onNavBoxToggled: toggleControlBarButtonAutoHide.restart()
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && rootPlayer.hasEmbededVideo
                 && !(MainCtx.pinVideoControls && !Player.fullscreen)
                 && (toggleControlBarButtonAutoHide.running === true
                     || controlBarView.state !== "hidden" || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: controlBarView.state === "hidden" ? parent.bottom : controlBarView.top
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: controlBarView.state === "hidden" ? VLCIcons.expand_inverted : VLCIcons.expand

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistpopup.showPlaylist ? playlistpopup : (audioControls.visible ? audioControls : topcontrolView)
        Navigation.downItem: controlBarView

        onClicked: {
            toolbarAutoHide.toggleForceVisible();
        }
    }

    Widgets.LoaderFade {
        id: controlBarView

        readonly property int sliderY: item.sliderY

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        focus: true

        onStateChanged: {
            if (state === "visible" && item)
                item.showChapterMarks()
        }

        sourceComponent: ControlBar {
            hoverEnabled: true

            focus: true

            rightPadding: VLCStyle.applicationHorizontalMargin
            leftPadding: VLCStyle.applicationHorizontalMargin
            bottomPadding: VLCStyle.applicationVerticalMargin + VLCStyle.margin_xsmall

            textPosition: (MainCtx.pinVideoControls)
                          ? ControlBar.TimeTextPosition.LeftRightSlider
                          : ControlBar.TimeTextPosition.AboveSlider

            Navigation.parentItem: rootPlayer
            Navigation.upItem: playlistpopup.showPlaylist ?
                                   playlistpopup : (Player.isInteractive ?
                                                        toggleControlBarButton : (audioControls.visible ?
                                                                                      audioControls : topcontrolView))

            onRequestLockUnlockAutoHide: rootPlayer.lockUnlockAutoHide(lock)

            identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                                : PlayerControlbarModel.Audioplayer

            onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)

            background: Rectangle {
                id: controlBarBackground

                visible: !MainCtx.hasEmbededVideo || MainCtx.pinVideoControls

                opacity: MainCtx.pinVideoControls ? MainCtx.pinOpacity : 0.7

                color: windowTheme.bg.primary
            }
        }
    }

    Timer {
        id: toolbarAutoHide
        running: true
        repeat: false
        interval: 3000
        onTriggered: {
            setVisibleControlBar(false)
        }

        function setVisibleControlBar(visible) {
            if (visible)
            {
                controlBarView.state = "visible"
                topcontrolView.state = "visible"
                if (!controlBarView.focus && !topcontrolView.focus)
                    controlBarView.forceActiveFocus()

                videoSurface.cursorShape = Qt.ArrowCursor
            }
            else
            {
                if (!rootPlayer._autoHide)
                    return;
                controlBarView.state = "hidden"
                topcontrolView.state = "hidden"
                videoSurface.forceActiveFocus()
                videoSurface.cursorShape = Qt.BlankCursor
            }
        }

        function setVisible(duration) {
            setVisibleControlBar(true)
            toolbarAutoHide.interval = duration
            toolbarAutoHide.restart()
        }

        function toggleForceVisible() {
            setVisibleControlBar(controlBarView.state !== "visible")
            toolbarAutoHide.stop()
        }

    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
        id: filter
        target: MainCtx.intfMainWindow
        enabled: controlBarView.state === "visible"
                 && (controlBarView.focus || topcontrolView.focus)
        Keys.onPressed: toolbarAutoHide.setVisible(5000)
    }

    Connections {
        target: MainCtx
        onAskShow: {
            toolbarAutoHide.toggleForceVisible()
        }
    }
}
