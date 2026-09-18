import { AppColors } from '../constants/AppColors';
import { AppDimens } from '../constants/AppDimens';
import { AppStrings } from '../constants/AppStrings';
import { ROUTE_KNOWLEDGE_DETAIL, ROUTE_PROFILE_FAVORITES, ROUTE_PROFILE_HISTORY,
  ROUTE_PROFILE_SETTINGS, ROUTE_PROFILE_ABOUT } from '../constants/RouteConstants';
import { RootTabContainer } from '../components/RootTabContainer';
import { KnowledgeDetailPage } from './learn/KnowledgeDetailPage';
import { FavoritesPage } from './profile/FavoritesPage';
import { HistoryPage } from './profile/HistoryPage';
import { SettingsPage } from './profile/SettingsPage';
import { AboutPage } from './profile/AboutPage';
import { DataSourceProvider } from '../utils/providers/DataSourceProvider';
import { RepositoryProvider } from '../utils/providers/RepositoryProvider';
import { UserRepository } from '../repositories/UserRepository';
import { UserStore } from '../stores/UserStore';
import { Failure, Result } from '../models/common/Result';
import { UserProgressState } from '../models/user/UserProgressState';
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

  /**
   * 启动水化：从 Preferences 恢复用户状态并注水到 UserStore。
   *
   * 链路：MainPage → DataSourceProvider.initialize → RepositoryProvider.getUserRepository
   *       → UserRepository.loadState → UserStore.initialize
   * 硬约束：
   *  - 必须 .then().catch()，严禁 await 阻塞冷启动。
   *  - 失败一律降级为「空 Store」，不 throw、不白屏。
   *  - hostContext 为 undefined 时必须先行返回。
   *  - 严禁在此 new Repository / new Store（一律走 Provider 与单例）。
   */
  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      Logger.error(MODULE_TAG, 'host context unavailable, skip user state hydration');
      return;
    }

    DataSourceProvider.initialize(hostContext);
    const userRepo: UserRepository = RepositoryProvider.getUserRepository();

    userRepo.loadState()
      .then((state: Result<UserProgressState>) => {
        if (!state.success) {
          // ArkTS 仅在否定式判别下收窄 Result<T>，失败信息在此分支取用
          const failure: Failure = state as Failure;
          Logger.warn(MODULE_TAG, `user state load failed, keep empty store: code=${failure.code}`);
          return;
        }
        UserStore.getInstance().initialize(state.data);
        Logger.info(MODULE_TAG,
          `user state hydrated: fav=${state.data.favorites.length} hist=${state.data.history.length}`);
      })
      .catch((err: Object) => {
        const message: string = err instanceof Error ? err.message : `${err}`;
        Logger.error(MODULE_TAG, `hydration unexpected error: ${message}`);
      });
  }

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
    if (name === ROUTE_KNOWLEDGE_DETAIL) {
      KnowledgeDetailPage()
    } else if (name === ROUTE_PROFILE_FAVORITES) {
      FavoritesPage()
    } else if (name === ROUTE_PROFILE_HISTORY) {
      HistoryPage()
    } else if (name === ROUTE_PROFILE_SETTINGS) {
      SettingsPage()
    } else if (name === ROUTE_PROFILE_ABOUT) {
      AboutPage()
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
          .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
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
