import { Failure, Result } from '../models/common/Result';
import { UIStatus } from '../models/common/UIStatus';
import { KnowledgeMetadata } from '../models/knowledge/KnowledgeMetadata';
import { KnowledgeRepository } from '../repositories/KnowledgeRepository';
import { RepositoryProvider } from '../utils/providers/RepositoryProvider';
import { UserStore } from '../stores/UserStore';
import { Logger } from '../utils/logger/Logger';
import { AppStrings } from '../constants/AppStrings';

const MODULE_TAG: string = 'HomeViewModel';

/** 首页各区块最多展示的条目数（概览语义，不做全量渲染） */
const PREVIEW_LIMIT: number = 3;

/**
 * 首页 ViewModel（Milestone B）。
 *
 * 职责：
 *  - 从 UserStore 读取收藏 / 历史的 ID 集合（内存态，不触达 Preferences）；
 *  - 经 KnowledgeRepository **一次性批量**取得元数据，再在内存中按 ID 顺序映射为展示实体；
 *  - 各区块仅取前 PREVIEW_LIMIT 条，避免首页渲染全量列表。
 * 分层约束（与 ProfileViewModel 同构，不另造轮子）：
 *  - 本类属于 ViewModel 层，严禁 import 任何 ArkUI 组件/UI 相关库。
 *  - 严禁在 UI 层遍历 ID 调 Repository —— 聚合职责收敛在本类（架构原则二「数据防腐」）。
 *  - 严禁直接访问 rawfile / Preferences；数据一律经 Repository。
 *  - 严禁持有任何 UI Component 引用。
 * V1 范围控制：
 *  - **不消费 UserStore.progress** —— 该字段在 V1 未激活，本页不引入进度展示。
 * 数据流：
 *  UserStore(favorites/history) → 本类取 ID 序列
 *    → KnowledgeRepository.getKnowledgeMetadataList()（命中 metadataCache，无重复 I/O）
 *    → 内存按 ID 顺序映射并截断前 N 条 → recentHistory / recentFavorites
 */
@Observed
export class HomeViewModel {
  /** 当前 UI 状态（LOADING / SUCCESS / ERROR / EMPTY） */
  uiStatus: UIStatus = UIStatus.LOADING;
  /** 最近阅读展示实体（按 UserStore.history 顺序，最新在前，最多 PREVIEW_LIMIT 条） */
  recentHistory: KnowledgeMetadata[] = [];
  /** 收藏总数（UserStore.favorites 的规模，不受 PREVIEW_LIMIT 影响） */
  favoriteCount: number = 0;
  /** 收藏展示实体（按 UserStore.favorites 顺序，最多 PREVIEW_LIMIT 条） */
  recentFavorites: KnowledgeMetadata[] = [];
  /** 失败时的错误码文本（用于错误态展示与排障） */
  lastErrorMessage: string = '';

  /** 元数据内存池（首次批量加载后缓存，供 refreshFromStore 复用） */
  private metadataPool: KnowledgeMetadata[] | null = null;

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

    this.metadataPool = result.data;
    this.rebuildFromStore(result.data);
    // 空数据不是错误：元数据加载成功即视为 SUCCESS，各区块自行渲染空态引导。
    this.uiStatus = UIStatus.SUCCESS;
    Logger.info(MODULE_TAG,
      `home items assembled: hist=${this.recentHistory.length} fav=${this.favoriteCount}`);
  }

  /**
   * 仅从 UserStore 重新装配展示数组（不触达 Repository）。
   * 用途：详情页收藏 / 足迹变化后回来刷新首页，避免重复元数据请求。
   * 元数据来源为上一次 loadDisplayItems 的结果缓存（metadataPool），若尚未加载则直接返回。
   */
  refreshFromStore(): void {
    const pool: KnowledgeMetadata[] | null = this.metadataPool;
    if (pool === null) {
      return;
    }
    this.rebuildFromStore(pool);
  }

  /** 依据 UserStore 最新状态重算三个展示字段（纯内存操作）。 */
  private rebuildFromStore(pool: KnowledgeMetadata[]): void {
    const store: UserStore = UserStore.getInstance();
    this.recentHistory = HomeViewModel.mapByIds(store.history, pool, PREVIEW_LIMIT);
    this.recentFavorites = HomeViewModel.mapByIds(store.favorites, pool, PREVIEW_LIMIT);
    this.favoriteCount = store.favorites.length;
  }

  /**
   * 按 ID 顺序把元数据池映射为展示实体，最多返回 limit 条。
   * 纯内存操作，无 I/O；池中不存在的 ID 被跳过（例如知识已被移除）。
   * @param ids 目标 ID 序列（顺序即展示顺序）
   * @param pool 全量元数据池
   * @param limit 最大返回条数
   */
  private static mapByIds(ids: string[], pool: KnowledgeMetadata[], limit: number): KnowledgeMetadata[] {
    const result: KnowledgeMetadata[] = [];
    for (let index: number = 0; index < ids.length; index++) {
      if (result.length >= limit) {
        break;
      }
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
