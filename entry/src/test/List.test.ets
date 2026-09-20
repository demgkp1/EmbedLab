import localUnitTest from './LocalUnit.test';

/**
 * 本地单元测试套件入口。
 *
 * 说明（Cleanup-4 收尾）：
 *  - repositories/KnowledgeRepository.test.ets 与
 *    datasources/RawFileAssetDataSource.test.ets 暂未挂载。
 *  - 原因：两者需构造 resourceManager.ResourceManager 实例（64 成员 interface），
 *    在 ArkTS 严格模式下无法以合理成本 mock。
 *  - 相关条目已登记 BACKLOG，待独立卡处理。
 */
export default function testsuite() {
  localUnitTest();
}
