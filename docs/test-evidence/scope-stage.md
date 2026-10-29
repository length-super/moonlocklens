# 0.4.0 应用范围扩展验收

日期：2026-10-29。模块 length-super/moonlocklens。三项独立改进按真实工作提交并公开：

| 改进 | 提交 | 用户任务与验证 |
|---|---|---|
| 同任务会话对比 | 642abe5 | 处理前后核对，拒绝混合 scope/根身份；不将消失或 PID 复用当作恢复 |
| 文件级连续观察 | 5f80fb0 | 无需 PID，观察 POSIX/FLOCK/OFD，验证锁释放与同路径换 inode |
| CI 等待阈值 | 22cc8a6 | 完整窗口检查，pass/fail/inconclusive 与 0/3/4 退出码；缺口不冒充通过 |

核心 Wasm-GC 和 JS 各 30 个 test block 全部通过。新增 6 个 block 针对会话比较、文件会话与阈值不变量；重复后端运行不合并计数。实际归档消费者两个后端各 3 项，覆盖原锁 API、任务报告/比较/阈值 API、文件报告及 OFD owner。

跨平台 CLI 验证包括 compare 的 text/Markdown/JSON/stdin 与 scope 错误、file-report 的回放/未知 owner/错误输入、gate 的窗口阈值/样本不足/权限缺口/退出码。Node 独立运行包增至 9 文件，包含三份明确标注的 synthetic fixture，解包后运行任务、文件报告及 gate。

本机 WSL 的真实 Linux 测试保持原有 POSIX/FLOCK/OFD 独立 fcntl/procfs/lslocks 对照与任务五帧采样。新增 verify_file_linux.py 对三类锁逐一创建竞争，在第 2 帧后释放；核对 fstat 文件身份、父行 witness、OFD unknown owner、后续无等待、0600 会话、拒绝覆盖。另验证同路径被新 inode 替换时报告仍跟踪原文件并标记 identity_changed，gate 返回 inconclusive。测试只清理本次创建的文件、子进程与私有 tmpfs。

MoonBit 仍使用项目隔离的 2026-10-12 工具链，Windows 编译便携 JS 后在 Linux 执行；不宣称验证 native 后端或 Linux MoonBit 编译。源码与打包检查由公开 CI 再验证，发布与 registry 结果在 release.md 补齐。

截至功能完成已公开 10 条真实提交；后续材料提交不用于代替核心功能。有效性最终以赛事审核为准，未执行报名或群聊操作。
