import { AppColors } from '../constants/AppColors';
import { AppDimens } from '../constants/AppDimens';
import { AppStrings } from '../constants/AppStrings';
import { HomePage } from '../pages/home/HomePage';
import { LearnPage } from '../pages/learn/LearnPage';
import { ProjectsPage } from '../pages/projects/ProjectsPage';
import { PracticePage } from '../pages/practice/PracticePage';
import { ProfilePage } from '../pages/profile/ProfilePage';

/**
 * 根 Tab 容器。
 *
 * 职责：承载 5 个一级 TabContent 的布局与组织，避免 MainPage 代码膨胀。
 * 约束：
 *  - 本组件内部严禁创建 NavPathStack，也不得嵌套独立 Navigation 容器。
 *  - 二级页面统一压入 MainPage 提供的唯一根 NavPathStack。
 */
@Component
export struct RootTabContainer {
  /** 当前选中的 Tab 下标 */
  @State currentIndex: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.tabBarBuilder(0, AppStrings.TAB_HOME))

      TabContent() {
        LearnPage()
      }
      .tabBar(this.tabBarBuilder(1, AppStrings.TAB_LEARN))

      TabContent() {
        ProjectsPage()
      }
      .tabBar(this.tabBarBuilder(2, AppStrings.TAB_PROJECTS))

      TabContent() {
        PracticePage()
      }
      .tabBar(this.tabBarBuilder(3, AppStrings.TAB_PRACTICE))

      TabContent() {
        ProfilePage()
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
    // 补上核心事件：同步真实切换的 index，保证文字高亮响应式刷新
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }

  /** 底部 Tab 项 */
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