# MoonLockLens 0.2.0 使用指南

这是可直接解压使用的命令行工具。需要 Node.js 22 或更高版本；运行包不需要 MoonBit、Python、联网或安装第三方模块。

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
