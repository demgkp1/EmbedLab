import { AppColors } from '../../../constants/AppColors';
import { AppDimens } from '../../../constants/AppDimens';
import { Logger } from '../../../utils/logger/Logger';

/** 关闭字形；工程内置 media 无图钉/关闭图标资源，故沿用星标同款字形方案。 */
const GLYPH_CLOSE: string = '✕';
/** 模块日志标签（统一门面输出，禁止裸写 console）。 */
const MODULE_TAG: string = 'ImageViewerOverlay';

/** 缩放上限：4.0x（M3.5 已由架构师确认的边界） */
const MAX_SCALE: number = 4;
/** 缩放下限：1.0x，禁止缩小到比原图更小 */
const MIN_SCALE: number = 1;
/** 缩放阈值：等于该值视为「原尺寸」，此时禁用单指平移（防与点击关闭冲突） */
const SCALE_UNIT: number = 1;
/**
 * 平移安全系数（软限制口径）。
 * 说明：图片以 ImageFit.Contain 呈现，其真实绘制尺寸在组件内不可静态获知，
 *      故以「缩放后组件盒」为基准做保守夹取：偏移量不超过 缩放后盒边长的一半 × 本系数。
 *      效果：ContentSize.CONTAIN 下即使图片被留白，放大后仍可平移到任一边缘，且不会把图整幅拖出屏幕。
 */
const PAN_SAFE_RATIO: number = 0.5;
/**
 * 软限制阻尼系数。
 * 说明：任务卡允许「不限制或软限制」，本实现取软限制：把可平移范围按 0.8 收窄，
 *      使平移在边缘处提前停住（软边界手感），而非可无限拖出。
 */
const PAN_DAMPING: number = 0.8;
/**
 * 可视区长边首次布局回调前的保守回退值（vp）。
 * 说明：真实值由根 Stack 的 onAreaChange 在首帧布局后写入（见 onViewportChanged），
 *      本常量仅保证「回调到达前」平移夹取不会因 span=0 或 span=NaN 而失效。
 */
const FALLBACK_VIEWPORT_SPAN: number = 720;

/**
 * 全屏图片预览叠加层（Milestone 3.5 / 3.5-b）。
 *
 * 职责：作为 bindContentCover（全模态页面）的内容根节点，全屏呈现单张 rawfile 图片，
 *      支持双指捏合缩放（1.0x ~ 4.0x）+ 放大后单指拖动平移，并支持点击空白处关闭。
 * 边界（架构书第 8 节「数据与页面解耦」）：
 *  - 本组件为纯展示组件，不承载任何 I/O、不访问 Repository / DataSource / Preferences。
 *  - 图片路径由父页面以 @Prop 传入，与详情页 image 块共用同一份 rawfile 相对路径，不做任何拼接。
 *  - 缩放与平移均为纯 UI 瞬态，不进入 UserStore，不参与四层数据流。
 * 约束（ArkUI 防御性编码红线）：
 *  - 严禁在 build() 内修改状态；本组件所有状态变更仅发生在手势回调与点击回调。
 *  - 根容器显式声明 .width('100%').height('100%')，防止被折叠为 0 尺寸白屏。
 *  - 全模态 builder 的根节点必须唯一，故以单一 Stack 承载「图片 + 右上角关闭字形」。
 * 交互设计（M3.5-b）：
 *  - PinchGesture 与 PanGesture 以 GestureGroup(GestureMode.Parallel) 组合，互不阻塞。
 *  - PanGesture 使用 PanGestureHandlerOptions { fingers: 1, isFingerCountLimited: true }：
 *    官方说明未开启 isFingerCountLimited 时「实际手指数超过配置值手势仍识别成功」，
 *    开启后「触摸手指数必须等于配置值」。该字段自 API 15 起支持，本工程 compatibleSdkVersion = 6.1.1(24)。
 *  - scale == 1.0 时禁用平移，避免单指拖动与「点击空白处关闭」相互干扰。
 *  - 关闭语义由父页面持有：本组件仅通过 onRequestClose 上行用户意图（单向数据流）。
 *  - 可视区尺寸实测自 onAreaChange（Area 单位为 vp），不使用 display / window 等外部 API。
 */
