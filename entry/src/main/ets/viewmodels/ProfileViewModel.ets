import { Failure, Result } from '../models/common/Result';
import { UIStatus } from '../models/common/UIStatus';
import { KnowledgeMetadata } from '../models/knowledge/KnowledgeMetadata';
import { KnowledgeRepository } from '../repositories/KnowledgeRepository';
import { RepositoryProvider } from '../utils/providers/RepositoryProvider';
import { UserStore } from '../stores/UserStore';
import { Logger } from '../utils/logger/Logger';
import { AppStrings } from '../constants/AppStrings';

const MODULE_TAG: string = 'ProfileViewModel';

/**
 * 「我的」页 ViewModel。
 *
 * 职责：
 *  - 从 UserStore 读取收藏 / 历史的 ID 集合（内存态，不触达 Preferences）；
 *  - 经 KnowledgeRepository **一次性批量**取得元数据，再在内存中按 ID 顺序映射为展示实体；
 *  - 对外只暴露装配好的展示数组与状态，供页面直接渲染。
 * 分层约束：
 *  - 本类属于 ViewModel 层，严禁 import 任何 ArkUI 组件/UI 相关库。
 *  - 严禁在 UI 层遍历 ID 调 Repository —— 聚合职责收敛在本类（架构原则二「Profile 数据防腐」）。
 *  - 严禁直接访问 rawfile / Preferences；数据一律经 Repository。
 *  - 严禁持有任何 UI Component 引用。
 * 数据流：
 *  UserStore(favorites/history) → 本类取 ID 序列
 *    → KnowledgeRepository.getKnowledgeMetadataList()（命中 metadataCache，无重复 I/O）
 *    → 内存按 ID 顺序映射 → favoriteItems / historyItems
 */
@Observed
export class ProfileViewModel {
  /** 当前 UI 状态（LOADING / SUCCESS / EMPTY / ERROR） */
  uiStatus: UIStatus = UIStatus.LOADING;
  /** 收藏对应的展示实体（顺序与 UserStore.favorites 一致） */
  favoriteItems: KnowledgeMetadata[] = [];
  /** 历史对应的展示实体（顺序与 UserStore.history 一致，最新在前） */
  historyItems: KnowledgeMetadata[] = [];
  /** 失败时的错误码文本（用于错误态展示与排障） */
  lastErrorMessage: string = '';

  /**
   * 装配展示数据。
   * 说明：元数据为一次性批量获取（Repository 内部命中 metadataCache），
   *      随后在内存中按 ID 映射，全程不产生 N 次 I/O。
   * @returns 装配完成（无论成功或失败）后 resolve 的 Promise，供页面以 then 触发重绘
   */
  async loadDisplayItems(): Promise<void> {
    this.uiStatus = UIStatus.LOADING;
    const repository: KnowledgeRepository | null = RepositoryProvider.getKnowledgeRepository();
    if (repository === null) {
      this.lastErrorMessage = AppStrings.ERROR_REPOSITORY_NOT_READY;
      this.uiStatus = UIStatus.ERROR;
      Logger.error(MODULE_TAG, `load skipped: ${this.lastErrorMessage}`);
      return;
    }
    const result: Result<KnowledgeMetadata[]> = await repository.getKnowledgeMetadataList();
    if (!result.success) {
      // ArkTS 仅在否定式判别下收窄 Result<T>，失败信息在此分支取用
      const failure: Failure = result as Failure;
      this.lastErrorMessage = `${failure.code}`;
      this.uiStatus = UIStatus.ERROR;
      Logger.error(MODULE_TAG, `metadata load failed code=${failure.code}`);
      return;
    }

    const store: UserStore = UserStore.getInstance();
    this.metadataPool = result.data;
    this.favoriteItems = ProfileViewModel.mapByIds(store.favorites, result.data);
    this.historyItems = ProfileViewModel.mapByIds(store.history, result.data);
    this.uiStatus = UIStatus.SUCCESS;
    Logger.info(MODULE_TAG,
      `display items assembled: fav=${this.favoriteItems.length} hist=${this.historyItems.length}`);
  }

  /**
   * 仅从 UserStore 重新装配展示数组（不触达 Repository）。
   * 用途：从详情页返回后刷新星标 / 收藏列表，避免重复元数据请求。
   * 元数据来源为上一次 loadDisplayItems 的结果缓存（metadataPool），若尚未加载则直接返回。
   */
  refreshFromStore(): void {
    const pool: KnowledgeMetadata[] | null = this.metadataPool;
    if (pool === null) {
      return;
    }
    const store: UserStore = UserStore.getInstance();
    this.favoriteItems = ProfileViewModel.mapByIds(store.favorites, pool);
    this.historyItems = ProfileViewModel.mapByIds(store.history, pool);
  }

  /** 元数据内存池（首次批量加载后缓存，供 refreshFromStore 复用） */
  private metadataPool: KnowledgeMetadata[] | null = null;

  /**
   * 按 ID 顺序把元数据池映射为展示实体。
   * 纯内存操作，无 I/O；池中不存在的 ID 被跳过（例如知识已被移除）。
   * @param ids 目标 ID 序列（顺序即展示顺序）
   * @param pool 全量元数据池
   */
  private static mapByIds(ids: string[], pool: KnowledgeMetadata[]): KnowledgeMetadata[] {
    const result: KnowledgeMetadata[] = [];
    for (let index: number = 0; index < ids.length; index++) {
      const id: string = ids[index];
      for (let scan: number = 0; scan < pool.length; scan++) {
        const meta: KnowledgeMetadata = pool[scan];
        if (meta.id === id) {
          result.push(meta);
          break;
        }
      }
    }
    return result;
  }
}
