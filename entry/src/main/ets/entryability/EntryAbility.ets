import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Logger } from '../utils/logger/Logger';
import { LogLevel } from '../utils/logger/LogLevel';
import { DataSourceProvider } from '../utils/providers/DataSourceProvider';
import { RepositoryProvider } from '../utils/providers/RepositoryProvider';
import { KnowledgeRepository } from '../repositories/KnowledgeRepository';
import { Result, Failure } from '../models/common/Result';
import { KnowledgeMetadata } from '../models/knowledge/KnowledgeMetadata';
import { AppStorageKeys } from '../constants/AppStorageKeys';

const MODULE_TAG: string = 'EntryAbility';
/** 链路预热日志域（按任务约定固定为 0x0000） */
const PRELOAD_DOMAIN: number = 0x0000;
/** 链路预热日志标签（按任务约定固定为 EmbedLab，便于真机按 tag 过滤） */
const PRELOAD_TAG: string = 'EmbedLab';

/**
 * 应用入口 Ability。
 *
 * 职责：创建主窗口并加载 pages/MainPage；在 onCreate 阶段注入全局 ApplicationContext，
 *      并以非阻塞方式触发一次底层链路预热（RawFile → DataSource → Repository → Cache）。
 * 约束：
 *  - 严禁使用 await 阻塞应用冷启动；预热必须通过 .then().catch() 异步发起。
 *  - 本层不做任何业务数据加工，仅做依赖注入与结果观测（HiLog）。
 *  - 用户状态恢复由 Milestone 3 的 MainViewModel 经 UserRepository 完成。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 日志门面初始化：Debug 构建保留 DEBUG 输出，Release 构建改用 LogLevel.INFO 即可收敛日志。
    Logger.configure(this.context.abilityInfo.bundleName, LogLevel.DEBUG);
    // 注入全局 ApplicationContext，供后续里程碑的 Provider 取用。
    // 键名 AppStorageKeys.APP_CONTEXT：进程级 Context 交付契约预留，当前无读取方。
    // MainPage 经 getUIContext().getHostContext() 取 Context，不使用此键。
    AppStorage.setOrCreate(AppStorageKeys.APP_CONTEXT, this.context.getApplicationContext());
    Logger.info(MODULE_TAG, 'onCreate: application context stored');
    // 注入真实设备 Context.resourceManager，打通 RawFile 底层读取能力。
    this.warmUpKnowledgeChain();
  }

  /**
   * 底层链路预热：RawFile → RawFileAssetDataSource → KnowledgeRepository → 内存缓存。
   * 全程异步非阻塞，不阻塞冷启动；失败时以语义化 ErrorCode 输出错误日志。
   */
  private warmUpKnowledgeChain(): void {
    DataSourceProvider.getRawFileAssetDataSource(this.context.resourceManager);
    const repository: KnowledgeRepository | null = RepositoryProvider.getKnowledgeRepository();
    if (repository === null) {
      hilog.error(PRELOAD_DOMAIN, PRELOAD_TAG,
        '【EmbedLab】底层链路预热失败！ErrorCode: %{public}s', 'UNKNOWN(数据源未完成上下文注入)');
      return;
    }
    repository.getKnowledgeMetadataList()
      .then((result: Result<KnowledgeMetadata[]>) => {
        if (!result.success) {
          // ArkTS 仅在否定式判别下收窄 Result<T>，失败信息在此分支取用（as 为已校验对齐）。
          const failure: Failure = result as Failure;
          hilog.error(PRELOAD_DOMAIN, PRELOAD_TAG,
            '【EmbedLab】底层链路预热失败！ErrorCode: %{public}s', failure.code);
          return;
        }
        hilog.info(PRELOAD_DOMAIN, PRELOAD_TAG,
          '【EmbedLab】底层链路预热成功！已加载知识索引数量: %{public}d', result.data.length);
      })
      .catch((err: Object) => {
        const message: string = err instanceof Error ? err.message : `${err}`;
        hilog.error(PRELOAD_DOMAIN, PRELOAD_TAG,
          '【EmbedLab】底层链路预热异常！ErrorCode: %{public}s', message);
      });
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
