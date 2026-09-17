import { ErrorCode } from '../models/common/ErrorCode';
import { Failure, Result } from '../models/common/Result';
import { UIStatus } from '../models/common/UIStatus';
import { KnowledgeMetadata } from '../models/knowledge/KnowledgeMetadata';
import { KnowledgeRepository } from '../repositories/KnowledgeRepository';
import { RepositoryProvider } from '../utils/providers/RepositoryProvider';
import { Logger } from '../utils/logger/Logger';
import { AppStrings } from '../constants/AppStrings';

const MODULE_TAG: string = 'LearnViewModel';

/**
 * 学习模块 ViewModel。
 *
 * 职责：维护 LearnPage 的 UI 状态（四态流转）、承载用户意图（切换分类、加载数据），
 *      并通过 RepositoryProvider 调度 KnowledgeRepository 完成数据获取与内存缓存命中。
 * 分层约束：
 *  - 本类属于 ViewModel 层，严禁 import 任何 ArkUI 组件/UI 相关库。
 *  - 严禁直接 new Repository()，必须经 RepositoryProvider 静态工厂获取。
 *  - 严禁直接访问 rawfile / resourceManager / Preferences。
 *  - 严禁持有任何 UI Component 或 PageController 引用。
 * 响应式说明：
 *  - 使用 @Observed 修饰，配合页面持有的实例，使 uiStatus / allList / selectedCategory
 *    的变化能够驱动 UI 重新渲染。
 */
@Observed
export class LearnViewModel {
  /** 当前 UI 状态 */
  uiStatus: UIStatus = UIStatus.LOADING;
  /** 全量知识元数据列表（与 Repository 的 metadataCache 对应） */
  allList: KnowledgeMetadata[] = [];
  /** 当前选中的分类，默认「全部」 */
  selectedCategory: string = AppStrings.LEARN_CATEGORY_ALL;
  /** 失败时的语义化错误码，用于错误态提示与排障 */
  lastErrorCode: ErrorCode = ErrorCode.UNKNOWN;
  /** 失败原因文本（仅用于日志与错误态副标题） */
  lastErrorMessage: string = '';

  /**
   * 加载知识元数据列表并流转 UI 状态。
   * 失败时按 ErrorCode 映射为 EMPTY / ERROR 两种终止态。
   * @returns 加载完成（无论成功或失败）后 resolve 的 Promise，
   *          供页面在 await/then 中触发显式重绘（ArkUI @State 不深层监听类内部属性）。
   */
  async loadKnowledgeList(): Promise<void> {
    this.uiStatus = UIStatus.LOADING;
    const repository: KnowledgeRepository | null = RepositoryProvider.getKnowledgeRepository();
    if (repository === null) {
      this.lastErrorCode = ErrorCode.UNKNOWN;
      this.lastErrorMessage = AppStrings.ERROR_REPOSITORY_NOT_READY;
      this.uiStatus = UIStatus.ERROR;
      Logger.error(MODULE_TAG, `load failed: ${this.lastErrorMessage}`);
      return;
    }
    const result: Result<KnowledgeMetadata[]> = await repository.getKnowledgeMetadataList();
    if (!result.success) {
      // ArkTS 仅在否定式判别下收窄 Result<T>，失败信息在此分支取用。
      const failure: Failure = result as Failure;
      this.lastErrorCode = failure.code;
      this.lastErrorMessage = failure.error;
      this.uiStatus = LearnViewModel.mapFailureToStatus(failure.code);
      Logger.error(MODULE_TAG, `load failed code=${failure.code} message=${failure.error}`);
      return;
    }
    this.allList = result.data;
    this.selectedCategory = AppStrings.LEARN_CATEGORY_ALL;
    this.uiStatus = result.data.length === 0 ? UIStatus.EMPTY : UIStatus.SUCCESS;
    Logger.info(MODULE_TAG, `load success count=${result.data.length} status=${this.uiStatus}`);
  }

  /**
   * 生成分类筛选清单：首项固定为「全部」，其余为元数据中按首次出现顺序去重的分类。
   * @returns 分类文案数组
   */
  categoryList(): string[] {
    const categories: string[] = [AppStrings.LEARN_CATEGORY_ALL];
    for (let index: number = 0; index < this.allList.length; index++) {
      const category: string = this.allList[index].category;
      if (category.length > 0 && !categories.includes(category)) {
        categories.push(category);
      }
    }
    return categories;
  }

  /**
   * 按当前选中分类计算展示列表（计算属性，不产生额外状态）。
   * @returns 过滤后的元数据数组
   */
  visibleList(): KnowledgeMetadata[] {
    if (this.selectedCategory === AppStrings.LEARN_CATEGORY_ALL) {
      return this.allList;
    }
    const filtered: KnowledgeMetadata[] = [];
    for (let index: number = 0; index < this.allList.length; index++) {
      const item: KnowledgeMetadata = this.allList[index];
      if (item.category === this.selectedCategory) {
        filtered.push(item);
      }
    }
    return filtered;
  }

  /**
   * 切换分类筛选（用户意图入口）。
   * @param category 目标分类文案
   */
  selectCategory(category: string): void {
    this.selectedCategory = category;
    Logger.debug(MODULE_TAG, `category switched to ${category}`);
  }

  /**
   * 将 ErrorCode 按架构文档 7.3 节标准映射表转换为 UI 状态。
   * FILE_NOT_FOUND → EMPTY；其余（JSON_INVALID / DATA_VERSION_UNSUPPORTED /
   * STORAGE_* / UNKNOWN）→ ERROR。
   */
  private static mapFailureToStatus(code: ErrorCode): UIStatus {
    return code === ErrorCode.FILE_NOT_FOUND ? UIStatus.EMPTY : UIStatus.ERROR;
  }
}
