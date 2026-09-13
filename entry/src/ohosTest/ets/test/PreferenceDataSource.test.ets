import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { ErrorCode } from '../../../main/ets/models/common/ErrorCode';
import { Failure, Result } from '../../../main/ets/models/common/Result';
import { PreferenceDataSource, PreferencesLike } from '../../../main/ets/datasources/PreferenceDataSource';

/** 与 PreferenceDataSource 内部保持一致的键名 */
const KEY_FAVORITES: string = 'user_favorites';
const KEY_HISTORY: string = 'user_history';

/**
 * 内存版 Preferences 测试替身。
 *
 * 用途：PreferenceDataSource 已提供可注入接缝（PreferencesLike），
 *      本替身使 A/B/C/D/E 全部用例无需真实 Preferences 服务即可确定性运行。
 * 能力：
 *  - 完整模拟 getSync / putSync / flush 语义（写入即生效，flush 为 no-op）；
 *  - 可预置任意原始值（用于构造损坏 JSON 场景）；
 *  - 可主动令读或写抛错，用于验证 STORAGE_READ_FAILED / STORAGE_WRITE_FAILED 映射。
 */
class FakePreferencesStore implements PreferencesLike {
  private data: Map<string, preferences.ValueType> = new Map<string, preferences.ValueType>();
  /** 为 true 时 getSync 抛错，模拟读失败 */
  failOnRead: boolean = false;
  /** 为 true 时 putSync 抛错，模拟写失败 */
  failOnWrite: boolean = false;

  /** 预置原始值（绕过业务写入路径，用于构造异常数据） */
  seed(key: string, raw: string): void {
    this.data.set(key, raw);
  }

  getSync(key: string, defValue: preferences.ValueType): preferences.ValueType {
    if (this.failOnRead) {
      throw new Error('fake preferences read failure');
    }
    const value: preferences.ValueType | undefined = this.data.get(key);
    return value === undefined ? defValue : value;
  }

  putSync(key: string, value: preferences.ValueType): void {
    if (this.failOnWrite) {
      throw new Error('fake preferences write failure');
    }
    this.data.set(key, value);
  }

  flush(): Promise<void> {
    return Promise.resolve();
  }
}

/**
 * PreferenceDataSource 单元测试（注入内存替身，不依赖真实 Preferences 服务）。
 *
 * 用例分组：
 *   [A] 序列化正常路径（经真实业务代码往返）
 *   [B] 结构损坏降级（必须返回 Success 空结构，而非 Failure）
 *   [C] FIFO 定长 30 条（写入侧截断 + 读取侧防越界）
 *   [D] 去重语义（保留首次出现位置）
 *   [E] 错误码分支（读失败 → STORAGE_READ_FAILED；写失败 → STORAGE_WRITE_FAILED）
 *
 * 说明：注入 store 后构造参数 context 不会被使用（仅生产路径需要它访问真实 Preferences），
 *      故此处只取一个可用对象填充，不参与任何断言。
 */
