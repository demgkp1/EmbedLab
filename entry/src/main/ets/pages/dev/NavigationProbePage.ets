import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'NavigationProbePage';

/**
 * 路由基础设施验证页（Milestone 0 临时脚手架）。
 *
 * 职责：作为最小 NavDestination，验证唯一根 NavPathStack 的 push / pop 基础设施可用。
 * 约束：
 *  - 本页不创建 NavPathStack，统一 @Consume MainPage 通过 @Provide 注入的根栈。
 *  - 本页不访问任何数据源，不承载业务逻辑。
 *  - 页面参数一律在 onReady 生命周期中经 NavDestinationContext 提取，禁止旧式 router.getParams()。
 * 移除时机：Milestone 2 落地 KnowledgeDetailPage（携带强类型 KnowledgeDetailParams）后，
 *          本页与 RouteConstants.NAV_PROBE 一并删除。
 */
@Component
export struct NavigationProbePage {
  /** 全应用唯一根路由栈，由 MainPage 注入。 */
  @Consume('NavPathStack') navPathStack: NavPathStack;

  /** 由 pageMap 透传的路由名称，仅用于发起二次 push。 */
  @Prop routeName: string = '';

  /** onReady 提取到的路由名称，用于证明参数提取链路已生效。 */
  @State private receivedRoute: string = '';

  build() {
    NavDestination() {
      Column({ space: AppDimens.SPACING_MD }) {
        Text(this.receivedRoute)
          .fontSize(AppDimens.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(AppStrings.NAV_PROBE_DESC)
          .fontSize(AppDimens.FONT_SIZE_BODY)
          .fontColor(AppColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)

        Button(AppStrings.NAV_PROBE_PUSH_AGAIN)
          .width('80%')
          .onClick(() => {
            this.pushSelfAgain();
          })
        Button(AppStrings.NAV_PROBE_POP)
          .width('80%')
          .backgroundColor(AppColors.PRIMARY_LIGHT)
          .fontColor(AppColors.PRIMARY)
          .onClick(() => {
            this.navPathStack.pop();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(AppDimens.SPACING_XL)
      .backgroundColor(AppColors.BACKGROUND)
    }
    .title(AppStrings.NAV_PROBE_TITLE)
    .backgroundColor(AppColors.SURFACE)
    .onReady((context: NavDestinationContext) => {
      this.receivedRoute = context.pathInfo.name;
      Logger.info(MODULE_TAG, `onReady name=${this.receivedRoute}`);
    })
  }

  /** 再次压入本页，验证重复 push 行为。 */
  private pushSelfAgain(): void {
    this.navPathStack.pushPathByName(this.receivedRoute, null);
  }
}
