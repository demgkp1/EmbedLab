import { AppColors } from '../constants/AppColors';
import { AppDimens } from '../constants/AppDimens';
import { AppStrings } from '../constants/AppStrings';
import { LearnPage } from '../pages/learn/LearnPage';
import { ProfilePage } from '../pages/profile/ProfilePage';
import { HomePage } from '../pages/home/HomePage';

/**
 * 根 Tab 容器。
 *
 * 职责：承载 3 个一级 TabContent 的布局与组织，避免 MainPage 代码膨胀。
 * 约束：
 *  - 本组件内部严禁创建 NavPathStack，也不得嵌套独立 Navigation 容器。
 *  - 二级页面统一压入 MainPage 创建的唯一根 NavPathStack。
 * 性能约定（对齐 @performance/avoid-overusing-custom-component-check）：
 *  - 一级 Tab 内统一挂载真实页面组件，不在本组件内展开业务布局，
 *    避免在 FrameNode 节点树上产生多余节点、拖慢首屏渲染。
 *  - Home 页已在 Milestone B 点亮为真实页面；Learn 页（Milestone 2.1）与
 *    Profile 页（Milestone 3.4 / Profile-R）均为真实页面组件。
 *  - UI-Batch-1（阶段一）：原「项目」「练习」两个 @Builder 占位 Tab 已移除，
 *    底部 Tab 由 5 个收敛为 3 个（首页 / 学习 / 我的），其占位 @Builder 一并删除。
 * 跨 Tab 刷新广播（Milestone 3.4-fix）：
 *  - TabContent 切换是 Tabs 内部状态，**不会触发子页面的 onPageShow**；
 *    而详情页返回时子页面同样不感知，导致 Profile 概览与 Learn 星标不刷新。
 *  - 故由本组件通过 @Provide('rootTabIndex') 广播当前下标，
 *    子页面以 @Consume + @Watch 监听并在切回自身时执行刷新。
 *  - 严禁改用 AppStorage / EventHub 等替代机制（V1 阶段不引入）。
 */
@Component
export struct RootTabContainer {
  /**
   * 当前选中的 Tab 下标 —— 同时充当 Tabs.index 的绑定源与跨 Tab 广播源（B-fix-3 方案 A-2）。
   *
   * 说明（合并原因，见 B-fix-E1 取证结论）：
   *  - 此前为两个变量：`@State currentIndex`（Tabs.index 的 $$ 绑定源）与
   *    `@Provide('rootTabIndex') broadcastTabIndex`（子页面 @Consume 的读写端）。
   *    二者之间**不存在任何同步机制**，故子页面写入只落到 broadcastTabIndex，
   *    永远无法驱动 Tabs 切换（断点位于原 L41）。
   *  - 现合并为同一变量：写入源 = Tabs 绑定源 = 广播源，链路闭合。
   *
   * 官方依据：
   *  - 《@Provide》API 参考：「@Provide装饰的变量作为数据源…当@Provide或@Consume装饰的变量
   *    发生变化时，变化会自动同步到对方」→ @Provide 自带状态能力，无需叠加 @State。
   *  - 《@Watch》：「可监听所有装饰器装饰的状态变量」→ 子页面 @Consume + @Watch 仍有效。
   *  - 《Tabs》index：「从API version 10开始，该参数支持$$双向绑定变量」。
   *
   * ⚠️ 变更历史与风险登记：
   *  - 原实现曾并存两个变量，注释自称「与 currentIndex 同步」，但该同步从未被实现。
   *  - 变量名刻意不取 tabIndex —— 该名与 ArkUI CustomComponent 基类内置属性冲突，
   *    会报 "Property 'tabIndex' is not assignable to the same property in base type"。
   *  - 广播别名固定为 'rootTabIndex'，Learn / Profile / Home 三页以同名键 @Consume。
   */
  @Provide('rootTabIndex') currentIndex: number = 0;

  build() {
    // B-fix（方案 A）：index 使用 $$ 双向绑定，绑定源即上面的 @Provide 变量。
    // $$ 使 index 由单向升级为双向，故子页面（HomePage）写入 @Consume 的 rootTabIndex
    // 即可驱动 Tabs 切换，无需 TabsController，也无需下发任何函数。
    Tabs({ barPosition: BarPosition.End, index: $$this.currentIndex }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.tabBarBuilder(0, AppStrings.TAB_HOME))

      TabContent() {
        LearnPage()
      }
      .tabBar(this.tabBarBuilder(1, AppStrings.TAB_LEARN))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.tabBarBuilder(2, AppStrings.TAB_PROFILE))
    }
    .barMode(BarMode.Fixed)
    .barHeight(AppDimens.TAB_BAR_HEIGHT)
    .barBackgroundColor(AppColors.SURFACE)
    .scrollable(true)
    .animationDuration(0)
    .width('100%')
    .height('100%')
    // 同步真实切换的 index：合并为单变量后，此处仅需写 currentIndex。
    // 说明：由 $$ 双向绑定先行写入的值与此处同值，不构成变化，
    //      故不会触发子页面 @Consume 的 @Watch（无冗余刷新）。
    .onChange((index: number) => {
      this.currentIndex = index;
    })
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
