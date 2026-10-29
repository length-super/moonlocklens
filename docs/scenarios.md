# 0.4.0 应用场景与可复现操作

以下真实采集命令在 Linux 执行。解压运行包后使用，输出文件应为尚不存在的新文件。

## 1. CI 构建卡在共享缓存，不知道持锁进程

从已知的缓存锁路径开始：

```sh
./moonlocklens watch-file /path/to/cache.lock --samples 10 --interval 500 --output cache-session.json
./moonlocklens file-report cache-session.json --markdown > cache-report.md
./moonlocklens gate cache-session.json --wait-samples 3 --json > cache-gate.json
```

报告显示原文件的锁记录及直接阻塞关系，即使 OFD owner=-1 也可观察。gate 根据整个采样窗口判定；退出 3 表示确实观察到达到阈值的连续等待样本，退出 4 表示证据不完整或样本不足，应保留现场继续排查。无需将 unknown owner 误认成进程。

## 2. 备份、导入或批处理任务重叠

已知本轮根任务 PID 时：

```sh
./moonlocklens watch 1234 --samples 10 --interval 500 --output batch-session.json
./moonlocklens report batch-session.json --markdown > batch-report.md
./moonlocklens gate batch-session.json --wait-samples 3 --json
```

定位当前子进程的锁请求及外部持锁者，辅助检查是否与上一轮任务争用文件。task gate 只累计同一 PID+starttime 的连续样本；短暂等待、持续样本和可见性缺口分开处理。业务成功仍以任务自身状态为准。

## 3. 处理持锁者后核对效果

保持被诊断根任务的进程身份不变，在检查或处理外部阻塞来源前后分别采样：

```sh
./moonlocklens watch 1234 --samples 3 --interval 500 --output before.json
# 人工检查持锁程序及日志，按业务流程处理；工具本身不终止进程或释放锁。
./moonlocklens watch 1234 --samples 3 --interval 500 --output after.json
./moonlocklens compare before.json after.json --markdown > comparison.md
```

比较两份会话末帧，列出同身份进程锁等待消失、新等待、状态与阻塞证据变化。根任务重启、跨 boot 或跨 procfs scope 的会话拒绝直接比较；子进程消失不会被计作已确认恢复。

## 4. 故障转交与离线分析

将已保存的 task/file 会话交给开发人员，在 Windows 解压运行包后执行：

```powershell
.\moonlocklens.cmd report .\batch-session.json --markdown
.\moonlocklens.cmd file-report .\cache-session.json --json
```

现场进程无需仍然存活。会话保留必要身份与锁证据；文件会话不保留路径，无关系统锁不写入。原始任务会话仍可能包含相关进程名，应按现场数据的业务权限分享。

## 5. 在 MoonBit 工具中集成

安装 `length-super/moonlocklens@0.4.0` 并导入根包，可使用 `parse_task_capture`、`parse_file_capture` 重算报告；调用 `TaskCapture::compare` 对比同任务，调用 `assess_capture` 或类型的 `assess(wait_samples=3)` 获得 pass/fail/inconclusive。核心支持 Wasm-GC 和 JS，不依赖命令行调用 lslocks；Node 仅负责实际采集的宿主适配。

体验 synthetic 样例可直接运行 `file-report fixtures/file-session.json`、`report fixtures/task-session.json` 和 `gate fixtures/file-session.json --wait-samples 3`。它们与真实 Linux oracle 结果分开标注。
