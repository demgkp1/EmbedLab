import abilityTest from './Ability.test';
import preferenceDataSourceTest from './PreferenceDataSource.test';
import userRepositoryTest from './repositories/UserRepository.test';

/**
 * ohosTest 测试套件总入口。
 *
 * 已废弃用例说明（Milestone 3.3 裁决）：
 *   PreferenceDataSource.production.test.ets.disabled 曾在本文件挂载，用于验证
 *   PreferenceDataSource 的 Preferences 生产读写路径。该用例已正式废弃，原因：
 *   ohosTest 进程的 getAppContext() 返回应用级 BaseContext，无 module sandbox 绑定，
 *   Preferences 服务运行时拒绝；而 App 进程内的 MainPage 走的是
 *   getUIContext().getHostContext()（具备 sandbox），二者是**不同的 Context 来源**，
 *   故该用例的设计前提与 ohosTest 环境本质冲突，不可能通过。
 *
 * 生产路径的有效证据（替代方案，已由人类架构师验证）：
 *   冷启动后按 tag 过滤 MainPage，可见：
 *     I/MainPage: user state hydrated: fav=N hist=N
 *   该日志由 MainPage.aboutToAppear 的启动水化链路产出，是生产路径的唯一有效证据。
 */
export default function testsuite() {
  abilityTest();
  preferenceDataSourceTest();
  userRepositoryTest();
}
