// SPDX-FileCopyrightText: 2023~2026 UnionTech Software Technology Co., Ltd.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import org.deepin.dtk 1.0
import org.deepin.dtk 1.0 as D
import org.deepin.dtk.style 1.0 as DS
import org.deepin.image.viewer 1.0 as IV

Item {
    id: navigation

    property bool enableRefresh: true
    property bool imageNeedNavi: false
    property real imgBottom: 0
    // 使用浮点，避免精度丢失导致拖拽边界有细微偏差
    property real imgLeft: 0
    property real imgRight: 0
    property real imgTop: 0
    // 用于动画控制，预期的隐藏动作(用于触发缩放动效时同步导航窗口的处理)
    property real prefferHide: 0
    // 期望是否显示，同时控制动画效果
    property bool prefferVisible: IV.GStatus.enableNavigation && imageNeedNavi
    // 指向的图片对象
    property Image targetImage
    // 背景采样源：由 ImageViewer 传入 viewBackground，用于磨砂玻璃模糊采样
    property Item blurSource

    // 主题感知：DTK.themeType 在 DTK6 为只读，用于色值选择
    readonly property bool isDark: DTK.themeType === ApplicationHelper.DarkType

    // DTK 调色板属性：D.ColorSelector 依据主题/控件状态自动解析为具体色值
    // 与 DTK FloatingPanel.qml 使用相同的声明方式
    property D.Palette dropShadowColor: DS.Style.floatingPanel.dropShadow
    property D.Palette insideBorderColor: DS.Style.floatingPanel.insideBorder
    property D.Palette outsideBorderColor: DS.Style.floatingPanel.outsideBorder

    // 请求释放信号，长时间不使用的导航窗口将请求销毁
    signal requestRelease

    function refreshNaviMask() {
        if (enableRefresh) {
            delayRefreshTimer.start();
        }
    }

    function refreshNaviMaskImpl() {
        if (!targetImage) {
            imageNeedNavi = false;
            return;
        }
        // 预期的缩放比例小于1时不进行显示
        if (prefferHide) {
            imageNeedNavi = false;
            return;
        }

        // 窗口小于最小尺寸时导航功能不可用
        if (!(window.height > IV.GStatus.minHideHeight && window.width > IV.GStatus.minWidth)) {
            imageNeedNavi = false;
            return;
        }

        // 图片实际绘制大小
        var paintedWidth = targetImage.paintedWidth * targetImage.scale;
        var paintedHeight = targetImage.paintedHeight * targetImage.scale;
        // 绘制区域未超过窗口显示区域
        if (paintedWidth <= Window.width && paintedHeight <= Window.height) {
            imageNeedNavi = false;
            return;
        }
        imageNeedNavi = true;

        // 获取横坐标偏移及宽度
        var xOffset = (currentImage.width - currentImage.paintedWidth) / 2;
        if (paintedWidth < Window.width) {
            maskArea.x = xOffset;
            maskArea.width = currentImage.paintedWidth;
        } else {
            // 图片显示宽度 + 超过窗口的图片宽度偏移量
            var expandWidth = paintedWidth - Window.width;
            var xRatio = ((expandWidth / 2) - targetImage.x) / paintedWidth;
            maskArea.x = xOffset + currentImage.paintedWidth * xRatio;
            var widthRatio = Window.width / paintedWidth;
            maskArea.width = currentImage.paintedWidth * widthRatio;
        }
        var yOffset = (currentImage.height - currentImage.paintedHeight) / 2;
        if (paintedHeight < Window.height) {
            maskArea.y = yOffset;
            maskArea.height = currentImage.paintedHeight;
        } else {
            var expandHeight = paintedHeight - Window.height;
            var yRatio = ((expandHeight / 2) - targetImage.y) / paintedHeight;
            maskArea.y = yOffset + currentImage.paintedHeight * yRatio;
            var heightRatio = Window.height / paintedHeight;
            maskArea.height = currentImage.paintedHeight * heightRatio;
        }
    }

    function updateImagePositionBasedOnMask() {
        enableRefresh = false;

        // 根据按键位置更新图片展示区域
        var xOffset = maskArea.x - imgLeft;
        var yOffset = maskArea.y - imgTop;
        // 按当前蒙皮位置映射图片位置
        var xRatio = xOffset / currentImage.paintedWidth;
        var yRatio = yOffset / currentImage.paintedHeight;

        // 图片实际绘制大小
        var paintedWidth = targetImage.paintedWidth * targetImage.scale;
        var paintedHeight = targetImage.paintedHeight * targetImage.scale;
        if (paintedWidth < Window.width) {
            targetImage.x = 0;
        } else {
            // 取得比例相对偏移位置 - 超过窗口的图片显示宽度
            var imageXOffset = (paintedWidth - Window.width) / 2;
            targetImage.x = imageXOffset - paintedWidth * xRatio;
        }
        if (paintedHeight < Window.height) {
            targetImage.y = 0;
        } else {
            var imageYOffset = (paintedHeight - Window.height) / 2;
            targetImage.y = imageYOffset - paintedHeight * yRatio;
        }
        enableRefresh = true;
    }

    // 默认属性为 hide 状态，切换显示状态时将自动动画，Y轴坐标由外部设置

    height: 112
    opacity: 0.3
    scale: 0.3
    visible: false
    width: 150

    states: [
        State {
            name: "show"
            when: prefferVisible

            PropertyChanges {
                opacity: 1
                scale: 1
                target: navigation
                x: 0
                y: 0
            }
        }
    ]
    transitions: Transition {
        id: animtionTrans

        reversible: true
        to: "show"

        onRunningChanged: {
            if (running) {
                visible = true;
            } else {
                // 动画结束再隐藏
                visible = prefferVisible;
            }

            // 隐藏的导航窗口在一段时间后释放
            if (!visible) {
                delayReleaseTimer.restart();
            } else {
                delayReleaseTimer.stop();
            }
        }

        NumberAnimation {
            duration: 366
            easing.type: Easing.OutExpo
            properties: "x,y,scale,opacity"
        }
    }

    onTargetImageChanged: {
        if (targetImage) {
            // 立即刷新
            refreshNaviMaskImpl();

            // transformOrigin 需在图片中心
            if (Item.Center !== targetImage.transformOrigin) {
                console.warn("Image transform origin error, not center!");
            }
        }
    }

    Timer {
        id: delayReleaseTimer

        interval: 5000
        repeat: false

        onTriggered: navigation.requestRelease()
    }

    Timer {
        id: delayRefreshTimer

        interval: 1
        repeat: false

        onTriggered: refreshNaviMaskImpl()
    }

    Connections {
        function onPaintedHeightChanged() {
            refreshNaviMask();
        }

        function onPaintedWidthChanged() {
            refreshNaviMask();
        }

        function onScaleChanged() {
            refreshNaviMask();
        }

        function onXChanged() {
            refreshNaviMask();
        }

        function onYChanged() {
            refreshNaviMask();
        }

        enabled: undefined !== targetImage && enableRefresh
        ignoreUnknownSignals: true
        target: undefined === targetImage ? null : targetImage
    }

    // 磨砂玻璃采样源：捕获 navigation 在 ImageViewer viewBackground 中的屏幕区域
    // visible:false 仅作为采样纹理，不参与场景渲染
    ShaderEffectSource {
        id: blurSampler

        // sourceItem 指向 blurSource(viewBackground)，sourceRect 跟踪 navigation 在其中的偏移
        sourceItem: blurSource
        // 导航窗口在 viewBackground 坐标系中的位置随窗口移动/平移图片实时变化
        sourceRect: Qt.rect(navigation.x, navigation.y, navigation.width, navigation.height)
        visible: false
        live: true
    }

    // 背景图片绘制区域
    Rectangle {
        id: imageRect

        anchors.fill: parent
        color: "transparent"
        layer.enabled: true
        radius: 10

        layer.effect: OpacityMask {
            maskSource: Rectangle {
                height: imageRect.height
                radius: imageRect.radius
                width: imageRect.width
            }
        }

        // 磨砂玻璃层：MultiEffect 对采样内容应用模糊 + 主题感知色相/明度调节
        // 依据 blur.md：色相和明度调节优先放在 MultiEffect 参数中处理，不另加染色层
        MultiEffect {
            id: blurLayer

            anchors.fill: parent
            source: blurSampler
            blurEnabled: true
            blur: 0.62
            blurMax: 72
            // 亮度调节：深色模式提亮，浅色模式压暗，参考 blur.md 基线
            brightness: isDark ? 0.06 : 0.03
            saturation: 1.04
            // 磨砂玻璃层不透明度降至旧配方一半，参考 blur.md
            opacity: 0.5
        }

        // 主题感知混色层：使用 DTK selectColor 选择浅色/深色玻璃色值
        // blur.md 允许在 blur primitive 不提供混色层时补自绘混色层 (uos-design: allow-manual-blur-overlay)
        Rectangle {
            id: tintLayer

            anchors.fill: parent
            radius: imageRect.radius
            // DS.Style.behindWindowBlur.darkColor / lightColor 为 DTK 磨砂玻璃标准混色
            color: DS.Style.control.selectColor(palette.window, DS.Style.behindWindowBlur.lightColor, DS.Style.behindWindowBlur.darkColor)
            opacity: isDark ? 0.6 : 0.33
        }

        Image {
            id: currentImage

            function updateMask() {
                if (Image.Ready === currentImage.status) {
                    imgLeft = (currentImage.width - currentImage.paintedWidth) / 2;
                    imgTop = (currentImage.height - currentImage.paintedHeight) / 2;
                    imgRight = imgLeft + currentImage.paintedWidth;
                    imgBottom = imgTop + currentImage.paintedHeight;
                    refreshNaviMaskImpl();
                }
            }

            function updateSource() {
                source = "image://ImageLoad/" + IV.GControl.currentSource + "#frame_" + IV.GControl.currentFrameIndex;
            }

            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectFit
            source: "image://ImageLoad/" + IV.GControl.currentSource + "#frame_" + IV.GControl.currentFrameIndex
            // 导航窗口尺寸很小，无需加载全尺寸图片，按显示容器大小限制 GPU 纹理
            sourceSize: Qt.size(imageRect.width, imageRect.height)

            // QML6 Image Ready 时 paintedGeometry 不一定更新，调整 onStatusChanged 为 onPaintedGeometryChanged
            onPaintedGeometryChanged: updateMask()
            onSourceChanged: updateMask()
        }

        // 旋转图片触发更新导航窗口，重设图片后绑定会失效，因此手动触发图片源更新
        Connections {
            function onCurrentFrameIndexChanged() {
                currentImage.updateSource();
            }

            function onCurrentRotationChanged() {
                var temp = currentImage.source;
                currentImage.source = "";
                currentImage.source = temp;
                currentImage.updateMask();
            }

            function onCurrentSourceChanged() {
                currentImage.updateSource();
            }

            target: IV.GControl
        }

        // DTK 内边框：D.ColorSelector 解析 D.Palette 为主题感知色值
        D.InsideBoxBorder {
            anchors.fill: parent
            color: navigation.D.ColorSelector.insideBorderColor
            radius: imageRect.radius
            borderWidth: DS.Style.control.borderWidth
        }

        // DTK 外边框：D.ColorSelector 解析 D.Palette 为主题感知色值
        D.OutsideBoxBorder {
            anchors.fill: parent
            color: navigation.D.ColorSelector.outsideBorderColor
            radius: imageRect.radius
            borderWidth: DS.Style.control.borderWidth
        }
    }

    // DTK 投影：hollow + cornerRadius 匹配面板圆角，投影随主题感知
    D.BoxShadow {
        anchors.fill: imageRect
        cornerRadius: imageRect.radius
        hollow: true
        shadowBlur: 6
        shadowColor: navigation.D.ColorSelector.dropShadowColor
        shadowOffsetX: 0
        shadowOffsetY: 2
        z: -1
    }

    // 退出按钮
    ToolButton {
        Accessible.name: qsTr("Close navigation window")
        height: 22
        width: 22
        z: 100

        background: Rectangle {
            radius: 50
        }

        onClicked: {
            IV.GStatus.enableNavigation = false;
        }

        anchors {
            right: parent.right
            rightMargin: 3
            top: parent.top
            topMargin: 3
        }

        Image {
            anchors.fill: parent
            source: "qrc:/res/close_hover.svg"
        }
    }

    // 显示范围蒙皮
    Rectangle {
        id: maskArea

        border.color: "white"
        border.width: 1
        color: "black"
        opacity: 0.4
    }

    // 允许拖动范围
    MouseArea {
        id: mouseArea

        anchors.fill: parent
        drag.axis: Drag.XAndYAxis
        drag.maximumX: imgRight - maskArea.width
        drag.maximumY: imgBottom - maskArea.height
        // 以图片的范围来限制拖动范围
        drag.minimumX: imgLeft
        drag.minimumY: imgTop
        drag.target: maskArea

        onPositionChanged: {
            if (mouseArea.pressed) {
                updateImagePositionBasedOnMask();
            }
        }

        // 拖拽与主界面的联动
        onPressed: {
            maskArea.x = Math.max(mouseX - maskArea.width / 2, 0);
            maskArea.y = Math.max(mouseY - maskArea.height / 2, 0);
            // 限定鼠标点击的蒙皮在图片内移动
            maskArea.x = Math.max(imgLeft, Math.min(maskArea.x, imgRight - maskArea.width));
            maskArea.y = Math.max(imgTop, Math.min(maskArea.y, imgBottom - maskArea.height));

            // 根据按键位置更新图片展示区域
            updateImagePositionBasedOnMask();
        }
    }
}
