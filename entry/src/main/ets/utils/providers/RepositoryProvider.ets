import { resourceManager } from '@kit.LocalizationKit';
import { KnowledgeRepository } from '../../repositories/KnowledgeRepository';
import { RawFileAssetDataSource } from '../../datasources/RawFileAssetDataSource';
import { DataSourceProvider } from './DataSourceProvider';

/**
 * 仓库静态工厂（依赖注入 Provider）。
 *
 * 职责：为 UI 层（ViewModel）提供 Repository 实例的统一获取入口，并在此完成
 *      Repository ← DataSource 的依赖注入组装，使调用方完全不感知底层实现。
 * 分层约束：
 *  - 本类只负责依赖组装，严禁承载任何业务逻辑、缓存策略或数据校验。
 *  - ViewModel 严禁直接 new KnowledgeRepository()，必须经由此 Provider 获取。
 *  - Repository 严禁直接 new RawFileAssetDataSource()，依赖由本 Provider 注入。
 */
export class RepositoryProvider {
  /** 单例仓库实例（进程生命周期内复用） */
  private static knowledgeRepository: KnowledgeRepository | null = null;

  /**
   * 获取知识仓库单例。
   * @param resMgr 系统资源管理器实例；首次调用时必须提供，用于完成数据源注入
   * @returns 仓库实例；数据源尚未完成注入时返回 null，由调用方决定降级策略
   */
  static getKnowledgeRepository(resMgr?: resourceManager.ResourceManager): KnowledgeRepository | null {
    if (RepositoryProvider.knowledgeRepository !== null) {
      return RepositoryProvider.knowledgeRepository;
    }
    const dataSource: RawFileAssetDataSource | null =
      DataSourceProvider.getRawFileAssetDataSource(resMgr);
    if (dataSource === null) {
      return null;
    }
    const created: KnowledgeRepository = new KnowledgeRepository(dataSource);
    RepositoryProvider.knowledgeRepository = created;
    return created;
  }

  /** 释放单例引用（仅用于测试隔离或应用级资源回收）。 */
  static reset(): void {
    RepositoryProvider.knowledgeRepository = null;
  }
}
