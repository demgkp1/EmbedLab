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
 *  - 创建全应用唯一的根 NavPathStack，并通过 @Provide 向下注入。
 *  - 挂载唯一根 Navigation 容器与 RootTabContainer。
 *  - 通过本地 @Builder pageMap(name, param) 集中注册二级页面（不使用 router_map.json）。
 * 约束：
 *  - 本页不执行任何业务 I/O；启动状态恢复由 Milestone 3 的 MainViewModel 经 Repository 完成。
 *  - 严禁在此重复创建 NavPathStack，严禁在子组件或 TabContent 中嵌套 Navigation。
 */
@Entry
@Component
struct MainPage {
  /** 全应用唯一根路由栈，供子页面通过 @Consume('NavPathStack') 获取。 */
  @Provide('NavPathStack') navPathStack: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.navPathStack) {
      RootTabContainer()
    }
    .mode(NavigationMode.Stack)
    .hideNavBar(true)
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /**
   * 二级页面集中注册表。
   * 说明：@Builder 只能包含一个根节点，因此以 Stack 作为分派容器。
   * @param name 路由名称，取值来自 RouteConstants
   * @param param 路由参数，无参数路由传入 null
   */
  @Builder
  pageMap(name: string, param: Object) {
    Stack() {
      if (name === RouteConstants.NAV_PROBE) {
        NavigationProbePage({ routeName: name })
      } else {
        this.unregisteredRoute(name)
      }
    }
    .width('100%')
    .height('100%')
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
