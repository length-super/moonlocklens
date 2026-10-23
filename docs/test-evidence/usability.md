# 0.2.0 实际使用验收

验证日期：2026-10-23。沿用 0.1.0 生态/规则证据，本次不重做选题。目标是完整的采集、定位、保存、回放和独立运行流程。

## 已执行结果

| 项目 | 证据与结果 |
|---|---|
| 格式、check/build | Windows 项目独立 MoonBit 工具链；Wasm-GC / JS --deny-warn 全部通过 |
| 核心测试 | 两后端分别 Total tests: 15, passed: 15, failed: 0；在原 13 个 test block 上补充选择与 blocker context 合约 |
| API | moon info；已有类型/方法保持，新增 Snapshot::matching、Snapshot::with_blockers；私有集合未暴露 |
| CLI 进程验收 | verify_cli.py 通过：文本/JSON、PID/key/waiter 组合、context、chain/range、stdin/BOM、空输入、无匹配、坏参数、坏 UTF-8、4 MiB 上限、错误源行、等待退出码、-- 文件名和控制符文本 |
| 源码包消费 | 实际 0.2.0 Mooncakes ZIP 解包，独立消费者两后端各 1 项通过；包含新公共方法；解包 CLI 单独构建执行通过 |
| 免编译运行包 | 7 文件 ZIP；只用 Node 运行独立解包副本，从其他工作目录调用过滤命令通过，Windows .cmd 启动器通过 |
| Linux 运行包 | 本机 WSL Linux 直接执行解包后的 lib/main.cjs；POSIX shell 启动器 --version 通过，无 Linux MoonBit 编译器依赖 |
| 实际采集 | POSIX/FLOCK/OFD 各一持有者、一真实阻塞等待者，字段、范围和链与独立 Python、lslocks 匹配 |
| 路径/PID 定位 | live --file --waiting 得到一个匹配等待者和其根 context；完整 device major/minor/inode 与独立 fstat 匹配；POSIX/FLOCK 的进程筛选匹配；OFD 保持 unknown owner |
| 自动化退出码 | --fail-on-wait 仅在匹配项有等待者时返回 3；上下文不伪装成匹配项 |
| capture/replay | 保存后回放所选三种锁完全匹配；重复 capture 失败且旧 bytes 不变，权限 0600 |
| PDF | 更新为 0.2.0 能力，一页 A4 并渲染检查 |

## 环境与口径

MoonBit 使用项目 release-local/toolchain：moon 0.1.20261012 (748b63c)，moonc v0.10.15+943464bfa，moonrun 同日期。Linux 执行该工具链生成的 JS，并未宣称验证 Linux 编译或 native 后端。Linux 为本机 WSL2 6.6.87.2；Node v24.18.1、Python 3.14.8、lslocks 2.41.2。

Linux oracle 使用私有 mount namespace 中、项目 release-local 下的临时 tmpfs；原因是 WSL Windows 文件盘会将 flock 映射为 POSIX。退出时卸载；仅清理本次创建的文件和等待进程。实际 procfs 原文不纳入分发包。以前的对照结果保留在 local.md，此次执行记录为 release-local/usability-checks.log、linux-oracle.json、distribution-evidence.json、package-evidence.json。

CLI 默认输出现在为文本；机器调用必须显式 --json。inspect/live JSON 为 moonlocklens/2，chain/range 仍为 Entry 数组；库的 Snapshot::to_json 仍保留 moonlocklens/1。此为明确记录的本地 0.2.0 CLI 行为变更。

Windows 可执行回放命令；Linux live/capture 依赖可见 procfs。路径 stat 与 procfs 读取不是原子事务，不能据无匹配结论证明从未存在锁；用户显式文件路径不会触发全机 fd 扫描。
