# 从一个卡住的任务开始

适用场景：构建/包管理作业、后台批处理、容器内共享缓存或文件竞争。0.3.0 将已有锁模型用于“父任务→当前工作进程→锁/等待线索→多次观察→故障报告”的流程。

## 操作路径

1. 找到任务根 PID，运行 `moonlocklens diagnose PID`。这里检查的是已存在的任务，不会代你启动、暂停或结束业务进程。
2. 看每个当前子进程的 finding。confirmed_file_lock_wait 表示有内核等待记录，request 的 parent_line 指向直接阻塞者；blockers 是完整上下文，包含更上层的传递阻塞者。
3. `moonlocklens watch PID --samples 10 --interval 500 --output incident.json` 观察变化。默认约数秒，实际耗时包含 procfs 扫描时间。
4. 将会话带到 Windows/Linux，执行 `moonlocklens report incident.json --markdown > incident.md` 生成报告。会话不能与原始 .locks 文件混用。
5. 根据 next_steps 检查已记录的阻塞者、文件身份、应用进度或线程状态。工具不会自动解锁或杀进程。

## 如何读结论

| finding / 状态 | 可以据此判断什么 |
|---|---|
| confirmed_file_lock_wait | 该进程有被观察到的内核锁等待请求；可按 request.parent_line 和 blocker context 还原证据链 |
| sleeping_wait_channel_hint | leader 睡眠，wchan 名称可读；是排查位置线索，不是业务根因 |
| sleeping_reason_unknown | leader 睡眠，但 wchan 为 0、空或不可读；原因仍未知 |
| runnable_progress_unknown | leader 可运行；不能据此认定任务已有业务进度 |
| stopped_or_traced / zombie | 观察到停止、调试或僵尸状态，可检查调试器/作业控制/父进程回收 |
| lock_evidence_unavailable | 锁快照读不到，不能把缺失当作“没有锁等待” |
| root not_observed / unavailable | 当前根进程不再可见或读取有缺口，不等于任务成功完成 |
| root identity_changed | 同一 PID 的 starttime 已不同；保留该事件并停止把它当作原任务分析 |

blocker_evidence_changed 表示前后快照的阻塞证据或 owner 身份信息发生变化，不保证精准捕获了锁对象的完整生命周期。ordinal 和源行号不会用于跨快照关联；进程按 PID+starttime，在一致 boot/reader PID namespace/procfs 挂载标识下关联。

## 时间线与范围

max_consecutive_wait_samples 是同一进程身份连续采样中出现锁等待的最大次数；max_sampled_wait_span_ms 是这串观察的首末采样时间差。间隔内未观察到的状态不可推断为连续，单样本 span 为 0。

当前处理 leader 信息及当前后代；不聚合每个线程的栈、不恢复重新收养的历史子进程，不推断所有 I/O/调度根因。OFD 锁不冒认 PID，遇到 unknown owner 时使用文件级分析。证据只来自当前可见 procfs；权限不足、退出竞态和目录预算会影响完整性。

## 规范依据

- [proc_pid_stat(5)](https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html)：comm 可能含空格/括号；字段 22 starttime 用于进程身份，保留无符号整数精度。
- [proc_pid_wchan(5)](https://man7.org/linux/man-pages/man5/proc_pid_wchan.5.html)：内核休眠位置及 ptrace 权限边界。
- [proc_pid_task(5)](https://man7.org/linux/man-pages/man5/proc_pid_task.5.html)：线程有独立状态，不能把 leader 状态当成全进程所有线程状态。

依据于 2026-10-28 读取的官方 man-pages。此阶段为既有项目实质扩展，未复制外部工具实现，不把通用 Linux 诊断声称为生态空白。

## 处理前后对比（0.4.0）

在处理持锁者前后分别保存同一任务的会话，运行 `moonlocklens compare before.json after.json --markdown`，或使用 `--json` 接入自动化。比较每份会话最后一帧，列出同身份进程锁等待消失、新等待、状态或阻塞证据变化。

比较要求 boot、procfs scope、根 PID 和 starttime 一致。子进程退出/不可见或 PID 复用分别记录，不计为已确认恢复。权限或目录缺口时 evidence_complete=false，恢复计数不作肯定结论；before/after 由参数顺序指定，不根据墙上时钟推断先后。
