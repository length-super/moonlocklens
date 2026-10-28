# Changes

## 0.3.0 - 2026-10-28

- 将独立应用范围扩展为任务等待与文件争用诊断：diagnose 根 PID、watch 连续采样、report 离线报告。
- 纯 MoonBit 解析 proc stat，按 PID/starttime 识别任务与当前后代，关联外部锁持有者及直接/传递证据。
- 区分已确认锁等待、leader 睡眠/wchan 线索、runnable 进度未知、停止/僵尸和证据缺失；不把推断写成确定根因。
- 有界采样会话保留 boot/读取者 PID namespace/procfs scope，拒绝时钟回退/混合范围；PID 复用不附着新任务。
- 记录连续观察、恢复和阻塞证据变化，导出 JSON/Markdown 故障报告及下一步检查建议。
- 包含任务 synthetic fixture、双后端 24 项核心测试、真实父子任务与外部锁释放的独立验证；原有文件锁命令保持。

## 0.2.0 - 2026-10-23

- 提供只需要 Node.js 22+ 的独立运行 ZIP、Windows .cmd 与 POSIX shell 启动器。
- CLI 默认可读文本；脚本显式使用 --json。inspect/live schema 为 moonlocklens/2。
- 按 --pid、--key、--waiting 组合筛选；Linux live 可按 --file 的实际 device+inode 定位。
- 保留精确 blocker context，区分 matched_lines 与展示上下文。
- Linux capture 保存标准原文为 0600 新文件，拒绝覆盖；跨平台 inspect/chain/range 回放。
- 支持 '-' stdin、UTF-8 BOM、结构化错误及 --fail-on-wait 退出码。
- 库新增 matching、with_blockers，已有 API 保持；补充真实 Linux 对照、CLI 和分发独立消费检查。

## 0.1.0 - 2026-10-23

首个本地版本：有界 proc/locks 模型、嵌套等待树、范围查询、影响统计、JSON CLI、双后端测试及 Linux oracle。
