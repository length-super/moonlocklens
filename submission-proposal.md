# MoonLockLens 项目申报草稿

**项目**：MoonLockLens，Linux 任务等待与文件争用诊断、连续观察及离线报告。

**参赛者 / 队长 GitHub ID / 队员**：待指定。**公开仓库 / 正式模块 namespace**：待指定。**状态**：本地开发；未报名，未取得官方审核结果。

**问题**：构建缓存、后台任务或数据库工具卡住时，单一 PID/文件清单不足以解释多个字节区间锁和嵌套等待。OFD 锁还不能直接归到一个进程。

**成果（0.3.0）**：纯 MoonBit 有界解析 `/proc/locks`，保留 POSIX/FLOCK/OFD/lease 与未知字段；还原直接及传递等待关系，输出源行阻塞链与等待规模排名；按 device/inode 和 inclusive byte range 查询。可独立解压运行的 Node CLI 提供文本/JSON、PID/实际文件定位、等待筛选、stdin、现场保存与回放、自动化退出码；附 synthetic 示例、必要测试及真实 Linux oracle。

**任务流程**：从根 PID 选择当前后代，关联锁请求和外部持有者；diagnose/watch/report 支持连续观察、会话保存、文本/JSON/Markdown 回放。PID+starttime 区分进程身份，记录等待消失、状态及阻塞证据变化。真实 Linux 五帧观察验证释放后的恢复。wchan 仅为线索，采样跨度不是精确持续等待时长。

**独立贡献**：原创实现，非 POSIX FFI 或 lslocks 的移植。参考内核格式，新增 MoonBit 可组合快照模型、逐层 witness 和区间 API。相邻库及淘汰方向见生态报告；与已有四个本地项目的对象和目标用户任务不同。

**验证**：Windows Wasm-GC、JS 核心各 24 项测试，check/build/fmt/API/CLI；独立运行包启动器、实际源码归档消费，以及 Linux POSIX/FLOCK/OFD 锁、按路径/PID 定位、capture/replay 对照。当前结果见 docs/test-evidence/task-stage.md。

**边界**：只读快照；namespace 可见性有限；ordinal 非跨时间身份；OFD PID -1 明确未知；range overlap 非授予预测；等待树非死锁证明。MIT，无第三方运行模块依赖。参赛者需掌握架构与 AI 产物。

**本期**：2026 十月，10 月 31 日报名/验收截止、最多 3 次提交、每队不超过 3 人（2026-10-23 官网源码复核）。用户本次要求先保存在本地，因此公开持续开发、正式链接、报名/入群与审核仍待后续处理，不追补公开时间。
