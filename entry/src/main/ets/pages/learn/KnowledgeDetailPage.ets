import { deviceInfo } from '@kit.BasicServicesKit';
import uiMaterial from '@ohos.arkui.uiMaterial';
import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { UIStatus } from '../../models/common/UIStatus';
import { ContentBlock, KnowledgeItem } from '../../models/knowledge/KnowledgeItem';
import { KnowledgeDetailParams } from '../../models/knowledge/KnowledgeDetailParams';
import { KnowledgeDetailViewModel } from '../../viewmodels/KnowledgeDetailViewModel';
import { GeekCodeBlock } from './components/GeekCodeBlock';
import { ImageViewerOverlay } from './components/ImageViewerOverlay';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'KnowledgeDetailPage';

/**
 * 图片块最小点击热区高度（vp）。
 * 说明：官方 Code Linter 规则要求「主要交互元素可点击热区至少 48vp×48vp（推荐），不得小于 40vp×40vp」。
 *      超宽图（如 stage5_adc_sensor 宽高比 12.06）在手机竖屏下渲染高仅约 30vp，点击容错≈0，
 *      故对承载图片的 Column 施加最小高度约束以扩大热区；图片本身用 ImageFit.Contain，
 *      官方语义为「保持宽高比…完全显示在显示边界内」，故视觉尺寸不变形，仅在下方留白。
 *      取值 = AppDimens.SPACING_XL(24) × 2 = 48vp，直接对齐官方推荐值，不引入新的魔法数字。
 */
const MIN_IMAGE_TAP_HEIGHT: number = AppDimens.SPACING_XL * 2;

/**
 * 标题栏沉浸光感材质适配器（UI-Immersion-1）。
 *
 * 为什么用 AttributeModifier 而不是直接写 .title(..., { systemMaterial: ... })：
 *  1. systemMaterial 依赖的 uiMaterial 起始版本为 26.0.0，而本工程
 *     compatibleSdkVersion = 6.1.1(24)。直接引用会在编译期产生
 *     "supported since SDK version 26.0.0 ... recommended to use apiAvailable"
 *     告警，且官方文档明确指出：compatibleSdkVersion 设低时，未受保护地调用
 *     高版本 API 会导致应用在低版本系统上崩溃。
 *  2. 官方对「属性级」兼容性保护的标准解法即 AttributeModifier +
 *     applyNormalAttribute 内以 if (deviceInfo.apiAvailable('<字面量>')) 保护。
 *     告警消除仅支持该结构（不支持取反 / && / || / 三元 / 封装），故此处严格遵循。
 *
 * 降级行为（经人类架构师裁决）：设备不支持时不设置材质（material 保持 undefined），
 *      即「无材质效果」，绝不改变标题栏的既有渲染与交互，属受控降级。
 */
class TitleMaterialModifier implements AttributeModifier<NavDestinationAttribute> {
  /**
   * 标题栏材质。
   * 默认 undefined = 不设置材质（即无光感效果），仅在设备能力满足时替换为
   * ImmersiveMaterial 实例，故设备不支持时行为等同于改动前，绝不崩溃。
   *
   * 说明：这里显式标注官方类型，但对象构造放在受 apiAvailable 保护的
   *      resolveMaterial 内完成 —— 该写法经干净全量构建验证不再产生
   *      "supported since SDK version 26.0.0" 告警（详见 resolveMaterial 注释）。
   */
  private material: uiMaterial.Material | undefined = undefined;

  /**
   * 按设备能力解析材质（幂等：已解析则直接返回，不在渲染期重复构造）。
   *
   * 告警消除生效点：裸 if + 纯字面量版本号（禁用取反 / && / || / 三元 / 封装）。
   * 取证结论（干净全量构建）：整个材质构造路径均置于
   *      if (deviceInfo.apiAvailable('26.0.0')) 之下时，不再产生
   *      "supported since SDK version 26.0.0" 告警；此前把构造直接写在
   *      「字段初始化器 / 构造器」中的两轮构建均带出该告警。
   *      注意：本工程 compatibleSdkVersion = 6.1.1(24)，该保护为必需项，
   *      不可因告警消失而移除。
   */
  private resolveMaterial(): void {
    if (this.material !== undefined) {
      return;
    }
    if (deviceInfo.apiAvailable('26.0.0')) {
      this.material = new uiMaterial.ImmersiveMaterial();
    }
  }

