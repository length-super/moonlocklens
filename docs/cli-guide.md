# MoonLockLens 0.3.0 使用指南

从 [GitHub Release](https://github.com/length-super/moonlocklens/releases/tag/v0.3.0) 下载 `moonlocklens-0.3.0.zip` 并解压。这是可直接使用的命令行工具。需要 Node.js 22 或更高版本；运行包不需要 MoonBit、Python、联网或安装第三方模块。

## 任务等待诊断与报告

Linux 输入卡住任务的根 PID：

```sh
./moonlocklens diagnose 1234
./moonlocklens watch 1234 --samples 10 --interval 500 --output incident.json
./moonlocklens report incident.json --markdown > incident.md
```

diagnose 采集一次；watch 保存有限次数的任务会话，默认 10 次、每次采集完成后间隔 500 ms。支持 1-60 次、100-5000 ms 间隔。实际时间线使用单调时钟，采集耗时会计入观察间距。watch 必须指定新的 --output 文件，以 0600 权限保存且拒绝覆盖。非 JSON 模式把采样进度写到 stderr，最终报告写 stdout。

report 支持 Windows/Linux 离线回放，输入为任务会话 JSON；--json 输出 machine report，--markdown 输出可分享的排障报告。无需真实进程仍在运行。可以先运行 `report fixtures/task-session.json` 体验 synthetic 三帧示例：父任务等待子进程，子进程两次被锁阻塞，第三次未再观察到锁等待。

报告给出当前进程树、PID+启动 ticks 身份、leader 状态、wchan 线索、锁请求/直接父行/阻塞者上下文、相关文件 device+inode、外部持有者元数据、观测变化和下一步检查建议。root PID 复用时不附着新任务；进程不再可见与成功完成分开表达。

已确认文件锁等待来自内核阻塞记录与 PID 的对应；wchan 只说明 leader 的睡眠位置，不能据此证明所有线程或根因。OFD owner=-1 无法单靠 PID 归属，仍可使用原有 live --file 定位。两次都观察到等待，不证明期间未释放/重获锁；报告中的 sampled span 不是精确等待时长。

任务会话 schema 为 moonlocklens-task/1；JSON 报告为 moonlocklens-report/1，内容位于 report 字段。64 位 ticks/毫秒值使用十进制字符串。--fail-on-wait 在整个窗口内曾确认锁等待时返回 3，包括最后一帧已恢复的情况。

任务采集读取可见进程的 stat/wchan 目录，再由 MoonBit 选择根任务、当前后代和相关外部阻塞者；保存文件只保留相关进程与锁证据，不读取 cmdline、环境变量或扫描 fd。父子进程按当前快照关系推导，不追踪脱离父进程后被重新收养的全部历史后代。采集非原子，权限、退出竞态和目录预算缺口会明确报告。

上限：4096 个可见进程目录、256 个任务进程、60 帧、16 MiB 级任务会话预算。catalog_complete=false 表示目录读取不完整，发现的子进程可能不全。单线程/多线程等待分析的边界为“进程 leader 线索及可见锁请求”；不提供通用死锁证明或业务完成判定。

原始 .locks 文件使用下面的 inspect/chain/range 命令；任务 incident.json 使用 report 命令。报告中的 L 行号是该帧归一化锁文本内的位置，不是 JSON 文件行号，也不是跨帧身份。

## 第一次运行

Windows 打开 PowerShell 并进入解压目录：

```powershell
.\moonlocklens.cmd --version
.\moonlocklens.cmd inspect .\fixtures\contention.locks
.\moonlocklens.cmd inspect .\fixtures\contention.locks --pid 300
```

Linux 进入解压目录：

```sh
chmod +x moonlocklens
./moonlocklens --help
./moonlocklens inspect fixtures/contention.locks --pid 300
```

上面的 fixture 是 synthetic 演示：PID 300 等待 PID 200，后者再等待 PID 100。`*` 标记匹配记录，未标记记录是为解释等待关系保留的阻塞者。显示的 L1/L2/L3 是输入文件的源行号，不是稳定锁 ID。

## 在 Linux 排查真实问题

```sh
./moonlocklens live
./moonlocklens live --pid 1234
./moonlocklens live --file /path/to/cache.lock
./moonlocklens live --file /path/to/cache.lock --waiting
```

把 1234 和路径替换成要诊断的进程及文件。`--file` 在 Linux 上对该路径做 stat（跟随符号链接），使用完整 device+inode 匹配 procfs；不扫描进程文件描述符。`--pid` 与 `--file`/`--key` 为同时满足的条件。OFD 的 owner=-1 不属于某个 PID，改用文件筛选可查看。

无匹配结果会显示 `No matching locks.`，退出码仍为 0。它只表示本次可见快照没有匹配项；路径与 procfs 读取之间可发生文件替换，namespace 外的锁也可能不可见。

## 保存现场，再到 Windows/Linux 回放

```sh
./moonlocklens capture incident.locks
./moonlocklens inspect incident.locks
./moonlocklens inspect incident.locks --waiting
./moonlocklens chain incident.locks 3
```

capture 只在 Linux 运行，保存标准 `/proc/locks` 原文，权限为 0600，不覆盖任何已有文件。文件名相同会报错，请另选文件名。源行号应从本次 inspect 输出中取得，不要照搬演示的 3。回放不需要目标进程仍在运行。

## 精确范围和脚本调用

```sh
./moonlocklens inspect incident.locks --key 08:01:42
./moonlocklens range incident.locks 08:01:42 100 EOF
./moonlocklens inspect incident.locks --json > report.json
cat incident.locks | ./moonlocklens inspect - --json
./moonlocklens inspect incident.locks --waiting --fail-on-wait --json
```

KEY 的 major/minor 为十六进制，inode 为十进制。起止字节均包含在范围内，EOF 为无界后缀；区间相交不是锁授予预测。`--key` 请使用 inspect 输出的实际标识。UTF-8/BOM 和 CRLF 输入均可读取，输入上限 4 MiB；超限会明确报错。

默认输出可读文本；`--json` 显式切换机器输出。inspect/live 的 JSON 为 schema `moonlocklens/2`，包含 observed_records、matching_records、matched_lines、entries、bottlenecks。entries 包括匹配项和阻塞者上下文，判定某条是否匹配应使用 matched_lines。bottlenecks 的计数是整个可见快照中该根的等待规模。chain/range 的 JSON 为 Entry 数组；错误为 stderr 上的 error 对象，stdout 留空。

退出码：0 成功（包括无匹配）；1 输入、格式或 I/O 错误；2 命令或参数错误；3 显式使用 --fail-on-wait 且匹配记录中有等待项。默认不因正常发现等待者而报错。

## 常见问题

- 找不到 node：安装 Node.js 22+ 并重新打开终端，然后 `node --version`。
- Windows 运行 live/capture：使用 Linux 采集，Windows 执行 inspect/chain/range 回放。
- --file 没有记录：确认是当前实际文件；文件可能已替换，或该类锁在文件系统上有不同实现。也可用 --key 检查保存快照中的 identity。
- 空 procfs：本次可见 namespace 可能没有锁。空快照是有效输入。
- --pid 不能找到 OFD：OFD 按 open file description 持有，不能归属一个 PID；使用文件身份筛选。
- 看到多个相同序号：这是同一棵阻塞树，按源行号和缩进区分节点。
- 文件名以 -- 开头：把选项放前面，使用 `inspect --json -- --name.locks`。

工具只读观察，不解锁、不杀进程；等待链不是死锁证明。离线范围查询可以跨平台执行，真实采集依赖 Linux procfs 的可见性。

## 不知道 PID 时按文件观察（0.4.0）

Linux：`moonlocklens watch-file /path/to/cache.lock --samples 10 --interval 500 --output file.json`。离线回放：`moonlocklens file-report file.json --markdown`，也可使用 `--json` 或 `--fail-on-wait`。采样次数、间隔和新建会话文件约束与 watch 一致。

保存的 moonlocklens-file/1 会话只保留原 device/inode 的锁及阻塞上下文，不保存路径、无关锁或进程 catalog。无需 PID，因此包括 OFD unknown owner。报告中的 waiting_records 是等待记录数，不是独立进程数。

路径替换为另一 inode 时标记 identity_changed 并继续观察原文件，不悄悄换对象；文件删除/不可读或锁证据缺失均显式记录。文件报告 JSON 为 moonlocklens-file-report/1。

## CI 和定时任务的等待阈值（0.4.0）

先用 watch 或 watch-file 保存会话，然后执行 `moonlocklens gate incident.json --wait-samples 3 --json`。同一任务进程身份连续 3 帧有确认锁等待，或原文件连续 3 帧有等待记录，则 fail，退出 3；可观察帧数足够、证据完整且未达到阈值则 pass，退出 0。

少于阈值帧数、采集中有权限/目录缺口或文件路径更换对象，且未获得足够违规证据时，返回 inconclusive，退出 4。输入/I/O 错误仍为 1，用法错误为 2。阈值为 1..60，默认 2；检查整个窗口，即使末帧恢复，先前达到阈值的等待仍算违规。

pass 仅表示该窗口未观察到达到阈值的锁等待，不判断业务是否成功，不将样本数换算为精确持续等待时长。gate 只读取会话，无需在 CI runner 上保留现场进程或安装额外模块；库提供 TaskCapture::assess、FileCapture::assess 和 assess_capture。
