import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { preferences } from '@kit.ArkData';
import { ErrorCode } from '../../../../main/ets/models/common/ErrorCode';
import { Failure, Result } from '../../../../main/ets/models/common/Result';
import { UserProgressState } from '../../../../main/ets/models/user/UserProgressState';
import { PreferenceDataSource, PreferencesLike } from '../../../../main/ets/datasources/PreferenceDataSource';
import { UserRepository } from '../../../../main/ets/repositories/UserRepository';

/**
 * 内存版 Preferences 测试替身。
 *
 * 与 PreferenceDataSource 的可注入接缝（PreferencesLike）配合，
 * 使本套用例无需真实 Preferences 服务即可确定性运行，
 * 并可主动制造读 / 写失败以验证错误码与「失败不改状态」语义。
 */
class FakePreferenceStore implements PreferencesLike {
  private data: Map<string, preferences.ValueType> = new Map<string, preferences.ValueType>();
  /** 为 true 时 getSync 抛错，模拟读失败 */
  failOnRead: boolean = false;
  /** 为 true 时 putSync 抛错，模拟写失败 */
  failOnWrite: boolean = false;

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
 * 用于填充 PreferenceDataSource 构造参数的上下文。
 * 说明：注入 store 后该对象永远不会被使用（只有生产路径才会经它访问真实 Preferences），
 *      故此处仅需一个真实可用的 Context 实例填充类型。
 *      ohosTest 进程通过 AbilityDelegator 取得（Local Test 环境不支持系统 API，无法运行本套用例）。
 */
function obtainContext(): common.Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
}

/**
 * UserRepository 单元测试。
 *
 * 时序编排：FakePreferenceStore → PreferenceDataSource(context, fake) → UserRepository(dataSource)
 * 覆盖用例：
 *   [A] loadState 首次返回空状态
 *   [B] toggleFavorite 首次添加 → 再次 toggle → 移除
 *   [C] toggleFavorite 新增 id 置于数组首位
 *   [D] recordHistory 重复 id 去重并置顶
 *   [E] recordHistory 超过 30 条截断为 30
 *   [F] 写失败 → Failure(STORAGE_WRITE_FAILED) 且状态未被修改
 */
export default function userRepositoryTest() {
  describe('UserRepositoryTest', () => {
    let fake: FakePreferenceStore;
    let repository: UserRepository;

    beforeEach(() => {
      fake = new FakePreferenceStore();
      const store: PreferencesLike = fake;
      const dataSource: PreferenceDataSource = new PreferenceDataSource(obtainContext(), store);
      repository = new UserRepository(dataSource);
    });

    /** [A] 首次使用：三项均为空结构，且必须是 Success 而非 Failure。 */
    it('loadState_ShouldReturnEmptyState_OnFirstUse', 0, async () => {
      const state: Result<UserProgressState> = await repository.loadState();
      expect(state.success).assertTrue();
      if (!state.success) {
        return;
      }
      expect(state.data.favorites.length).assertEqual(0);
      expect(state.data.history.length).assertEqual(0);
      expect(state.data.progress.size).assertEqual(0);
    });

    /** [B] 收藏开关：首次添加 → 已收藏；再次 toggle → 移除。 */
    it('toggleFavorite_ShouldAddThenRemove_AcrossTwoCalls', 0, async () => {
      const added: Result<string[]> = await repository.toggleFavorite('stage1_intro');
      expect(added.success).assertTrue();
      if (!added.success) {
        return;
      }
      expect(added.data.length).assertEqual(1);
      expect(added.data[0]).assertEqual('stage1_intro');

      const removed: Result<string[]> = await repository.toggleFavorite('stage1_intro');
      expect(removed.success).assertTrue();
      if (!removed.success) {
        return;
      }
      expect(removed.data.length).assertEqual(0);

      const favorite: boolean = await repository.isFavorite('stage1_intro');
      expect(favorite).assertFalse();
    });

    /** [C] 新增收藏必须位于数组首位。 */
    it('toggleFavorite_ShouldPlaceNewIdAtFirstPosition', 0, async () => {
      await repository.toggleFavorite('first_id');
      const result: Result<string[]> = await repository.toggleFavorite('second_id');
      expect(result.success).assertTrue();
      if (!result.success) {
        return;
      }
      expect(result.data.length).assertEqual(2);
      expect(result.data[0]).assertEqual('second_id');
      expect(result.data[1]).assertEqual('first_id');
    });

    /** [D] 历史记录：重复 id 应被移除旧位置并置顶（去重 + 置顶）。 */
    it('recordHistory_ShouldMoveDuplicateIdToFront', 0, async () => {
      await repository.recordHistory('a');
      await repository.recordHistory('b');
      await repository.recordHistory('c');
      const result: Result<string[]> = await repository.recordHistory('a');
      expect(result.success).assertTrue();
      if (!result.success) {
        return;
      }
      expect(result.data.length).assertEqual(3);
      expect(result.data[0]).assertEqual('a');
      expect(result.data[1]).assertEqual('c');
      expect(result.data[2]).assertEqual('b');
    });

    /** [E] 历史记录超过 30 条时应截断为 30（截断由 DataSource 负责）。 */
    it('recordHistory_ShouldTruncateTo30_WhenExceedingLimit', 0, async () => {
      for (let index: number = 0; index < 35; index++) {
        await repository.recordHistory(`id_${index}`);
      }
      const state: Result<UserProgressState> = await repository.loadState();
      expect(state.success).assertTrue();
      if (!state.success) {
        return;
      }
      expect(state.data.history.length).assertEqual(30);
      // 最新写入的应位于首位
      expect(state.data.history[0]).assertEqual('id_34');
    });

    /** [F] 写失败必须返回 Failure(STORAGE_WRITE_FAILED)，且不得产生任何状态变更。 */
    it('toggleFavorite_ShouldReturnStorageWriteFailed_AndKeepStateUnchanged', 0, async () => {
      // 先建立可观测的初始状态
      await repository.toggleFavorite('stable_id');
      const before: Result<UserProgressState> = await repository.loadState();
      expect(before.success).assertTrue();
      if (!before.success) {
        return;
      }
      const beforeFavoriteIds: string[] = before.data.favorites;
      const beforeLength: number = beforeFavoriteIds.length;

      // 令写入失败后再次 toggle
      fake.failOnWrite = true;
      const failed: Result<string[]> = await repository.toggleFavorite('another_id');
      expect(failed.success).assertFalse();
      if (failed.success) {
        return;
      }
      const failure: Failure = failed as Failure;
      expect(failure.code).assertEqual(ErrorCode.STORAGE_WRITE_FAILED);

      // 恢复可读后核对状态未被修改（快照比对）
      fake.failOnWrite = false;
      const after: Result<UserProgressState> = await repository.loadState();
      expect(after.success).assertTrue();
      if (!after.success) {
        return;
      }
      expect(after.data.favorites.length).assertEqual(beforeLength);
      expect(after.data.favorites[0]).assertEqual(beforeFavoriteIds[0]);
    });
  });
}
