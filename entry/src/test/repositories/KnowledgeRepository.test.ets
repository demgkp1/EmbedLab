import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/models/common/ErrorCode';
import { Failure, Result } from '../../main/ets/models/common/Result';
import { ContentBlock, KnowledgeItem } from '../../main/ets/models/knowledge/KnowledgeItem';
import { KnowledgeMetadata } from '../../main/ets/models/knowledge/KnowledgeMetadata';
import { RawFileAssetDataSource } from '../../main/ets/datasources/RawFileAssetDataSource';
import { KnowledgeRepository } from '../../main/ets/repositories/KnowledgeRepository';

/**
 * 【暂未挂载说明 · Cleanup-4 收尾】
 *
 * 本文件当前未被 List.test.ets 挂载，原因：
 *  - :31 super(null as object) 无法在 ArkTS 严格模式下通过编译，
 *    需放宽 RawFileAssetDataSource 构造签名为可空（生产代码契约弱化），
 *    或构造完整 ResourceManager mock（64 成员 interface），
 *    两者成本均高于负向单测本身价值；
 *  - 已登记 BACKLOG，待独立卡处理。
 *
 * 已保留的修复：失败分支的 `as Failure` 类型收窄
 *      （纯类型改进，与 mock 无关，独立有效）。
 */

/** 测试用知识条目 id */
const TEST_ID: string = 'test_id';

/**
 * 数据源测试替身。
 *
 * 策略：继承 RawFileAssetDataSource 并重写两个读取方法，返回固定 Success 数据，
 *      同时以调用计数器记录真实触底次数，用于验证 Repository 的缓存拦截能力。
 * 说明：
 *  - 父类构造函数要求注入 ResourceManager，但本替身重写了全部会触达 I/O 的方法，
 *    父类成员永不被使用，故传入占位值即可（避免依赖真实资源管理器）。
 *  - 保留私有字段而非构造函数参数，以规避 ArkTS 参数属性与 strictPropertyInitialization 差异。
 */
class MockDataSource extends RawFileAssetDataSource {
  /** readKnowledgeMetadataList 真实触底次数 */
  metadataCallCount: number = 0;
  /** readKnowledgeItem 真实触底次数 */
  detailCallCount: number = 0;
  /** 是否模拟读取失败，用于验证错误码透传 */
  failRead: boolean = false;

  constructor() {
    super(null as object);
  }

  private static metadata(): KnowledgeMetadata {
    const item: KnowledgeMetadata = {
      id: TEST_ID,
      title: 'GPIO 基础原理与工作模式',
      category: 'MCU_Peripherals',
      level: 'Basic',
      tags: ['GPIO', 'STM32'],
      summary: '测试用元数据摘要'
    };
    return item;
  }

  private static detail(): KnowledgeItem {
    // 适配 contentBlocks 动态富文本契约（替代已废弃的 content 九宫格结构）
    const blocks: ContentBlock[] = [
      { type: 'header', content: '核心概念' },
      { type: 'text', content: '通用输入输出端口' },
      { type: 'code', content: 'HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);', language: 'C' },
      { type: 'image', content: 'database/images/gpio/pinmode.png' },
      { type: 'warning', content: '忘记使能时钟会导致配置不生效' }
    ];
    const item: KnowledgeItem = {
      id: TEST_ID,
      title: 'GPIO 基础原理与工作模式',
      category: 'MCU_Peripherals',
      level: 'Basic',
      tags: ['GPIO', 'STM32'],
      summary: '测试用元数据摘要',
      images: ['knowledge/gpio/pinmode.png'],
      relatedProjectIds: ['proj_led_blink'],
      contentBlocks: blocks
    };
    return item;
  }

  async readKnowledgeMetadataList(): Promise<Result<KnowledgeMetadata[]>> {
    this.metadataCallCount = this.metadataCallCount + 1;
    if (this.failRead) {
      return { success: false, error: 'mock metadata failure', code: ErrorCode.FILE_NOT_FOUND };
    }
    return { success: true, data: [MockDataSource.metadata()] };
  }

