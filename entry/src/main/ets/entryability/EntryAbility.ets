import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../utils/logger/Logger';
import { LogLevel } from '../utils/logger/LogLevel';

const MODULE_TAG: string = 'EntryAbility';

/**
 * 应用入口 Ability。
 *
 * 职责：创建主窗口并加载 pages/MainPage；在 onCreate 阶段注入全局 ApplicationContext。
 * 约束：本层不做任何业务 I/O；用户状态恢复由 MainPage → MainViewModel → UserRepository 链路完成。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 日志门面初始化：Debug 构建保留 DEBUG 输出，Release 构建改用 LogLevel.INFO 即可收敛日志。
    Logger.configure(this.context.abilityInfo.bundleName, LogLevel.DEBUG);
    // 注入全局 ApplicationContext，供 DataSourceProvider.init(context) 在后续里程碑取用。
    // 键名 'appContext' 由 MainPage 读取，二者共同构成进程级 Context 交付契约。
    AppStorage.setOrCreate('appContext', this.context.getApplicationContext());
    Logger.info(MODULE_TAG, 'onCreate: application context stored');
  }

  onDestroy(): void {
    Logger.info(MODULE_TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        Logger.error(MODULE_TAG, `failed to load MainPage, code=${err.code} message=${err.message}`);
        return;
      }
      Logger.info(MODULE_TAG, 'MainPage loaded');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Logger.error(MODULE_TAG, `failed to set colorMode: ${JSON.stringify(err)}`);
    }
  }

  onWindowStageDestroy(): void {
    Logger.info(MODULE_TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    Logger.info(MODULE_TAG, 'onForeground');
  }

  onBackground(): void {
    Logger.info(MODULE_TAG, 'onBackground');
  }
}
