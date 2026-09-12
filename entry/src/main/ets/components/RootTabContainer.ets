import { AppColors } from '../constants/AppColors';
import { AppDimens } from '../constants/AppDimens';
import { AppStrings } from '../constants/AppStrings';
import { LearnPage } from '../pages/learn/LearnPage';

/**
 * 根 Tab 容器。
 *
 * 职责：承载 5 个一级 TabContent 的布局与组织，避免 MainPage 代码膨胀。
 * 约束：
 *  - 本组件内部严禁创建 NavPathStack，也不得嵌套独立 Navigation 容器。
 *  - 二级页面统一压入 MainPage 创建的唯一根 NavPathStack。
 * 性能约定（对齐 @performance/avoid-overusing-custom-component-check）：
 *  - 骨架阶段的 Tab 内容统一使用 @Builder 函数渲染，不引入自定义组件，
 *    避免在 FrameNode 节点树上产生多余节点、拖慢首屏渲染。
 *  - Learn 页已在 Milestone 2.1 具备真实 ViewModel 与业务内容，故改为挂载真实页面组件；
 *    其余 4 个 Tab 仍保持 @Builder 占位，待各自里程碑落地后再切换。
 */
@Component
export struct RootTabContainer {
  /** 当前选中的 Tab 下标 */
  @State currentIndex: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        this.tabPlaceholder(AppStrings.HOME_PLACEHOLDER_TITLE, AppStrings.HOME_PLACEHOLDER_DESC)
      }
      .tabBar(this.tabBarBuilder(0, AppStrings.TAB_HOME))

      TabContent() {
        LearnPage()
      }
      .tabBar(this.tabBarBuilder(1, AppStrings.TAB_LEARN))

      TabContent() {
        this.tabPlaceholder(AppStrings.PROJECTS_PLACEHOLDER_TITLE, AppStrings.PROJECTS_PLACEHOLDER_DESC)
      }
      .tabBar(this.tabBarBuilder(2, AppStrings.TAB_PROJECTS))

      TabContent() {
        this.tabPlaceholder(AppStrings.PRACTICE_PLACEHOLDER_TITLE, AppStrings.PRACTICE_PLACEHOLDER_DESC)
      }
      .tabBar(this.tabBarBuilder(3, AppStrings.TAB_PRACTICE))

      TabContent() {
        this.tabPlaceholder(AppStrings.PROFILE_PLACEHOLDER_TITLE, AppStrings.PROFILE_PLACEHOLDER_DESC)
      }
      .tabBar(this.tabBarBuilder(4, AppStrings.TAB_PROFILE))
    }
    .barMode(BarMode.Fixed)
    .barHeight(AppDimens.TAB_BAR_HEIGHT)
    .barBackgroundColor(AppColors.SURFACE)
    .scrollable(true)
    .animationDuration(0)
    .width('100%')
    .height('100%')
    // 同步真实切换的 index，保证文字高亮响应式刷新
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }

  /**
   * 一级 Tab 统一占位内容。
   * 说明：使用 @Builder 而非自定义组件，避免多余 FrameNode 节点开销。
   */
  @Builder
  tabPlaceholder(title: string, description: string) {
    Column() {
      // 标题区
      Row() {
        Text(title)
          .fontSize(AppDimens.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
      }
      .width('100%')
      .padding({
        left: AppDimens.SPACING_LG,
        right: AppDimens.SPACING_LG,
        top: AppDimens.SPACING_LG,
        bottom: AppDimens.SPACING_SM
      })

      // 主体占位区
      Column({ space: AppDimens.SPACING_SM }) {
        Text(description)
          .fontSize(AppDimens.FONT_SIZE_BODY)
          .fontColor(AppColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
        Text(AppStrings.PLACEHOLDER_DESC)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_TERTIARY)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(AppDimens.SPACING_XL)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /** 底部 Tab 项：V1 仅文字标签，图形图标资源后续按设计补充。 */
  @Builder
  tabBarBuilder(index: number, label: string) {
    Column() {
      Text(label)
        .fontSize(AppDimens.FONT_SIZE_TAB)
        .fontColor(this.currentIndex === index ? AppColors.PRIMARY : AppColors.TEXT_TERTIARY)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
