# 0.1.0 本地验证基线

此页保留首次交付证据；当前 0.2.0 续验结果见 usability.md。

验证日期：2026-10-23。全部输出保存在项目忽略目录 release-local；本报告为脱敏摘要。

## 工具链与环境

Windows 使用项目独立工具链，非系统 PATH 上原有的 2026-09-15 版本：

```text
moon 0.1.20261012 (748b63c 2026-10-12)
moonc v0.10.15+943464bfa (2026-10-12)
moonrun 0.1.20261012 (748b63c 2026-10-12)
MOON_HOME = <project>/release-local/toolchain
```

Linux 实际运行环境：本机 WSL2，Linux 6.6.87.2-microsoft-standard-WSL2；Node.js v24.18.1，Python 3.14.8，util-linux lslocks 2.41.2。Python/Node 从 Alpine 官方 3.24.3 包安装到项目忽略目录，未改发行版系统包。执行的是上述 Windows 工具链生成的 JS；没有把 Linux JS 运行冒称 Linux MoonBit 编译或 native 后端测试。

## 结果

| 检查 | 结果 |
|---|---|
| moon fmt --check | 通过 |
| Wasm-GC check/build --deny-warn | 通过 |
| Wasm-GC test --deny-warn | Total tests: 13, passed: 13, failed: 0 |
| JS check/build --deny-warn | 通过，含 CLI |
| JS test --deny-warn | Total tests: 13, passed: 13, failed: 0 |
| moon info，公开 API | 已生成并审阅；Snapshot 两个数组为 private |
| 双后端 examples/demo | 通过；输入标为 synthetic |
| Windows CLI inspect/chain/range | 通过，JSON 输出 |
| Linux POSIX 真实持有/等待 | 各 1 条，链/范围/lslocks 均匹配 |
| Linux FLOCK 真实持有/等待 | 各 1 条，链/范围/lslocks 均匹配 |
| Linux OFDLCK 真实持有/等待 | 各 1 条，owner=-1 为 OpenDescription；链/范围/lslocks 均匹配 |
| Linux live CLI | 通过，实际 procfs 中上述 6 条记录被识别 |
| Linux 错误 CLI | 不存在文件及孤儿等待均非零退出 |
| 实际 package ZIP 独立消费 | Wasm-GC/JS 各 1 项外部消费者测试通过；与库测试分开计数；解包 CLI 构建执行通过 |
| 一页 PDF | A4 一页，渲染检查 |

库 13 项 test block 包含：锁族/未知 metadata，CRLF/空输入，18 个坏数字或字段输入，错误树形，预算，嵌套父链与兄弟，直接/传递规模，根 ID 非排序和并列，inclusive/EOF，返回数组独立性，typed errors，JSON 大整数精度，深度 64 边界。不是把同一组测试跨后端相加称作 26 个独立逻辑用例。

## 独立对照与发现

Python 使用系统 fcntl 创建三类锁；独立正则解码 proc 原文后核对字段，预先由系统调用给定期望 offset；lslocks 独立核对锁族、模式、范围和等待标志。父持锁进程及自己启动的等待进程维持稳定直至采集结束，finally 只清理本次创建的子进程和临时文件。所有等待均为真实阻塞，不是 synthetic。

第一次在 WSL 的 NTFS/DrvFS 项目盘验证时，系统将 flock 暴露为 POSIX；oracle 正确失败。随后在私有 mount namespace 内把项目 release-local/linux-scratch 临时挂为 16 MiB tmpfs，以 Linux 本地文件系统语义执行完整矩阵并通过；退出时卸载。这个失败证明锁族行为与文件系统相关，不能从调用名推断实际 procfs 输出。公开脚本允许 MOONLOCKLENS_TEST_TMP 指向项目 release-local 内的 Linux 文件系统。

原始 procfs 与临时文件在测试结束即清理，不收录宿主 PID/inode 记录。Synthetic 二层等待 fixture 来自 kernel locks_show 的格式语义，真实集成覆盖一层等待与三类锁；不声称验证了每种内核 lease/delegation 状态。未知字段由 fixture 覆盖。未宣称跨 namespace 探测、死锁证明或性能基准。

规模口径（物理行，含空行/注释，非语义有效行）：MoonBit 核心实现 510，MoonBit 测试 244，CLI 65，demo 21，根公开生成接口 120。宿主 JS 位于 CLI 的 FFI 字符串中；Python 检查/制 PDF 脚本不计入 MoonBit 实现。没有用源码或测试数量推断官方验收结论。

远端源码传输曾被自动审批拒绝，本次采用本机 WSL 完成 Linux 验证，没有传输源码到该主机。Docker 引擎未能响应，未运行容器；它不作为成功证据。
