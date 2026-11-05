pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper
    required property real absX
    required property real absY

    property var settings: ({})

    QtObject {
        id: _cfg

        readonly property real scale: root.settings.scale ?? 1
        readonly property bool invertColors: root.settings.invertColors ?? false
        readonly property int alignment: root.settings.alignment ?? 1
        readonly property bool autoHide: root.settings.autoHide ?? true
        readonly property bool bgEnabled: root.settings.background?.enabled ?? false
        readonly property bool bgBlur: root.settings.background?.blur ?? true
        readonly property real bgOpacity: root.settings.background?.opacity ?? 0.7
        readonly property bool shadowEnabled: root.settings.shadow?.enabled ?? true
        readonly property real shadowOpacity: root.settings.shadow?.opacity ?? 0.7
        readonly property real shadowBlur: root.settings.shadow?.blur ?? 0.4
    }

    property real lyricsScale: _cfg.scale
    readonly property bool bgEnabled: _cfg.bgEnabled
    readonly property bool blurEnabled: bgEnabled && _cfg.bgBlur
    readonly property bool invertColors: _cfg.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary

    readonly property int alignment: _cfg.alignment
    readonly property bool autoHide: _cfg.autoHide
    readonly property bool allWindowsFloating: Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true
    readonly property bool shouldHide: autoHide && !allWindowsFloating

    readonly property bool hasLyrics: Lyrics.hasLyrics
    property int currentLyricIndex: -1
    readonly property bool isCurrentActive: currentLyricIndex >= 0


    property string displayedLyric: ""
    property string previousLyricText: ""
    property string nextLyricText: ""

    property real lyricSpacing: Tokens.spacing.large * root.lyricsScale
    property real targetCenterY: lyricsContainer.height > 0 ? (lyricsContainer.height - lyricContainer.height) / 2 : 0
    property real targetPrevY: targetCenterY - prevLyricItem.height - lyricSpacing
    property real targetNextY: targetCenterY + lyricContainer.height + lyricSpacing
    property real startNextY: targetNextY + nextLyricItem.height + lyricSpacing

    // Match the dashboard's reactive metadata tuple. Native setTrack deduplicates
    // identical tuples across views; this view never clears or refreshes the singleton.
    readonly property var trackSync: {
        const p = Players.active;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        return null;
    }

    function updateLyrics(): void {
        const available = Lyrics.hasLyrics && Players.active !== null;
        const index = available ? Lyrics.indexForTime(Players.active.position) : -1;
        const lines = Lyrics.lyrics;
        const current = index >= 0 ? (lines[index] ?? "").replace(/\u00A0/g, " ") : "";
        const previous = index > 0 ? (lines[index - 1] ?? "").replace(/\u00A0/g, " ") : "";
        const next = available ? (lines[index + 1] ?? "").replace(/\u00A0/g, " ") : "";
        const changed = index !== currentLyricIndex || current !== displayedLyric || previous !== previousLyricText || next !== nextLyricText;

        currentLyricIndex = index;
        displayedLyric = current;
        previousLyricText = previous;
        nextLyricText = next;
        if (changed && index >= 0)
            lyricSlide.restart();
    }

    Component.onCompleted: Qt.callLater(root.updateLyrics)

    implicitWidth: 350 * root.lyricsScale
    implicitHeight: 180 * root.lyricsScale

    opacity: ((root.hasLyrics || Lyrics.loading) && !root.shouldHide && (Players.active?.isPlaying ?? false)) ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim {}
    }

    Behavior on lyricsScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }

    SequentialAnimation {
        id: lyricSlide

        PropertyAction {
            target: prevLyricItem
            property: "y"
            value: root.targetCenterY
        }
        PropertyAction {
            target: lyricContainer
            property: "y"
            value: root.targetNextY
        }
        PropertyAction {
            target: nextLyricItem
            property: "y"
            value: root.startNextY
        }
        ParallelAnimation {
            NumberAnimation {
                target: prevLyricItem
                property: "y"
                to: root.targetPrevY
                duration: Tokens.anim.durations.expressiveDefaultEffects
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lyricContainer
                property: "y"
                to: root.targetCenterY
                duration: Tokens.anim.durations.expressiveDefaultEffects
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: nextLyricItem
                property: "y"
                to: root.targetNextY
                duration: Tokens.anim.durations.expressiveDefaultEffects
                easing.type: Easing.OutCubic
            }
        }
    }

    Timer {
        running: Players.active?.isPlaying ?? false
        interval: Config.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.updateLyrics()
    }

    Connections {
        function onActiveChanged(): void {
            Qt.callLater(root.updateLyrics);
        }

        target: Players
    }

    Connections {
        function onPositionChanged(): void {
            root.updateLyrics();
        }

        function onIsPlayingChanged(): void {
            root.updateLyrics();
        }

        target: Players.active
    }

    Connections {
        // setLines emits lyricsChanged before updating hasLyrics; coalesce both
        // notifications so replacement content is read after the native update.
        function onLyricsChanged(): void {
            Qt.callLater(root.updateLyrics);
        }

        function onHasLyricsChanged(): void {
            Qt.callLater(root.updateLyrics);
        }

        function onOffsetChanged(): void {
            root.updateLyrics();
        }

        target: Lyrics
    }

    Item {
        id: lyricsContainer

        anchors.fill: parent


        layer.enabled: _cfg.shadowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: _cfg.shadowOpacity
            shadowBlur: _cfg.shadowBlur
        }

        Loader {
            id: blurLoader

            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.large * root.lyricsScale
            opacity: _cfg.bgOpacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        Loader {
            id: loadingIndicator

            anchors.centerIn: parent
            asynchronous: true
            active: opacity > 0
            opacity: Lyrics.loading && !root.hasLyrics ? 1 : 0

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.large * root.lyricsScale

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                    implicitHeight: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: shape

                        anchors.centerIn: parent
                        implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5 * root.lyricsScale)
                        containsIcon: true
                        color: Colours.palette.m3primary
                    }
                }

                StyledText {
                    text: Tr.tr("Loading lyrics...")
                    color: root.safeSecondary
                    font: Tokens.font.title.builders.medium.scale(root.lyricsScale).build()
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }


        Item {
            id: fadeContainer

            anchors.fill: parent
            clip: true
            opacity: root.hasLyrics ? 1 : 0

            layer.enabled: true
            layer.effect: Mask {
                maskSource: fadeMask
            }

            Behavior on opacity {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            Rectangle {
                id: fadeMask

                layer.enabled: true
                visible: false
                implicitWidth: fadeContainer.width
                implicitHeight: fadeContainer.height

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        color: Qt.alpha("black", 0)
                        position: 0
                    }
                    GradientStop {
                        color: Qt.alpha("black", 1)
                        position: 0.25 // fadeMargin
                    }
                    GradientStop {
                        color: Qt.alpha("black", 1)
                        position: 0.75 // 1 - fadeMargin
                    }
                    GradientStop {
                        color: Qt.alpha("black", 0)
                        position: 1
                    }
                }
            }

            // --- Previous Lyric ---
            Item {
                id: prevLyricItem

                width: parent.width
                height: prevLyricLabel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.targetPrevY
                visible: root.isCurrentActive

                StyledText {
                    id: prevLyricLabel

                    anchors.fill: parent
                    text: root.previousLyricText
                    font: Tokens.font.body.builders.medium.scale(root.lyricsScale).build()
                    color: root.safeSecondary
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                    horizontalAlignment: {
                        switch (root.alignment) {
                        case 0:
                            return Text.AlignLeft;
                        case 2:
                            return Text.AlignRight;
                        default:
                            return Text.AlignHCenter;
                        }
                    }
                }
            }

            // --- Current Lyric ---
            Item {
                id: lyricContainer

                width: parent.width
                height: currentLyricLabel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.targetCenterY
                visible: root.isCurrentActive

                MultiEffect {
                    id: lyricGlow

                    anchors.fill: currentLyricLabel
                    source: currentLyricLabel
                    scale: currentLyricLabel.scale
                    enabled: root.isCurrentActive

                    blurEnabled: true
                    blur: 0.4

                    shadowEnabled: true
                    shadowColor: Colours.palette.m3primary
                    shadowOpacity: 0.5
                    shadowBlur: 0.6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0

                    autoPaddingEnabled: true
                }

                StyledText {
                    id: currentLyricLabel

                    width: parent.width
                    text: root.displayedLyric
                    font: Tokens.font.title.builders.medium.scale(1.3 * root.lyricsScale).weight(Font.Bold).build()
                    color: Colours.palette.m3primary
                    wrapMode: Text.WordWrap
                    horizontalAlignment: {
                        switch (root.alignment) {
                        case 0:
                            return Text.AlignLeft;
                        case 2:
                            return Text.AlignRight;
                        default:
                            return Text.AlignHCenter;
                        }
                    }

                    Behavior on color {
                        CAnim {
                            duration: Tokens.anim.durations.expressiveFastEffects
                        }
                    }
                }
            }

            Item {
                id: nextLyricItem

                width: parent.width
                height: nextLyricLabel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.targetNextY
                visible: root.isCurrentActive

                StyledText {
                    id: nextLyricLabel

                    anchors.fill: parent
                    text: root.nextLyricText
                    font: Tokens.font.body.builders.medium.scale(root.lyricsScale).build()
                    color: root.safeSecondary
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                    horizontalAlignment: {
                        switch (root.alignment) {
                        case 0:
                            return Text.AlignLeft;
                        case 2:
                            return Text.AlignRight;
                        default:
                            return Text.AlignHCenter;
                        }
                    }
                }
            }
        }
    }
}
