import { resourceManager } from '@kit.LocalizationKit';
import { KnowledgeRepository } from '../../repositories/KnowledgeRepository';
import { UserRepository } from '../../repositories/UserRepository';
import { RawFileAssetDataSource } from '../../datasources/RawFileAssetDataSource';
import { PreferenceDataSource } from '../../datasources/PreferenceDataSource';
import { DataSourceProvider } from './DataSourceProvider';

/**
 * 仓库静态工厂（依赖注入 Provider）。
 *
 * 职责：为 UI 层（ViewModel）提供 Repository 实例的统一获取入口，并在此完成
 *      Repository ← DataSource 的依赖注入组装，使调用方完全不感知底层实现。
 * 分层约束：
 *  - 本类只负责依赖组装，严禁承载任何业务逻辑、缓存策略或数据校验。
 *  - ViewModel 严禁直接 new KnowledgeRepository() / new UserRepository()，必须经由此 Provider 获取。
 *  - Repository 严禁直接 new 任何 DataSource，依赖由本 Provider 注入。
 * 时序约束（架构师裁决 [A]）：
 *  - DataSourceProvider.getUserPreferencesDataSource() 未初始化时会 throw，
 *    该语义保持不变；本 Provider **禁止**用 try-catch 包裹该调用。
 *    任何 throw 都意味着调用时序错误（未先 initialize），应当直接暴露以便定位。
 */
export class RepositoryProvider {
  /** 单例仓库实例（进程生命周期内复用） */
  private static knowledgeRepository: KnowledgeRepository | null = null;
  /** 用户状态仓库单例 */
  private static userRepository: UserRepository | null = null;

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

  /**
   * 获取用户状态仓库单例。
   * 前置条件：必须先调用 DataSourceProvider.initialize(context) 完成 Preferences 数据源注入；
   *          未注入时 getter 会 throw（编程时序错误，故意不捕获）。
   * @returns 用户状态仓库实例
   */
  static getUserRepository(): UserRepository {
    const existing: UserRepository | null = RepositoryProvider.userRepository;
    if (existing !== null) {
      return existing;
    }
    const dataSource: PreferenceDataSource = DataSourceProvider.getUserPreferencesDataSource();
    const created: UserRepository = new UserRepository(dataSource);
    RepositoryProvider.userRepository = created;
    return created;
  }

  /** 释放单例引用（仅用于测试隔离或应用级资源回收）。 */
  static reset(): void {
    RepositoryProvider.knowledgeRepository = null;
    RepositoryProvider.userRepository = null;
  }
}
