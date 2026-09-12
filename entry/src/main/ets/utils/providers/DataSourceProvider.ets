import { resourceManager } from '@kit.LocalizationKit';
import { RawFileAssetDataSource } from '../../datasources/RawFileAssetDataSource';
/**
 * 数据源静态工厂（依赖注入 Provider）。
 *
 * 职责：为上层（Repository）提供 DataSource 实例的统一获取入口，屏蔽实例构造细节，
 *      使未来替换数据源实现（如迁移至 SQLite）时不影响调用方。
 * 分层约束：
 *  - 本类只负责依赖组装，严禁承载任何业务逻辑、缓存策略或数据校验。
 *  - Repository 严禁直接 new RawFileAssetDataSource()，必须经由此 Provider 获取。
 *  - ResourceManager 必须在首次获取实例时注入；无法获取时返回 null 而不是抛异常，
 *    由调用方转换为 Result.Failure，避免异常穿透到 UI 层。
 */
export class DataSourceProvider {
  /** 单例数据源实例（进程生命周期内复用） */
  private static rawFileAssetDataSource: RawFileAssetDataSource | null = null;

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

  /** 释放单例引用（仅用于测试隔离或应用级资源回收）。 */
  static reset(): void {
    DataSourceProvider.rawFileAssetDataSource = null;
  }
}
