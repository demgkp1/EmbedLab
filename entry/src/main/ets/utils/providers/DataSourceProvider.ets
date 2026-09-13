import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { RawFileAssetDataSource } from '../../datasources/RawFileAssetDataSource';
import { PreferenceDataSource } from '../../datasources/PreferenceDataSource';
import { Logger } from '../logger/Logger';

/** 本模块日志标签 */
const MODULE_TAG: string = 'DataSourceProvider';

/**
 * 数据源静态工厂（依赖注入 Provider）。
 *
 * 职责：为上层（Repository）提供 DataSource 实例的统一获取入口，屏蔽实例构造细节，
 *      使未来替换数据源实现（如迁移至 SQLite）时不影响调用方。
 * 分层约束：
 *  - 本类只负责依赖组装，严禁承载任何业务逻辑、缓存策略或数据校验。
 *  - Repository 严禁直接 new RawFileAssetDataSource() / new PreferenceDataSource()，必须经由此 Provider 获取。
 *  - 严禁在本文件内 new 任何 Repository。
 *  - ResourceManager 必须在首次获取实例时注入；无法获取时返回 null 而不是抛异常，
 *    由调用方转换为 Result.Failure，避免异常穿透到 UI 层。
 */
export class DataSourceProvider {
  /** 单例数据源实例（进程生命周期内复用） */
  private static rawFileAssetDataSource: RawFileAssetDataSource | null = null;
  /** 用户状态 Preferences 数据源单例 */
  private static userPreferencesDataSource: PreferenceDataSource | null = null;

  /**
   * 获取原始文件资产数据源单例。
   * @param resMgr 系统资源管理器实例；首次调用时必须提供，用于完成底层 I/O 依赖注入
   * @returns 数据源实例；未完成注入时返回 null
   */
  static getRawFileAssetDataSource(resMgr?: resourceManager.ResourceManager): RawFileAssetDataSource | null {
    if (DataSourceProvider.rawFileAssetDataSource !== null) {
      return DataSourceProvider.rawFileAssetDataSource;
    }
    if (resMgr === undefined) {
      return null;
    }
    const created: RawFileAssetDataSource = new RawFileAssetDataSource(resMgr);
    DataSourceProvider.rawFileAssetDataSource = created;
    return created;
  }

  /**
   * 初始化用户状态 Preferences 数据源。
   *
   * 形参采用 common.Context：与 PreferenceDataSource 构造函数类型对齐，
   * 使 UIAbility 上下文与应用级上下文均可传入。
   *
   * 重复调用策略（架构师裁决 [C]）：overwrite + warn。
   * 即：若已有实例，先输出 warn 提示重复初始化，再以新 context 覆盖旧实例。
   */
  static initialize(context: common.Context): void {
    if (DataSourceProvider.userPreferencesDataSource !== null) {
      Logger.warn(MODULE_TAG, 'initialize() called repeatedly: overwriting existing PreferenceDataSource');
    }
    DataSourceProvider.userPreferencesDataSource = new PreferenceDataSource(context);
  }

  /**
   * 获取用户状态 Preferences 数据源。
   * @returns 数据源实例；尚未初始化时抛错以暴露调用时序错误（由 Repository 层捕获转换）
   */
  static getUserPreferencesDataSource(): PreferenceDataSource {
    const store: PreferenceDataSource | null = DataSourceProvider.userPreferencesDataSource;
    if (store === null) {
      throw new Error('PreferenceDataSource is not initialized: call DataSourceProvider.initialize(context) first');
    }
    return store;
  }

  /** 释放单例引用（仅用于测试隔离或应用级资源回收）。 */
  static reset(): void {
    DataSourceProvider.rawFileAssetDataSource = null;
    DataSourceProvider.userPreferencesDataSource = null;
  }
}
