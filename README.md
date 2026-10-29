# MoonLockLens

[源码仓库](https://github.com/length-super/moonlocklens) · [版本下载](https://github.com/length-super/moonlocklens/releases/tag/v0.4.0) · [Mooncakes 0.4.0](https://mooncakes.io/docs/length-super/moonlocklens@0.4.0)

Linux 任务等待与文件争用诊断工具及 MoonBit 库。从一个任务 PID 出发，关联当前子进程、文件锁请求与外部阻塞者，连续采样并生成可回放的故障报告。核心为纯 MoonBit，零第三方运行模块依赖；Node.js 负责有界 procfs 读取、采样时钟与命令行 I/O。

## 从文件、任务与自动化进入排查

- 知道任务 PID：diagnose/watch/report 找当前后代和外部阻塞者。
- 只知道文件：watch-file/file-report 连续观察，包括 OFD unknown owner。
- 核对处理效果：compare 对比同一任务会话末帧，区分恢复观察与进程消失。
- 接入流水线和定时任务：gate 根据连续采样阈值返回通过、违规或证据不足。

完整操作见 [五个应用场景](docs/scenarios.md)，0.4.0 验证见 [范围扩展验收](docs/test-evidence/scope-stage.md)。

## 从卡住的任务进入诊断

Linux：

```sh
./moonlocklens diagnose 1234
./moonlocklens watch 1234 --samples 10 --interval 500 --output incident.json
./moonlocklens report incident.json --markdown > incident.md
```

把 1234 替换成实际任务的根进程 PID。工具列出当前子进程、已确认的锁请求和直接/传递阻塞证据；睡眠位置、停止/僵尸状态作为其他排查线索。观察到的状态变化、阻塞证据变化及不再可见会进入时间线，供定位下一步检查对象。

Windows 也能直接体验任务报告：

```powershell
.\output\cli\moonlocklens-0.4.0\moonlocklens.cmd report fixtures/task-session.json
```

此 fixture 为 synthetic：构建父任务等待工作进程，工作进程先被外部锁阻塞，随后锁等待消失。它与真实 Linux 验证分开记录。详细流程、证据等级和采样边界见 [任务诊断指南](docs/task-guide.md)。

## 直接使用 0.4.0

从 [GitHub Release](https://github.com/length-super/moonlocklens/releases/tag/v0.4.0) 下载运行包。源码构建输出：`output/cli/moonlocklens-0.4.0.zip`；已解压版本在 `output/cli/moonlocklens-0.4.0/`。只需 Node.js 22+，无需安装 MoonBit/Python。完整操作说明见 [使用指南](docs/cli-guide.md)。

在本项目根目录的 PowerShell 中直接试用：

```powershell
.\output\cli\moonlocklens-0.4.0\moonlocklens.cmd inspect fixtures/contention.locks --pid 300
```

Linux 解压后：

```sh
chmod +x moonlocklens
./moonlocklens live --file /path/to/cache.lock --waiting
./moonlocklens capture incident.locks
./moonlocklens inspect incident.locks --json > report.json
```

支持 PID、device+inode 和等待状态组合筛选，自动保留阻塞者上下文。默认可读文本，`--json` 用于脚本。capture 以 0600 权限保存原文并拒绝覆盖；保存后可在 Windows 回放。输入 `-` 从 stdin 读取 UTF-8/BOM 文本。显式添加 `--fail-on-wait`，可在匹配记录包含等待者时返回 3。

0.2.0 将 CLI 默认输出从 JSON 改为文本；旧脚本需添加 `--json`。库的已有类型与接口保持兼容，新增 matching 和 with_blockers。CLI inspect/live 的 JSON 为 schema moonlocklens/2，原始库 Snapshot::to_json 仍为 moonlocklens/1。

```text
PID 300 的请求 [源行 3]
  → 等待 PID 200 的请求 [源行 2]
    → 等待 PID 100 的根锁 [源行 1]
```

适合构建缓存、后台任务和容器故障排查。嵌套等待保留直接父节点；OFD 的 PID -1 标记为 OpenDescription，PID 0 标记为 NotVisible。未知类型、状态、模式和 lease 信息保留，不强行归为 POSIX。

## 本地开始

从源码开发需要 MoonBit `moonc v0.10.15+943464bfa`（本次验证版本，2026-10-12 工具链）和 Node.js 22+。核心支持 Wasm-GC 与 JS；Windows/Linux 都可回放，live/capture/diagnose/watch/watch-file 的实际采集需要 Linux。

```sh
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon run examples/demo --target wasm-gc
moon run cmd/main --target js -- inspect fixtures/contention.locks
moon run cmd/main --target js -- chain fixtures/contention.locks 3
moon run cmd/main --target js -- range fixtures/contention.locks 08:01:42 99 99
moon run cmd/main --target js -- live
```

`examples/demo` 和 `fixtures/contention.locks` 是明确标注的 synthetic 数据。chain 使用输入文件的 1-based 源行号，不是每次采集会变化的序号。范围查询的 major/minor 输入为十六进制、inode 为十进制，起止字节均包含，END 可为 EOF。正常输出默认为文本；添加 --json 输出 JSON。错误写入 stderr；退出码 1 为输入/I/O 错误，2 为用法错误。`--help` 输出命令说明。也可 `moon build --target js` 后直接用 Node 运行 `_build/js/debug/build/cmd/main/main.js`。

Windows 若系统默认 MoonBit 较旧，本项目忽略目录中已准备独立工具链；本机执行：

```powershell
./scripts/verify.ps1 -MoonHome ./release-local/toolchain
```

## 库接口

模块名为 `length-super/moonlocklens`。在消费项目中安装确切版本：

```sh
moon add length-super/moonlocklens@0.4.0
```

归档消费验证见 `scripts/verify_package.py`；注册表消费验证见 `scripts/verify_registry.py`。

```moonbit
let snapshot = @locks.parse(text)
let chain = snapshot.wait_chain(3)       // 请求本身 → 直接 blocker → 根记录
let impact = snapshot.bottlenecks()     // 根记录按所有后代等待数排序
let matching = snapshot.matching(pid=300, waiting_only=true)
let context = snapshot.with_blockers(matching.map(e => e.line))
let children = snapshot.children(1)     // 只返回直接等待项
let hits = snapshot.query_range(
  @locks.file_key("08:01:42"),
  @locks.byte_range("0", "99"),
  include_waiters=false,
)
```

调用包在 moon.pkg 中导入 `"length-super/moonlocklens" @locks`。根包拥有全部公开类型；`pkg.generated.mbti` 为实际编译器接口。`Snapshot` 的数组私有，查询返回独立数组，修改结果数组不会改变快照。错误类型为 `LockError::Invalid(line~, reason~)`；参数/预算错误 line 为 0。

## 格式与语义

- 按 Linux v6.12 `locks_show` 的先序输出还原树：`1: ->` 为深度 1，`1:  ->` 为深度 2；同根 ID、不跳层、不接受孤儿等待或重复根。
- 解析预算默认 4,194,304 UTF-16 units、10,000 条记录、64 层；CLI 读取在 4 MiB 字节处拒绝继续。预算可由库调用方显式调节。
- inode 使用 UInt64，offset 使用非负 Int64，支持最大有符号 offset 和 EOF，无须 `end + 1` 运算。JSON 中 ordinal/inode/offset 均为字符串，避免大整数精度丢失；无 parent_line/file 时省略该字段。
- 空文本与空行允许；支持 CRLF、缺少末尾换行。kernel 输出使用空格；tab 拒绝，因为它破坏等待深度含义。root ID 可以不按数值排序。
- LEASE 的 ACTIVE/BREAKING/BREAKER、`<none>:0` 和未知类型原样表达。等待树为记录关系，不把多个 OFD 未知 owner 合并成一个进程。

## 能力边界

只读当前可见 procfs。采集可见性受 proc 挂载所对应的 PID namespace 影响；不能保证观察到 namespace 外所有锁。输入是真实性由调用方负责的快照，解析成功不证明来源可信。序号与源行号均是单快照定位符，不用于跨时间身份识别。

wait_chain 是内核记录的等待依赖，不是死锁证明。query_range 只提供相同 device/inode 下区间相交证据，不判定是否授予锁；锁族、读写模式、owner 共享、文件系统/网络锁语义仍会影响结果。没有路径扫描、解锁、杀进程或自动修复操作。FST/VCD、Windows 锁、事件订阅不在当前范围。

## 验证与资料

- `python scripts/verify.py`：格式、双后端 check/build/test、示例与 CLI。
- Linux `python3 scripts/linux_oracle.py`：项目内临时文件取得 POSIX/FLOCK/OFD 锁，创建自己的等待进程；对照 Python fcntl、proc 原文和 util-linux lslocks，最终清理自己的子进程与临时文件。
- `python scripts/verify_package.py`：真实 moon package 归档、实际文件清单、隔离解包依赖消费者。
- `python scripts/build_cli.py`：生成只需 Node.js 的本地运行包。
- `python scripts/verify_distribution.py`：独立解包并从其他工作目录测试启动器与公开命令。
- `python scripts/verify_task_cli.py`：跨平台任务会话回放、JSON/Markdown 和时间线合约。
- Linux `python3 scripts/verify_task_linux.py`：真实父子任务、外部锁争用、五次连续采样及释放后的变化对照。
- 设计与调研：根目录 project-proposal 及三份生态/竞争报告。
- 验收与状态：`docs/acceptance-review.md`、`docs/release.md`、`docs/test-evidence/local.md`。

本项目为原创 MIT 实现，规范与工具参考见 THIRD_PARTY.md；AI 说明见 docs/architecture.md。发布目标由用户指定为 length-super；发布状态见 docs/release.md。赛事报名另行处理。

Linux oracle 需要支持三类锁的 Linux 文件系统。WSL 的 Windows 文件盘可能将 flock 映射为 POSIX；本次使用私有 mount namespace 下的项目内 tmpfs 验证，详见本地证据。可通过 `MOONLOCKLENS_TEST_TMP` 指定项目 release-local 内的 Linux 文件系统目录。
