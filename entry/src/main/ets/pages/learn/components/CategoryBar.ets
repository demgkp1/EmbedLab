import { AppColors } from '../../../constants/AppColors';
import { AppDimens } from '../../../constants/AppDimens';

/**
 * 分类栏高度（vp）。
 * 说明：该高度是本组件内在的控件尺寸（胶囊高度 + 上下留白），
 *      非跨模块设计系统数值，故就近声明而不污染全局 AppDimens。
 */
const CATEGORY_BAR_HEIGHT: number = 44;

/**
 * 知识分类胶囊筛选栏。
 *
 * 职责：基于知识元数据中的 category 生成水平滚动胶囊标签，首项为「全部」，
 *      并负责选中态高亮渲染；选择结果通过回调上抛给父页面。
 * 分层约束：本组件只做渲染与事件上抛，不持有任何数据源、不发起任何 I/O。
 */
@Component
export struct CategoryBar {
  /** 分类文案清单（首项为「全部」） */
  @Prop categories: string[] = [];
  /** 当前选中分类 */
  @Prop selected: string = '';
  /** 选中回调：通知父组件切换分类 */
  onCategorySelected: (category: string) => void = () => {};

  build() {
    // 横向滚动使用 List + ListItem 容器（遵循工程列表渲染规范）
    List({ space: AppDimens.SPACING_SM }) {
      ForEach(this.categories, (category: string) => {
        ListItem() {
          Text(category)
            .fontSize(AppDimens.FONT_SIZE_BODY)
            .fontWeight(this.selected === category ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.selected === category ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
            .padding({
              left: AppDimens.SPACING_MD,
              right: AppDimens.SPACING_MD,
              top: AppDimens.SPACING_XS,
              bottom: AppDimens.SPACING_XS
            })
            .borderRadius(AppDimens.RADIUS_SM)
            .backgroundColor(this.selected === category ? AppColors.PRIMARY_LIGHT : AppColors.SURFACE)
            .onClick(() => {
              this.onCategorySelected(category);
            })
        }
      }, (category: string) => category)
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(CATEGORY_BAR_HEIGHT)
  }
}
