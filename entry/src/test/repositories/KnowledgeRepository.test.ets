import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { ErrorCode } from '../../main/ets/models/common/ErrorCode';
import { Result } from '../../main/ets/models/common/Result';
import { CodeSnippet } from '../../main/ets/models/knowledge/CodeSnippet';
import { KnowledgeContent, KnowledgeItem } from '../../main/ets/models/knowledge/KnowledgeItem';
import { KnowledgeMetadata } from '../../main/ets/models/knowledge/KnowledgeMetadata';
import { RawFileAssetDataSource } from '../../main/ets/datasources/RawFileAssetDataSource';
import { KnowledgeRepository } from '../../main/ets/repositories/KnowledgeRepository';

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
    const snippet: CodeSnippet = {
      language: 'C',
      code: 'HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);',
      description: '初始化 GPIO 引脚'
    };
    const content: KnowledgeContent = {
      prerequisite: '具备 C 语言基础',
      objective: '掌握 GPIO 工作模式',
      concept: '通用输入输出端口',
      principle: '通过寄存器配置引脚方向与电平',
      example: snippet,
      experiment: '点亮一颗 LED',
      tips: '注意上下拉配置',
      commonErrors: '忘记使能时钟',
      keyPoints: ['输入模式', '输出模式']
    };
    const item: KnowledgeItem = {
      id: TEST_ID,
      title: 'GPIO 基础原理与工作模式',
      category: 'MCU_Peripherals',
      level: 'Basic',
      tags: ['GPIO', 'STM32'],
      summary: '测试用元数据摘要',
      images: ['knowledge/gpio/pinmode.png'],
      relatedProjectIds: ['proj_led_blink'],
      content: content
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
      if (!failed.success) {
        expect(failed.code).assertEqual(ErrorCode.FILE_NOT_FOUND);
      }

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
