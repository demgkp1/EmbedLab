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
 * 难度候选值（写入序）。
 *
 * 来源：knowledge/index.json 的 level 字段 —— 实测 34 章仅 3 种取值
 *      Basic(9) / Medium(15) / Hard(10)，无第四种，故此处静态声明而非从数据推导，
 *      以保证候选顺序在视觉上由浅入深稳定呈现（推导序会随 JSON 条目顺序漂移）。
 * 约束：按产品决策 D2，标签直接使用原始值，不做中文映射。
 */
const LEVEL_OPTIONS: string[] = ['Basic', 'Medium', 'Hard'];

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
  /** 当前选中的难度，默认「全部」（C-1；与分类维度相互独立，二者为「与」关系） */
  selectedLevel: string = AppStrings.LEARN_LEVEL_ALL;
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
    // 重新加载视为一次全新会话，两个筛选维度一并复位为「全部」，
    // 避免「重试后仍停留在旧筛选条件」造成的「加载了但看不到内容」困惑。
    this.selectedCategory = AppStrings.LEARN_CATEGORY_ALL;
    this.selectedLevel = AppStrings.LEARN_LEVEL_ALL;
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
   * 生成难度筛选清单：首项固定为「全部」，后接固定顺序的 Basic / Medium / Hard。
   *
   * 说明：与 categoryList() 的「从数据去重推导」不同，难度取值以 LEVEL_OPTIONS
   *      静态声明为准 —— 候选顺序需稳定（由浅入深），不可随 JSON 条目顺序漂移。
   *      若某难度档在当前数据中不存在，该档位仍会展示但筛选结果为空，
   *      此时由页面呈现 LEARN_EMPTY_FILTERED 空态。
   * @returns 难度文案数组
   */
  levelList(): string[] {
    const levels: string[] = [AppStrings.LEARN_LEVEL_ALL];
    for (let index: number = 0; index < LEVEL_OPTIONS.length; index++) {
      levels.push(LEVEL_OPTIONS[index]);
    }
    return levels;
  }

  /**
   * 按当前选中分类 + 选中难度计算展示列表（计算属性，不产生额外状态）。
   *
   * 组合语义：两个维度为**逻辑与**。任一维度为「全部」即视为该维度不过滤；
   *          两者均为「全部」时不遍历，直接返回 allList（快路径）。
   * @returns 过滤后的元数据数组
   */
  visibleList(): KnowledgeMetadata[] {
    const categoryAll: boolean = this.selectedCategory === AppStrings.LEARN_CATEGORY_ALL;
    const levelAll: boolean = this.selectedLevel === AppStrings.LEARN_LEVEL_ALL;
    if (categoryAll && levelAll) {
      return this.allList;
    }
    const filtered: KnowledgeMetadata[] = [];
    for (let index: number = 0; index < this.allList.length; index++) {
      const item: KnowledgeMetadata = this.allList[index];
      const categoryHit: boolean = categoryAll || item.category === this.selectedCategory;
      const levelHit: boolean = levelAll || item.level === this.selectedLevel;
      if (categoryHit && levelHit) {
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
   * 切换难度筛选（用户意图入口，C-1）。
   * @param level 目标难度值（LEARN_LEVEL_ALL 或 Basic / Medium / Hard）
   */
  selectLevel(level: string): void {
    this.selectedLevel = level;
    Logger.debug(MODULE_TAG, `level switched to ${level}`);
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