  /**
   * 渲染期应用属性。
   * 同样以裸 if 保护：确保低版本设备上不会执行到未受支持的 API。
   * 不使用 @State / @Prop / @Link：本类实例全程不变。
   */
  applyNormalAttribute(instance: NavDestinationAttribute): void {
    this.resolveMaterial();
    if (deviceInfo.apiAvailable('26.0.0')) {
      instance.title(this.navTitle, { systemMaterial: this.material });
    }
  }

  /** 标题栏文案（由页面在 onReady 中写入；未传则回退通用标题）。 */
  private navTitle: string = AppStrings.DETAIL_DEFAULT_TITLE;

  /** 页面侧同步标题文案到适配器。 */
  setNavTitle(value: string): void {
    this.navTitle = value;
  }
}

/**
 * 知识详情页。
 *
 * 职责：由 NavDestination 承载，在 onReady 中提取强类型路由参数，按需加载正文，
 *      并依据 contentBlocks 的动态顺序渲染富文本（标题 / 正文 / 图片 / 代码 / 警示）。
 * 约束：
 *  - 严禁直接调用 Repository，一切数据与错误映射收敛在 KnowledgeDetailViewModel。
 *  - 严禁在 build() 内修改状态；状态变更只发生在生命周期与事件回调。
 *  - 严禁阻塞主线程：加载为异步 Promise，配合 refreshFlag 哨兵触发重绘。
 *  - 保留 NavDestination 原生返回箭头（严禁 hideTitleBar(true)），由系统接管 pop。
 */
@Component
export struct KnowledgeDetailPage {
  /** 页面级 ViewModel */
  @State viewModel: KnowledgeDetailViewModel = new KnowledgeDetailViewModel();

  /**
   * 重绘哨兵。
   * 说明：ArkUI 的 @State 不深层监听类实例内部属性变化，异步加载完成后翻转本布尔值
   *      以强制驱动 build() 重执行。仅可在生命周期与事件回调中翻转。
   */
  @State refreshFlag: boolean = false;

  /** 当前知识 id（onReady 提取后保存，供重试使用） */
  private currentId: string = '';
  /** 标题栏文案（onReady 提取，未传则回退通用标题） */
  @State navTitle: string = AppStrings.DETAIL_DEFAULT_TITLE;
  /**
   * 收藏态（页面级镜像）。
   * 说明：标题栏星标需即时变色，而 UserStore 为 @Observed 单例、@State 不深层监听其内部属性，
   *      故把收藏态镜像为页面自身的 @State，由 toggleFavorite 成功后显式同步。
   */
  @State isFav: boolean = false;

  /**
   * 全屏图片预览开关（Milestone 3.5）。
   * 说明：经 $$ 双向绑定下沉至 bindContentCover 的 isShow（该参数官方自 API 10 起支持 $$，
   *      且本页 @Builder 内的组件调用不使用 $$，改为单向 @Prop + onRequestClose 回调上行）。
   */
  @State isPreviewOpen: boolean = false;
  /** 待预览图片的 rawfile 相对路径（与 image 块 content 同源，不做任何拼接） */
  @State previewPath: string = '';

  /**
   * 标题栏沉浸光感材质适配器（UI-Immersion-1）。
   * 说明：经 .attributeModifier() 挂载到 NavDestination；材质构造与
   *      apiAvailable 兼容性保护全部收敛在适配器内部（见文件头 TitleMaterialModifier）。
   *      本实例全程不变，故用无装饰器普通成员，严禁加 @State / @Prop / @Link。
   */
  private titleMaterialModifier: TitleMaterialModifier = new TitleMaterialModifier();

