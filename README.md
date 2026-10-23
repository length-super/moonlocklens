# MoonLockLens

Linux 文件锁等待树诊断库与 CLI。把 `/proc/locks` 转成可解释的记录、逐层阻塞链和区间查询结果。核心为纯 MoonBit，零第三方运行依赖；Node.js 只负责命令行和有界文件读取。

```text
PID 300 的请求 [源行 3]
  → 等待 PID 200 的请求 [源行 2]
    → 等待 PID 100 的根锁 [源行 1]
```

适合构建缓存、后台任务和容器故障排查。嵌套等待保留直接父节点；OFD 的 PID -1 标记为 OpenDescription，PID 0 标记为 NotVisible。未知类型、状态、模式和 lease 信息保留，不强行归为 POSIX。

## 本地开始

需要 MoonBit `moonc v0.10.15+943464bfa`（本次验证版本，2026-10-12 工具链）和 Node.js 22+。核心支持 Wasm-GC 与 JS；CLI 支持 Windows/Linux Node.js，live 仅 Linux。

```sh
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon run examples/demo --target wasm-gc
moon run cmd/main --target js -- inspect fixtures/contention.locks
moon run cmd/main --target js -- chain fixtures/contention.locks 3
moon run cmd/main --target js -- range fixtures/contention.locks 08:01:42 99 99
moon run cmd/main --target js -- live
```

`examples/demo` 和 `fixtures/contention.locks` 是明确标注的 synthetic 数据。chain 使用输入文件的 1-based 源行号，不是每次采集会变化的序号。范围查询的 major/minor 输入为十六进制、inode 为十进制，起止字节均包含，END 可为 EOF。正常输出为 JSON；错误写入 stderr，退出码 1。`--help` 输出命令说明。也可 `moon build --target js` 后直接用 Node 运行 `_build/js/debug/build/cmd/main/main.js`。

Windows 若系统默认 MoonBit 较旧，本项目忽略目录中已准备独立工具链；本机执行：

```powershell
./scripts/verify.ps1 -MoonHome ./release-local/toolchain
```

## 库接口

`local/moonlocklens` 是本地开发模块名，正式 namespace 待指定。尚未发布到注册表；安装归档消费示例见 `scripts/verify_package.py`，不使用虚构 moon add 链接。

```moonbit
let snapshot = @locks.parse(text)
let chain = snapshot.wait_chain(3)       // 请求本身 → 直接 blocker → 根记录
let impact = snapshot.bottlenecks()     // 根记录按所有后代等待数排序
let children = snapshot.children(1)     // 只返回直接等待项
let hits = snapshot.query_range(
  @locks.file_key("08:01:42"),
  @locks.byte_range("0", "99"),
  include_waiters=false,
)
```

调用包在 moon.pkg 中导入 `"local/moonlocklens" @locks`。根包拥有全部公开类型；`pkg.generated.mbti` 为实际编译器接口。`Snapshot` 的数组私有，查询返回独立数组，修改结果数组不会改变快照。错误类型为 `LockError::Invalid(line~, reason~)`；参数/预算错误 line 为 0。

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
- 设计与调研：根目录 project-proposal 及三份生态/竞争报告。
- 验收与状态：`docs/acceptance-review.md`、`docs/release.md`、`docs/test-evidence/local.md`。

本项目为原创 MIT 实现，规范与工具参考见 THIRD_PARTY.md；AI 说明见 docs/architecture.md。公开仓库、正式 namespace、发布和赛事报名均待用户另行指定。

Linux oracle 需要支持三类锁的 Linux 文件系统。WSL 的 Windows 文件盘可能将 flock 映射为 POSIX；本次使用私有 mount namespace 下的项目内 tmpfs 验证，详见本地证据。可通过 `MOONLOCKLENS_TEST_TMP` 指定项目 release-local 内的 Linux 文件系统目录。
