import { AppColors } from '../../../constants/AppColors';
import { AppDimens } from '../../../constants/AppDimens';

/**
 * 分类栏高度（vp）。
 * 说明：该高度是本组件内在的控件尺寸（胶囊高度 + 上下留白），
 *      非跨模块设计系统数值，故就近声明而不污染全局 AppDimens。
 */
const CATEGORY_BAR_HEIGHT: number = 44;

/**
 * 胶囊单选筛选栏（通用组件）。
 *
 * 职责：把「一组候选标签 + 当前选中项」渲染为水平滚动胶囊条，并负责选中态高亮；
 *      选择结果通过回调上抛给父页面。
 * 通用性（C-1 参数改名后）：入参为标签无关的字符串数组，可同时承载
 *      **分类维度**（category）与**难度维度**（level）两套筛选，故本组件不再是
 *      category 专属；参数名已从 categories / onCategorySelected 收敛为
 *      options / onSelected，避免语义误导。
 * 分层约束：本组件只做渲染与事件上抛，不持有任何数据源、不发起任何 I/O。
 */
@Component
export struct CategoryBar {
  /** 候选标签清单（首项约定为「全部」；调用方决定其取值来源） */
  @Prop options: string[] = [];
  /** 当前选中标签 */
  @Prop selected: string = '';
  /** 选中回调：通知父组件切换选中项 */
  onSelected: (option: string) => void = () => {};

  build() {
    // 横向滚动使用 List + ListItem 容器（遵循工程列表渲染规范）
    List({ space: AppDimens.SPACING_SM }) {
      // key 采用「下标-标签」复合形式：本组件被同页复用于分类与难度两条筛选栏，
      // 若仅以标签文本作 key，两栏出现同名标签（如两处「全部」）将导致 key 冲突。
      ForEach(this.options, (item: string, index: number) => {
        ListItem() {
          Text(item)
            .fontSize(AppDimens.FONT_SIZE_BODY)
            .fontWeight(this.selected === item ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.selected === item ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
            .padding({
              left: AppDimens.SPACING_MD,
              right: AppDimens.SPACING_MD,
              top: AppDimens.SPACING_XS,
              bottom: AppDimens.SPACING_XS
            })
            .borderRadius(AppDimens.RADIUS_SM)
            .backgroundColor(this.selected === item ? AppColors.PRIMARY_LIGHT : AppColors.SURFACE)
            .onClick(() => {
              this.onSelected(item);
            })
        }
      }, (item: string, index: number) => `${index}-${item}`)
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(CATEGORY_BAR_HEIGHT)
  }
}