  async readKnowledgeItem(id: string): Promise<Result<KnowledgeItem>> {
    this.detailCallCount = this.detailCallCount + 1;
    if (this.failRead) {
      return { success: false, error: 'mock detail failure', code: ErrorCode.FILE_NOT_FOUND };
    }
    await Promise.resolve(id);
    return { success: true, data: MockDataSource.detail() };
  }
}

export default function knowledgeRepositoryTest() {
  describe('KnowledgeRepositoryTest', () => {
    let mock: MockDataSource = new MockDataSource();
    let repository: KnowledgeRepository = new KnowledgeRepository(mock);

    beforeEach(() => {
      mock = new MockDataSource();
      repository = new KnowledgeRepository(mock);
    });

    /**
     * 核心用例：detailCache 命中拦截。
     * 连续两次读取同一 id，底层数据源必须只被调用一次。
     */
    it('getKnowledgeItem_ShouldHitDetailCache_OnSecondCall', 0, async () => {
      const first: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);
      const second: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);

      expect(mock.detailCallCount).assertEqual(1);
      expect(first.success).assertTrue();
      expect(second.success).assertTrue();
    });

    /** metadataCache 命中拦截。 */
    it('getKnowledgeMetadataList_ShouldHitMetadataCache_OnSecondCall', 0, async () => {
      const first: Result<KnowledgeMetadata[]> = await repository.getKnowledgeMetadataList();
      const second: Result<KnowledgeMetadata[]> = await repository.getKnowledgeMetadataList();

      expect(mock.metadataCallCount).assertEqual(1);
      expect(first.success).assertTrue();
      expect(second.success).assertTrue();
    });

    /** 缓存内容一致性：两次读取应返回同一实体数据。 */
    it('getKnowledgeItem_ShouldReturnSameEntity_WhenCacheHit', 0, async () => {
      const first: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);
      const second: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);

      expect(first.success).assertTrue();
      expect(second.success).assertTrue();
      if (first.success && second.success) {
        expect(first.data.id).assertEqual(TEST_ID);
        expect(second.data.id).assertEqual(TEST_ID);
        expect(second.data.title).assertEqual(first.data.title);
      }
    });

    /** 不同 id 应各自触底，缓存按 key 隔离。 */
    it('getKnowledgeItem_ShouldReachDataSource_ForDifferentIds', 0, async () => {
      const first: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);
      const second: Result<KnowledgeItem> = await repository.getKnowledgeItem('another_id');

      expect(first.success).assertTrue();
      expect(second.success).assertTrue();
      expect(mock.detailCallCount).assertEqual(2);
    });

    /** 失败分支：数据源失败时 Repository 必须透传 ErrorCode，且不污染缓存。 */
    it('getKnowledgeItem_ShouldPassThroughErrorCode_AndNotCacheFailure', 0, async () => {
      mock.failRead = true;
      const failed: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);
      expect(failed.success).assertFalse();
      // 显式类型收窄（Cleanup-4 修复）：ArkTS 在 `if (!x.success)` 分支内**未**将
      // Result<T> 收窄为 Failure，直接访问 .code 会报
      // "Property 'code' does not exist on type 'Success<KnowledgeItem>'"。
      // 故此处按工程既定模式做「已判别后的类型对齐」断言。
      const failure: Failure = failed as Failure;
      expect(failure.code).assertEqual(ErrorCode.FILE_NOT_FOUND);

      // 失败不应被缓存：恢复正常后再次调用应重新触底
      mock.failRead = false;
      const recovered: Result<KnowledgeItem> = await repository.getKnowledgeItem(TEST_ID);
      expect(recovered.success).assertTrue();
      expect(mock.detailCallCount).assertEqual(2);
    });

    /** clearCache 后应重新触底。 */
    it('clearCache_ShouldForceReload', 0, async () => {
      await repository.getKnowledgeItem(TEST_ID);
      expect(mock.detailCallCount).assertEqual(1);

      repository.clearCache();
      await repository.getKnowledgeItem(TEST_ID);
      expect(mock.detailCallCount).assertEqual(2);
    });
  });
}
