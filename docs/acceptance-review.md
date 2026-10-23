# MoonLockLens 本地验收复核

2026-10-23，项目版本 0.2.0，本地模块 local/moonlocklens。

## 本地材料就绪

源码、MIT 许可、第三方来源、四份调研/方案、公开接口、Wasm-GC/JS 测试、可运行 demo/CLI、真实 Linux 文件锁 oracle、实际 package ZIP 与解包独立消费者、精简申报草稿和一页 PDF 已准备。0.2.0 增加免编译 Node 运行包、文本报告、PID/文件定位、筛选上下文、stdin、capture/replay 和自动化退出码；具体续验结果见 test-evidence/usability.md，0.1.0 基线保留在 local.md。

原创 MoonBit 核心提供 inode/device/byte-range 对象、严格等待树解析、逐层阻塞 witness、根锁受影响规模与区间查询。JS FFI 只做宿主读取/参数/退出。没有拷贝 Linux、util-linux 或相邻 MoonBit 项目实现。OFD unknown owner、PID 0、未知类型、lease 状态、不溢出的 EOF 范围均明确表达。

0.2.0 覆盖完整的采集→定位→保存→回放流程。真实系统验证仅操作本次创建的临时文件和子进程。按明确 --file 路径 stat，不扫描进程 fd；范围相交与等待依赖不宣称死锁判定。

## 公开发布状态

未创建远程仓库、未推送、未发布 Mooncakes。仓库 owner/repo、Git 人员身份、Mooncakes 账号与 namespace 待用户指定。当前 Git author/committer 明确为 Local development automation / local-development@invalid，仅记录本次本地自动化过程，不冒充参赛者身份。正式发布前须按用户指定的真实贡献归属核对；不得把本地历史补写为早已公开。

已准备 CI 配置，尚无远端运行或 registry 安装证据。实际本地包消费不等于注册表已可安装。没有沿用历史项目账号。

## 官方报名或审核状态

未报名、未入群、无官方审核结论。十月规则 2026-10-23 已联网复核，截止 2026-10-31、最多提交 3 次、每队不超过 3 人。用户实际已用报名次数与参赛身份未知。公开持续开发、正式可访问仓库、参赛者理解 AI 产物确认属于后续正式参赛事项，不能用本地就绪替代。

结论：本地交付就绪；公开发布与正式参赛未执行。不保证官方通过或获奖。