@Component
export struct ImageViewerOverlay {
  /**
   * 预览显示开关（父页面单向下发）。
   * 说明：本组件为纯展示组件，**不反向写父状态**；点击关闭经 onRequestClose 回调上行，
   *      由持有 bindContentCover 的父页面把 isShow 置 false 收起全模态页面。
   */
  @Prop isOpen: boolean = false;
  /**
   * 关闭请求回调（由父页面构造时传入；子组件绝不自持关闭语义）。
   * 说明：官方《@Prop装饰器》限制条件明确「@Prop不支持装饰Function类型的变量...
   *      从API version 23开始，在应用编译时添加了相关校验...应在代码中删除Function类型变量的@Prop装饰器」。
   *      本工程 compatibleSdkVersion = 6.1.1(24) 命中该校验，故此处为**无装饰器常规成员变量**。
   *      回调引用在构造后不再变化，无需响应式；仅在事件回调中读取。
   */
  onRequestClose: () => void = () => {};
  /** 待预览图片的 rawfile 相对路径（父页面传入，本组件只读） */
  @Prop @Watch('onPathChanged') path: string = '';

  /**
   * 当前可视区较长边（vp）。
   * 说明：由根 Stack 的 onAreaChange 实测写入（Area 的 width/height 单位即 vp，
   *      与 GestureEvent.offsetX/offsetY 单位一致，无需 px↔vp 换算）。
   */
  @State viewportSpan: number = FALLBACK_VIEWPORT_SPAN;

  /** 当前缩放倍率（1.0 = 原尺寸，仅内存瞬态） */
  @State scaleValue: number = 1;
  /** 当前平移偏移（vp，作用于图片本体 translate） */
  @State offsetX: number = 0;
  @State offsetY: number = 0;

  /** 本次捏合的起始倍率（onActionStart 采样） */
  private pinchStartScale: number = 1;
  /** 本次平移的起始偏移（onActionStart 采样） */
  private panStartX: number = 0;
  private panStartY: number = 0;
  /** 平移中位（onActionUpdate 采样，供结束日志取证） */
  private panCurrentX: number = 0;
  private panCurrentY: number = 0;

