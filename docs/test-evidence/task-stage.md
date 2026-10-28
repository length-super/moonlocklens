# 0.3.0 任务诊断阶段验收

日期：2026-10-28。模块 local/moonlocklens 0.3.0。本地续开发，沿用已有生态/规则调查，不执行发布或报名。

## 实际验证

| 检查 | 实际结果 |
|---|---|
| MoonBit 核心 | Wasm-GC 与 JS 各 24 个 test block，全部通过；含原有 15 项及新增任务/采样合约 |
| 进程解析 | 独立字段约定验证带括号、空格、换行的 comm；UInt64 starttime；截断/坏数字拒绝 |
| 树与锁证据 | 当前后代选择、外部 blocker 身份、请求直接父行、无关进程/锁不保留 |
| 时间连续性 | ordinal/源行变化不制造新身份；锁等待消失、阻塞证据变化、子进程 PID 复用分别记录 |
| 缺失证据 | 不可读 wchan/locks、root 不再可见、PID 复用、跨 scope、时钟回退和首样本 root 竞态均检查 |
| 资源上限 | 60 帧/256 任务进程/4096 catalog 上限及错误后不追加帧；总存储预算受限 |
| 跨平台 CLI | 原有锁 CLI 与 task report 的文本/JSON/Markdown/stdin/退出码/坏参数全部通过 |
| 实际 Linux 场景 | 真实父任务等待工作进程，后者被本次测试持有的 FLOCK 阻塞；进程树、starttime、wchan、file key 和外部持有者与独立 Python / procfs 对照匹配 |
| 五帧 watch | 在第二帧完成后释放锁；后续帧确认不再有该锁等待，报告出现 finding_changed；没有依赖任意定时 sleep 猜测释放时机 |
| 会话与报告 | 新建 0600 会话、离线重算报告、Markdown 导出、已有会话 bytes 不被覆盖均通过 |
| 源码归档 | 实际 moon package ZIP 解包，从独立消费者调用原有 API 与任务 API；记录在 release-local/package-evidence.json |
| 运行包 | 独立 Node 运行包含 8 文件；Windows/POSIX 启动器及解包后的任务报告验证，Linux oracle 使用该解包副本 |

新增 9 个 test block 关注进程身份、树、可解释结论、采样状态转换和边界；不是将重复后端执行合并为 48 个独立逻辑用例。外部消费测试单独计数。

## 环境和证据来源

Windows 工具链为项目内 moon 0.1.20261012 (748b63c)、moonc v0.10.15+943464bfa、同版 moonrun。Linux 为本机 WSL2，Node v24.18.1 / Python 3.14.8 / lslocks 2.41.2，执行 Windows MoonBit 工具链生成的 JS；不冒称验证了 Linux MoonBit 编译或 native 后端。

Linux 真实锁测试继续使用项目内私有 tmpfs，避免 WSL Windows 文件盘的 flock 映射影响语义；只清理本次创建的任务、工作进程和文件。task-linux-oracle.json 为脱敏结论，原始 procfs 会话在测试临时目录内清理。synthetic task-session.json 与真实测试分开。

源码实现核心包含 process.mbt、task_capture.mbt、task_report.mbt、task_markdown.mbt：解析、选择、关联、身份保护、连续观察与报告解释都在 MoonBit。JS 仅有界读取 stat/wchan/locks、单调时钟、采样等待和输出；不调用 lslocks 实现产品逻辑。lslocks/Python 仅作为独立测试 oracle。

这些结论证明本次任务诊断流程可运行，不将 wchan 当作根因证明，不将采样间隔当作精确等待时间。当前仍未公开发布、未正式报名、无官方审核结论。
