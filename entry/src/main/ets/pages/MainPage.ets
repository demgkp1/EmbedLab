import { AppColors } from '../constants/AppColors';
import { AppStrings } from '../constants/AppStrings';
import { RouteConstants } from '../constants/RouteConstants';
import { RootTabContainer } from '../components/RootTabContainer';
import { NavigationProbePage } from './dev/NavigationProbePage';
import { Logger } from '../utils/logger/Logger';

const MODULE_TAG: string = 'MainPage';

/**
 * 应用根页面骨架。
 *
 * 职责：
 *  - 创建全应用唯一的根 NavPathStack，并向下注入给子页面。
 *  - 挂载唯一根 Navigation 容器与 RootTabContainer。
 *  - 通过本地 @Builder pageMap(name, param) 集中注册二级页面（不使用 router_map.json）。
 *
 * ⚠️ 关键渲染约束（修复 "State variable 'navPathStack' has changed during render!" 的根因）：
 *  - NavPathStack 是「被 Navigation 组件在渲染期内部写入」的可变控制器对象。
 *  - 因此该成员严禁使用 @Provide / @State / @Link 等状态装饰器：一旦被装饰，
 *    ArkUI 会把 Navigation 的内部入栈动作识别为「渲染期间修改状态变量」并抛出渲染告警。
 *  - 本页必须保持为普通成员变量，且严禁在 build() / @Builder / 组件实例化阶段对其做
 *    任何赋值、push 或 pop；所有栈操作只能来自事件回调（onClick 等）或生命周期回调。
 *
 * 其他约束：
 *  - 本页不执行任何业务 I/O；底层链路预热由 EntryAbility 负责，
 *    启动状态恢复由 Milestone 3 的 MainViewModel 经 Repository 完成。
 *  - 严禁在此重复创建 NavPathStack，严禁在子组件或 TabContent 中嵌套 Navigation。
 */
@Entry
@Component
struct MainPage {
  /**
   * 全应用唯一根路由栈：普通成员变量，刻意不加状态装饰器（见上方渲染约束）。
   * Navigation 组件通过构造参数持有同一实例，子页面经 NavDestinationContext.pathStack 获取。
   */
  private navPathStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.navPathStack) {
      RootTabContainer()
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /**
   * 二级页面集中注册表。
   * 说明：分支直接返回 NavDestination（或其 NavDestination 根组件），
   *      严禁再外套 Stack 等多余容器，避免破坏 NavDestination 的顶级节点语义。
   * @param name 路由名称，取值来自 RouteConstants
   * @param param 路由参数，无参数路由传入 null
   */
  @Builder
  pageMap(name: string, param: Object) {
    if (name === RouteConstants.NAV_PROBE) {
      NavigationProbePage({ routeName: name })
    } else {
      this.unregisteredRoute(name)
    }
  }

  /** 未注册路由兜底：避免静默白屏，同时不掩盖真实缺失。 */
  @Builder
  unregisteredRoute(name: string) {
    NavDestination() {
      Column() {
        Text(AppStrings.PLACEHOLDER_TITLE)
          .fontSize(16)
          .fontColor(AppColors.TEXT_PRIMARY)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .title(AppStrings.PLACEHOLDER_TITLE)
    .onReady(() => {
      Logger.error(MODULE_TAG, `unregistered route requested: ${name}`);
    })
  }
}
