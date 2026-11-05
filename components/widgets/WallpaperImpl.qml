import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.Multimedia
import Caelestia.Shaders
import Caelestia.State
import qs.services
import "../../utils/WallpaperDirection.js" as WallpaperDirection

Item {
    id: root

    readonly property transitionShader shader: slideDirection !== 0 ? Shaders.directional : configuredShader
    readonly property transitionShader configuredShader: {
        CUtils.dependency(Config.background.wallpaperTransition);
        let transition = CUtils.enumToString(Config.background, "wallpaperTransition");
        if (!transition)
            return Shaders.crossfade;

        transition = transition[0].toLowerCase() + transition.slice(1);
        return Shaders[transition] ?? Shaders.crossfade;
    }

    property string source: Wallpapers.current
    property ShaderEffectSource currentCapture: capture1
    property real transitionProgress: 1
    property string previousSource: ""
    property int pendingDirection: 0
    property int slideDirection: 0
    property bool capturePending: false

    onSourceChanged: {
        pendingDirection = WallpaperDirection.selectDirection(previousSource, source, Wallpapers.list);
        previousSource = source;
        capturePending = true;
        transitionAnim.stop();

        if (transitionProgress < 1) {
            currentCapture = currentCapture === capture1 ? capture2 : capture1;
            currentCapture.sourceItem = transition;
        } else {
            currentCapture.sourceItem = live;
        }

        currentCapture.visible = true;
        currentCapture.scheduleUpdate();
    }

    Component.onCompleted: {
        previousSource = source;
        live.source = source;
    }

    function finishCapture(capture: ShaderEffectSource): void {
        capture.visible = false;
        if (capture !== currentCapture)
            return;

        transition.from = capture;
        transitionProgress = 0;
        // Keep the previous shader/direction intact until its frame is captured.
        slideDirection = pendingDirection;
        live.source = source;
        capturePending = false;
        if (live.ready && live.source === source)
            transitionAnim.start();
    }

    NumberAnimation on transitionProgress {
        id: transitionAnim

        running: false
        duration: root.shader.duration * Tokens.anim.durations.scale
        easing: root.shader.easing
        to: 1
    }

    ShaderEffectSource {
        id: capture1

        anchors.fill: parent
        live: false
        visible: false

        onScheduledUpdateCompleted: root.finishCapture(this)
    }

    ShaderEffectSource {
        id: capture2

        anchors.fill: parent
        live: false
        visible: false

        onScheduledUpdateCompleted: root.finishCapture(this)
    }

    Visual {
        id: live

        anchors.fill: parent
        playing: PersistentState.wallpaperPlaying
        animate: false
        layer.enabled: true

        onReadyChanged: {
            if (ready && source === root.source && !root.capturePending && root.transitionProgress < 1)
                transitionAnim.start();
        }
    }

    ShaderEffect {
        id: transition

        property Item from
        property Item to: live
        property real progress: root.transitionProgress
        property vector2d direction: root.slideDirection !== 0 ? Qt.vector2d(root.slideDirection, 0) : Qt.vector2d(0, 1)
        property real slideFade: root.slideDirection !== 0 ? 1 : 0

        anchors.fill: parent
        visible: root.transitionProgress < 1
        fragmentShader: root.shader.url
    }
}