export default function preferenceDataSourceTest() {
  describe('PreferenceDataSourceTest', () => {
    let fake: FakePreferencesStore;
    let dataSource: PreferenceDataSource;

    beforeEach(() => {
      fake = new FakePreferencesStore();
      const store: PreferencesLike = fake;
      // 注入 store 后该 context 不会被使用（仅生产路径需要它访问真实 Preferences）
      const context: common.Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      dataSource = new PreferenceDataSource(context, store);
    });

    // ==================== [A] 序列化正常路径 ====================

    /** A-1：收藏列表写入后应能原样读出。 */
    it('favorites_ShouldRoundTrip_OnNormalPath', 0, async () => {
      const saved: Result<void> = await dataSource.saveFavorites(['a', 'b', 'c']);
      expect(saved.success).assertTrue();

      const loaded: Result<string[]> = await dataSource.loadFavorites();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(3);
      expect(loaded.data[0]).assertEqual('a');
      expect(loaded.data[1]).assertEqual('b');
      expect(loaded.data[2]).assertEqual('c');
    });

    /** A-2：完成标记字典写入后应能原样读出。 */
    it('progress_ShouldRoundTrip_OnNormalPath', 0, async () => {
      const map: Map<string, boolean> = new Map<string, boolean>();
      map.set('stage1_intro', true);
      map.set('stage3_gpio', false);
      const saved: Result<void> = await dataSource.saveProgress(map);
      expect(saved.success).assertTrue();

      const loaded: Result<Map<string, boolean>> = await dataSource.loadProgress();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.size).assertEqual(2);
      expect(loaded.data.get('stage1_intro')).assertTrue();
      expect(loaded.data.get('stage3_gpio')).assertFalse();
    });

    // ==================== [B] 结构损坏降级 ====================

    /** B-1：非 JSON 文本 → 降级为 Success(空数组)，不得返回 Failure。 */
    it('favorites_ShouldDegradeToEmpty_OnBrokenJson', 0, async () => {
      fake.seed(KEY_FAVORITES, 'not a json');

      const loaded: Result<string[]> = await dataSource.loadFavorites();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(0);
    });

    /** B-2：JSON 合法但根为对象（非数组）→ 降级为 Success(空数组)。 */
    it('favorites_ShouldDegradeToEmpty_OnObjectInsteadOfArray', 0, async () => {
      fake.seed(KEY_FAVORITES, '{"x":1}');

      const loaded: Result<string[]> = await dataSource.loadFavorites();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(0);
    });

    /** B-3：JSON 合法、根为数组但元素非 string → 降级为 Success(空数组)。 */
    it('favorites_ShouldDegradeToEmpty_OnNonStringElements', 0, async () => {
      fake.seed(KEY_FAVORITES, '[1,2,3]');

      const loaded: Result<string[]> = await dataSource.loadFavorites();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(0);
    });

    // ==================== [C] FIFO 定长 30 条 ====================

    /** C-1：写入 35 条 → 读出恰好 30 条，保留输入顺序前 30 条（最新 30 条）。 */
    it('history_ShouldTruncateTo30_OnOverflowWrite', 0, async () => {
      const ids: string[] = [];
      for (let index: number = 0; index < 35; index++) {
        ids.push(`id_${index}`);
      }
      const saved: Result<void> = await dataSource.saveHistory(ids);
      expect(saved.success).assertTrue();

      const loaded: Result<string[]> = await dataSource.loadHistory();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(30);
      expect(loaded.data[0]).assertEqual('id_0');
      expect(loaded.data[29]).assertEqual('id_29');
    });

    /** C-2：读取侧同样截断 —— 直写 35 条越界数据，读出应被裁剪为 30 条。 */
    it('history_ShouldTruncateTo30_OnLegacyOverflowRead', 0, async () => {
      const ids: string[] = [];
      for (let index: number = 0; index < 35; index++) {
        ids.push(`legacy_${index}`);
      }
      fake.seed(KEY_HISTORY, JSON.stringify(ids));

      const loaded: Result<string[]> = await dataSource.loadHistory();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(30);
      expect(loaded.data[0]).assertEqual('legacy_0');
      expect(loaded.data[29]).assertEqual('legacy_29');
    });

    // ==================== [D] 去重语义 ====================

    /** D-1：连续重复 → 仅保留一个。 */
    it('history_ShouldDedup_OnAdjacentDuplicates', 0, async () => {
      const saved: Result<void> = await dataSource.saveHistory(['a', 'a', 'b', 'b', 'c']);
      expect(saved.success).assertTrue();

      const loaded: Result<string[]> = await dataSource.loadHistory();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(3);
      expect(loaded.data[0]).assertEqual('a');
      expect(loaded.data[1]).assertEqual('b');
      expect(loaded.data[2]).assertEqual('c');
    });

    /** D-2：非相邻重复 → 保留首次出现位置（等价于保留最新访问位置）。 */
    it('history_ShouldKeepFirstOccurrence_OnInterleavedDuplicates', 0, async () => {
      const saved: Result<void> = await dataSource.saveHistory(['a', 'b', 'c', 'a', 'd']);
      expect(saved.success).assertTrue();

      const loaded: Result<string[]> = await dataSource.loadHistory();
      expect(loaded.success).assertTrue();
      if (!loaded.success) {
        return;
      }
      expect(loaded.data.length).assertEqual(4);
      expect(loaded.data[0]).assertEqual('a');
      expect(loaded.data[1]).assertEqual('b');
      expect(loaded.data[2]).assertEqual('c');
      expect(loaded.data[3]).assertEqual('d');
    });

    // ==================== [E] 错误码分支（Fake 主动抛错） ====================

    /** E-1：Preferences 读失败 → Failure(STORAGE_READ_FAILED)。 */
    it('loadFavorites_ShouldReturnStorageReadFailed_OnReadError', 0, async () => {
      fake.failOnRead = true;

      const loaded: Result<string[]> = await dataSource.loadFavorites();
      expect(loaded.success).assertFalse();
      if (loaded.success) {
        return;
      }
      // ArkTS 仅在否定式判别下收窄 Result<T>，故显式对齐后取用 code
      const failure: Failure = loaded as Failure;
      expect(failure.code).assertEqual(ErrorCode.STORAGE_READ_FAILED);
    });

    /** E-2：Preferences 写失败 → Failure(STORAGE_WRITE_FAILED)。 */
    it('saveFavorites_ShouldReturnStorageWriteFailed_OnWriteError', 0, async () => {
      fake.failOnWrite = true;

      const saved: Result<void> = await dataSource.saveFavorites(['a']);
      expect(saved.success).assertFalse();
      if (saved.success) {
        return;
      }
      const failure: Failure = saved as Failure;
      expect(failure.code).assertEqual(ErrorCode.STORAGE_WRITE_FAILED);
    });
  });
}