  build() {
    Stack() {
      // 图片本体：Contain 保证长宽比不失真；scale 与 translate 仅作用于图片，黑底不变形
      Image($rawfile(this.path))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .scale({ x: this.scaleValue, y: this.scaleValue, z: 1 })
        .translate({ x: this.offsetX, y: this.offsetY, z: 0 })
        .gesture(
          GestureGroup(GestureMode.Parallel,
            // 双指捏合：更新缩放倍率
            PinchGesture({ fingers: 2 })
              .onActionStart((event: GestureEvent) => {
                this.pinchStartScale = this.scaleValue;
                Logger.debug(MODULE_TAG, `pinch start, base=${this.pinchStartScale}`);
              })
              .onActionUpdate((event: GestureEvent) => {
                this.applyScale(this.pinchStartScale * event.scale);
              })
              .onActionEnd(() => {
                Logger.info(MODULE_TAG, `pinch end, scale=${this.scaleValue}`);
              })
              .onActionCancel(() => {
                Logger.debug(MODULE_TAG, `pinch cancel, scale=${this.scaleValue}`);
              }),
            // 单指拖动平移：仅在放大状态下响应（scale == 1.0 时直接不进入手势，零状态写入）
            PanGesture({ fingers: 1, isFingerCountLimited: true })
              .onActionStart((event: GestureEvent) => {
                if (this.scaleValue <= SCALE_UNIT) {
                  return;
                }
                this.panStartX = this.offsetX;
                this.panStartY = this.offsetY;
                Logger.debug(MODULE_TAG, `pan start, scale=${this.scaleValue}`);
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.scaleValue <= SCALE_UNIT) {
                  return;
                }
                this.applyPan(this.panStartX + event.offsetX, this.panStartY + event.offsetY);
              })
              .onActionEnd(() => {
                if (this.scaleValue <= SCALE_UNIT) {
                  return;
                }
                Logger.info(MODULE_TAG,
                  `pan end, offset=(${this.panCurrentX},${this.panCurrentY}) scale=${this.scaleValue}`);
              })
          )
        )

      // 右上角关闭字形：为侧滑/返回键被系统占用时提供确定性退出路径
      Text(GLYPH_CLOSE)
        .fontSize(AppDimens.FONT_SIZE_CLOSE_GLYPH)
        .fontColor(AppColors.OVERLAY_CLOSE)
        .padding(AppDimens.SPACING_MD)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.OVERLAY_BACKDROP)
    .alignContent(Alignment.Center)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.onViewportChanged(newValue);
    })
    .onClick(() => {
      this.closePreview();
    })
  }

  /**
   * 缩放倍率夹取：把捏合原始倍率收敛到 [1.0, 4.0] 闭区间。
   * 说明：抽为独立纯函数，便于后续单测；1.0 为下限，保证「缩小到比原图更小」这一无意义状态不出现。
   *      本函数仅做数值比较与赋值，不抛异常、不打日志——避免在捏合高频回调中产生日志开销。
   */
  private clampScale(value: number): number {
    if (value < MIN_SCALE) {
      return MIN_SCALE;
    }
    if (value > MAX_SCALE) {
      return MAX_SCALE;
    }
    return value;
  }

  /** 应用缩放：夹取后直接写状态，无分支副作用。 */
  private applyScale(raw: number): void {
    this.scaleValue = this.clampScale(raw);
  }

  /**
   * 平移量夹取（软限制）：把偏移收敛到 ±(缩放后组件盒半边长度 × 安全系数 × 阻尼)。
   * 说明：offset 单位为 vp，与 GestureEvent.offsetX / offsetY 单位一致。
   *      为提高可读性与可测性，此处使用同一套 vp 基准做归一化（不引入单位换算模块）。
   */
  private clampOffset(value: number, scale: number): number {
    const span: number = this.viewportSpan;
    let limit: number = span * PAN_SAFE_RATIO * (scale - SCALE_UNIT) * PAN_DAMPING;
    if (limit < 0) {
      limit = 0;
    }
    if (value < -limit) {
      return -limit;
    }
    if (value > limit) {
      return limit;
    }
    return value;
  }

  /** 应用平移：夹取后写状态。high-frequency 回调内不打日志，避免性能告警。 */
  private applyPan(rawX: number, rawY: number): void {
    this.offsetX = this.clampOffset(rawX, this.scaleValue);
    this.offsetY = this.clampOffset(rawY, this.scaleValue);
    this.panCurrentX = this.offsetX;
    this.panCurrentY = this.offsetY;
  }

  /**
   * 可视区尺寸回调：记录根 Stack 的实际边长（vp），供平移软边界使用。
   * 说明：onAreaChange 只响应布局变化，不响应 translate / scale 等绘制变化，
   *      故本组件自身的缩放与平移不会反复触发该回调。
   *      Area 的 width/height 静态类型为 Length（string | number | Resource），
   *      文档载明「单位：vp」，故此处显式收窄为 number（number 直接用，其余经字符串解析）。
   */
  private onViewportChanged(newValue: Area): void {
    const width: number = ImageViewerOverlay.toVp(newValue.width);
    const height: number = ImageViewerOverlay.toVp(newValue.height);
    this.viewportSpan = width > height ? width : height;
  }

  /** 把 Area 的 Length 值收窄为 vp 数值；无法解析时回退为保守常量。 */
  private static toVp(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value);
      return Number.isNaN(parsed) ? FALLBACK_VIEWPORT_SPAN : parsed;
    }
    return FALLBACK_VIEWPORT_SPAN;
  }

  /** 关闭预览：以回调方式把用户意图上行给父页面，由父页面收起全模态页面。 */
  private closePreview(): void {
    Logger.info(MODULE_TAG, `close requested, finalScale=${this.scaleValue}`);
    this.onRequestClose();
  }

  /** 切换图片时复位缩放与平移，避免上一张的视图状态串到下一张。 */
  private onPathChanged(): void {
    this.scaleValue = MIN_SCALE;
    this.offsetX = 0;
    this.offsetY = 0;
    this.pinchStartScale = MIN_SCALE;
    this.panStartX = 0;
    this.panStartY = 0;
    this.panCurrentX = 0;
    this.panCurrentY = 0;
    Logger.debug(MODULE_TAG, `path changed, view state reset for ${this.path}`);
  }
}