  build() {
    NavDestination() {
      Column() {
        if (this.viewModel.uiStatus === UIStatus.LOADING) {
          this.stateHint(AppStrings.DETAIL_LOADING, '')
        } else if (this.viewModel.uiStatus === UIStatus.EMPTY) {
          this.stateHint(AppStrings.DETAIL_EMPTY_TITLE, AppStrings.DETAIL_EMPTY_DESC)
        } else if (this.viewModel.uiStatus === UIStatus.ERROR) {
          this.errorState()
        } else {
          this.contentState()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BACKGROUND)
      // M3.5-d：全页唯一 bindContentCover 绑定点（本 Column 为 NavDestination 唯一直接子节点，
      // 且不随 uiStatus 分支与 ForEach 重复）。此前每个 image 块各挂一个绑定却共享同一
      // @State isPreviewOpen，属官方未定义行为，是"成功章节无规律"的根因。
      .bindContentCover($$this.isPreviewOpen, this.previewOverlay(), ModalTransition.DEFAULT)
    }
    .attributeModifier(this.titleMaterialModifier)
    .menus(this.favoriteMenu)
    .backgroundColor(AppColors.SURFACE)
    .onReady((context: NavDestinationContext) => {
      this.handleReady(context);
    })
  }

  /**
   * 标题栏右侧收藏按钮。
   * 说明：工程无星标图标资源，故用 CustomBuilder 渲染字形（★ / ☆）；
   *      点击为 fire-and-forget，内部 Promise 失败仅记录日志，绝不阻塞 UI 线程。
   */
  @Builder
  favoriteMenu() {
    Row() {
      Text(this.isFav ? AppStrings.GLYPH_STAR_FILLED : AppStrings.GLYPH_STAR_OUTLINE)
        .fontSize(AppDimens.FAVORITE_GLYPH_SIZE)
        .fontColor(this.isFav ? AppColors.FAVORITE_ACTIVE : AppColors.TEXT_SECONDARY)
        .padding({
          left: AppDimens.SPACING_SM,
          right: AppDimens.SPACING_SM
        })
        .onClick(() => {
          this.onToggleFavorite();
        })
    }
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 收藏点击处理：fire-and-forget 调用 ViewModel，成功后同步页面镜像态。
   * 状态同步铁律：ViewModel 内部保证「持久化成功后才更新 UserStore」；
   * 本方法仅在整体成功后才翻转 isFav。
   */
  private onToggleFavorite(): void {
    this.viewModel.toggleFavorite()
      .then(() => {
        this.isFav = this.viewModel.isFavorite();
        Logger.info(MODULE_TAG, `favorite state synced: isFav=${this.isFav}`);
      })
      .catch((err: Object) => {
        const message: string = err instanceof Error ? err.message : `${err}`;
        Logger.error(MODULE_TAG, `toggleFavorite unexpected: ${message}`);
      });
  }

  /**
   * onReady 生命周期：提取强类型路由参数并触发按需加载。
   * 说明：后续 NavDestination 以 MOVE_TO_TOP_SINGLETON 复用时 onReady 可能不再触发，
   *      故本方法做了重复入参的幂等保护（同 id 不重复加载）。
   */
  private handleReady(context: NavDestinationContext): void {
    const params: KnowledgeDetailParams = context.pathInfo.param as KnowledgeDetailParams;
    if (params === undefined || params.id === undefined || params.id.length === 0) {
      this.viewModel.uiStatus = UIStatus.ERROR;
      Logger.error(MODULE_TAG, 'onReady: invalid route params, missing id');
      return;
    }
    const title: string | undefined = params.title;
    if (title !== undefined && title.length > 0) {
      this.navTitle = title;
      // 同步到材质适配器：NavDestination 的标题栏由适配器经 attributeModifier 挂载，
      // 必须在 applyNormalAttribute 重执行前把最新文案写入适配器，二者保持一致。
      this.titleMaterialModifier.setNavTitle(title);
    }
    if (this.currentId === params.id) {
      return;
    }
    this.currentId = params.id;
    Logger.info(MODULE_TAG, `onReady id=${params.id}`);
    this.loadDetail();
  }

  /** 触发/重试加载（生命周期与重试按钮共用入口）。 */
  private loadDetail(): void {
    if (this.currentId.length === 0) {
      return;
    }
    this.viewModel.loadDetail(this.currentId).then(() => {
      this.refreshFlag = !this.refreshFlag;
      // 仅在加载成功（SUCCESS 态）时记录一次阅读足迹；
      // 足迹由 ViewModel 调度 UserRepository 持久化，成功后才更新 UserStore。
      if (this.viewModel.uiStatus === UIStatus.SUCCESS) {
        // 同步收藏态镜像（从收藏列表进入时星标必须立即为实心）
        this.isFav = this.viewModel.isFavorite();
        this.viewModel.recordHistory();
      }
    });
  }

  /** SUCCESS 态：按 contentBlocks 顺序动态渲染富文本正文。 */
  @Builder
  contentState() {
    Scroll() {
      Column({ space: AppDimens.SPACING_LG }) {
        this.headerBlock()

        ForEach(this.blocksOrDefault(), (block: ContentBlock, index: number) => {
          if (block.type === 'header') {
            this.blockHeader(block.content)
          } else if (block.type === 'text') {
            this.blockText(block.content)
          } else if (block.type === 'image') {
            this.blockImage(block.content)
          } else if (block.type === 'warning') {
            this.blockWarning(block.content)
          } else {
            this.blockCode(block.content, block.language === undefined ? '' : block.language)
          }
        }, (block: ContentBlock, index: number) => `${block.type}_${index}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(AppDimens.SPACING_LG)
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
  }

  /** 正文头部：标题 + 分类 + 难度 + 标签。 */
  @Builder
  headerBlock() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(this.itemOrDefault().title)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')

      Row({ space: AppDimens.SPACING_SM }) {
        Text(this.itemOrDefault().category)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .layoutWeight(1)
        Text(this.itemOrDefault().level)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.PRIMARY)
          .backgroundColor(AppColors.PRIMARY_LIGHT)
          .padding({
            left: AppDimens.SPACING_SM,
            right: AppDimens.SPACING_SM,
            top: AppDimens.SPACING_XS,
            bottom: AppDimens.SPACING_XS
          })
          .borderRadius(AppDimens.RADIUS_SM)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.itemOrDefault().tags, (tag: string) => {
          Text(tag)
            .fontSize(AppDimens.FONT_SIZE_CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
            .backgroundColor(AppColors.BACKGROUND)
            .padding({
              left: AppDimens.SPACING_SM,
              right: AppDimens.SPACING_SM,
              top: AppDimens.SPACING_XS,
              bottom: AppDimens.SPACING_XS
            })
            .borderRadius(AppDimens.RADIUS_SM)
            .margin({ right: AppDimens.SPACING_XS, bottom: AppDimens.SPACING_XS })
        }, (tag: string) => `detail-tag-${tag}`)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** header 块：章节标题，较大字号 + 加粗 + 上下留白。 */
  @Builder
  blockHeader(text: string) {
    Text(text)
      .fontSize(AppDimens.FONT_SIZE_TITLE)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppColors.TEXT_PRIMARY)
      .width('100%')
      .margin({ top: AppDimens.SPACING_SM })
  }

  /** text 块：普通正文段落，lineHeight 增强阅读体验。 */
  @Builder
  blockText(text: string) {
    Text(text)
      .fontSize(AppDimens.FONT_SIZE_BODY)
      .fontColor(AppColors.TEXT_SECONDARY)
      .lineHeight(AppDimens.LINE_HEIGHT_BODY)
      .width('100%')
      .copyOption(CopyOptions.InApp)
  }

  /**
   * image 块：直接以 block.content 作为 rawfile 路径，不做任何字符串拼接。
   * Milestone 3.5-d（结构收敛）：
   *  - 本块**不再挂载 bindContentCover**（全页唯一点已上移至 build() 的根 Column），只保留点击触发。
   *  - 承载 Column 施加 MIN_IMAGE_TAP_HEIGHT 最小高度约束：图片视觉尺寸不变（ImageFit.Contain
   *    官方语义为保持宽高比、完全显示在边界内），但可点击热区不低于官方 48vp 推荐值。
   */
  @Builder
  blockImage(path: string) {
    Column() {
      Image($rawfile(path))
        .width('100%')
        .objectFit(ImageFit.Contain)
        .borderRadius(AppDimens.RADIUS_SM)
    }
    .width('100%')
    .constraintSize({ minHeight: MIN_IMAGE_TAP_HEIGHT })
    .onClick(() => {
      this.openPreview(path);
    })
  }

  /**
   * 全模态预览内容（唯一根节点为叠加层组件）。
   * 说明：关闭语义留在本页——叠加层点击关闭时经 onRequestClose 回调上行，
   *      由本页把 isPreviewOpen 置 false，bindContentCover 随即收起全模态页面。
   *      故子组件只需 @Prop 单向接收，不使用 @Link（@Builder 内传 $$ 双向绑定不被接受）。
   */
  @Builder
  previewOverlay() {
    ImageViewerOverlay({
      isOpen: this.isPreviewOpen,
      path: this.previewPath,
      onRequestClose: (): void => {
        this.closePreview();
      }
    })
  }

  /** 打开全屏预览：先落盘路径再翻转开关，保证叠加层以正确图片入帧。 */
  private openPreview(path: string): void {
    if (path.length === 0) {
      Logger.warn(MODULE_TAG, 'openPreview: empty image path, ignored');
      return;
    }
    this.previewPath = path;
    this.isPreviewOpen = true;
    Logger.info(MODULE_TAG, `open preview: ${path}`);
  }

  /** 关闭全屏预览（由叠加层的关闭请求回调触发）。 */
  private closePreview(): void {
    this.isPreviewOpen = false;
    Logger.info(MODULE_TAG, 'preview closed by user request');
  }

  /** warning 块：浅色底 + 圆角 + 醒目前缀。 */
  @Builder
  blockWarning(text: string) {
    Text(AppStrings.WARNING_PREFIX + text)
      .fontSize(AppDimens.FONT_SIZE_BODY)
      .fontColor(AppColors.TEXT_PRIMARY)
      .lineHeight(AppDimens.LINE_HEIGHT_BODY)
      .width('100%')
      .padding(AppDimens.SPACING_MD)
      .backgroundColor(AppColors.WARNING_BG)
      .borderRadius(AppDimens.RADIUS_MD)
      .copyOption(CopyOptions.InApp)
  }

  /** code 块：交由极客代码块组件渲染，并支持一键原样复制。 */
  @Builder
  blockCode(code: string, language: string) {
    GeekCodeBlock({ code: code, language: language })
  }

  /** 通用状态提示（LOADING / EMPTY）。 */
  @Builder
  stateHint(title: string, description: string) {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(title)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      if (description.length > 0) {
        Text(description)
          .fontSize(AppDimens.FONT_SIZE_BODY)
          .fontColor(AppColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
  }

  /** ERROR 态：错误提示 + 语义化错误码 + 重试。 */
  @Builder
  errorState() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.DETAIL_ERROR_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text(`${this.viewModel.lastErrorCode}`)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.TEXT_TERTIARY)
      Button(AppStrings.MSG_RETRY)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .backgroundColor(AppColors.PRIMARY)
        .onClick(() => {
          this.loadDetail();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
  }

  /** 取详情实体（成功态下必然非空，此处提供安全兜底避免空引用）。 */
  private itemOrDefault(): KnowledgeItem {
    const item: KnowledgeItem | null = this.viewModel.detailItem;
    if (item !== null) {
      return item;
    }
    const empty: KnowledgeItem = {
      id: '',
      title: '',
      category: '',
      level: '',
      tags: [],
      summary: '',
      images: [],
      contentBlocks: [],
      relatedProjectIds: []
    };
    return empty;
  }

  /** 取正文块序列（安全兜底为空数组）。 */
  private blocksOrDefault(): ContentBlock[] {
    const item: KnowledgeItem | null = this.viewModel.detailItem;
    if (item !== null) {
      return item.contentBlocks;
    }
    const empty: ContentBlock[] = [];
    return empty;
  }
}
