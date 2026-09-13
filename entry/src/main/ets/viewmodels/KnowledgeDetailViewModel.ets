import { ErrorCode } from '../models/common/ErrorCode';
import { Failure, Result } from '../models/common/Result';
import { UIStatus } from '../models/common/UIStatus';
import { KnowledgeItem } from '../models/knowledge/KnowledgeItem';
import { KnowledgeRepository } from '../repositories/KnowledgeRepository';
import { UserRepository } from '../repositories/UserRepository';
import { RepositoryProvider } from '../utils/providers/RepositoryProvider';
import { UserStore } from '../stores/UserStore';
import { Logger } from '../utils/logger/Logger';

const MODULE_TAG: string = 'KnowledgeDetailViewModel';

/**
 * 知识详情 ViewModel。
 *
 * 职责：按 id 调度 KnowledgeRepository 完成正文的**按需加载**（命中 detailCache 时不再触达
 *      rawfile），并把结果流转为页面四态；失败时按 ErrorCode 标准映射为 EMPTY / ERROR。
 * 分层约束：
 *  - 本类属于 ViewModel 层，严禁 import 任何 ArkUI 组件/UI 相关库。
 *  - 严禁直接 new Repository()，必须经 RepositoryProvider 静态工厂获取。
 *  - 严禁直接访问 rawfile / resourceManager / Preferences。
 *  - 严禁持有任何 UI Component 或 PageController 引用。
 */
@Observed
export class KnowledgeDetailViewModel {
  /** 当前 UI 状态 */
  uiStatus: UIStatus = UIStatus.LOADING;
  /** 加载成功的知识详情实体；未加载完成时为 null */
  detailItem: KnowledgeItem | null = null;
  /** 失败时的语义化错误码 */
  lastErrorCode: ErrorCode = ErrorCode.UNKNOWN;
  /** 失败原因文本（用于日志与错误态副标题） */
  lastErrorMessage: string = '';

  /**
   * 按 id 加载知识详情正文。
   * @param id 知识条目唯一标识
   * @returns 加载结束（成功或失败）后 resolve 的 Promise，供页面以 then 触发显式重绘
   */
  async loadDetail(id: string): Promise<void> {
    this.uiStatus = UIStatus.LOADING;
    const repository: KnowledgeRepository | null = RepositoryProvider.getKnowledgeRepository();
    if (repository === null) {
      this.lastErrorCode = ErrorCode.UNKNOWN;
      this.lastErrorMessage = '知识仓库尚未完成依赖注入';
      this.uiStatus = UIStatus.ERROR;
      Logger.error(MODULE_TAG, `load skipped: ${this.lastErrorMessage}`);
      return;
    }
    const result: Result<KnowledgeItem> = await repository.getKnowledgeItem(id);
    if (!result.success) {
      // ArkTS 仅在否定式判别下收窄 Result<T>，失败信息在此分支取用。
      const failure: Failure = result as Failure;
      this.lastErrorCode = failure.code;
      this.lastErrorMessage = failure.error;
      this.uiStatus = KnowledgeDetailViewModel.mapFailureToStatus(failure.code);
      Logger.error(MODULE_TAG, `load failed id=${id} code=${failure.code} message=${failure.error}`);
      return;
    }
    this.detailItem = result.data;
    this.uiStatus = UIStatus.SUCCESS;
    Logger.info(MODULE_TAG, `load success id=${id} title=${result.data.title}`);
  }

  /**
   * 将 ErrorCode 按架构文档 7.3 节标准映射表转换为 UI 状态。
   * FILE_NOT_FOUND → EMPTY（内容不存在或已被移除）；其余 → ERROR。
   */
  private static mapFailureToStatus(code: ErrorCode): UIStatus {
    return code === ErrorCode.FILE_NOT_FOUND ? UIStatus.EMPTY : UIStatus.ERROR;
  }

  /**
   * 切换当前知识的收藏状态。
   *
   * 状态同步铁律：必须先由 UserRepository 完成 Preferences 持久化，
   * **写入成功后才**更新 UserStore；失败仅告警，绝不更新 Store
   * （杜绝「Store 已更新但磁盘写入失败」的伪成功状态）。
   */
  async toggleFavorite(): Promise<void> {
    const id: string = this.currentIdForUserState();
    if (id.length === 0) {
      Logger.warn(MODULE_TAG, 'toggleFavorite skipped: no loaded knowledge id');
      return;
    }
    const userRepo: UserRepository = RepositoryProvider.getUserRepository();
    const result: Result<string[]> = await userRepo.toggleFavorite(id);
    if (!result.success) {
      // ArkTS 仅在否定式判别下收窄 Result<T>
      const failure: Failure = result as Failure;
      Logger.warn(MODULE_TAG, `toggleFavorite failed id=${id} code=${failure.code}`);
      return;
    }
    UserStore.getInstance().updateFavorites(result.data);
    Logger.info(MODULE_TAG, `favorite toggled id=${id} favCount=${result.data.length}`);
  }

  /**
   * 记录一次阅读足迹（详情加载成功后调用一次）。
   *
   * 状态同步铁律同 toggleFavorite：持久化成功后才更新 UserStore。
   */
  async recordHistory(): Promise<void> {
    const id: string = this.currentIdForUserState();
    if (id.length === 0) {
      Logger.warn(MODULE_TAG, 'recordHistory skipped: no loaded knowledge id');
      return;
    }
    const userRepo: UserRepository = RepositoryProvider.getUserRepository();
    const result: Result<string[]> = await userRepo.recordHistory(id);
    if (!result.success) {
      const failure: Failure = result as Failure;
      Logger.warn(MODULE_TAG, `recordHistory failed id=${id} code=${failure.code}`);
      return;
    }
    UserStore.getInstance().updateHistory(result.data);
    Logger.info(MODULE_TAG, `history recorded id=${id} histCount=${result.data.length}`);
  }

  /**
   * 查询当前知识是否已收藏（供后续收藏按钮 UI 使用）。
   * @returns 已收藏为 true；尚未加载出实体时为 false
   */
  isFavorite(): boolean {
    const id: string = this.currentIdForUserState();
    if (id.length === 0) {
      return false;
    }
    return UserStore.getInstance().isFavorite(id);
  }

  /** 取当前已加载知识实体的 id；未加载成功时返回空串。 */
  private currentIdForUserState(): string {
    const item: KnowledgeItem | null = this.detailItem;
    return item === null ? '' : item.id;
  }
}
