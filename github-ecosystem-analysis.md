# GitHub 与规范调查

读取日期 2026-10-23。检索了 `moonbit language`、`moonbitlang`、`moonbit-community`、awesome-moonbit、topic:moonbit 与具体 sourcemap/ICU/VCD/file locks/proc/locks/fdinfo 组合。检索平台的匿名索引不完备；搜索无结果只约束本次范围。

| 来源 | 已读取证据 | 对本项目的影响 |
|---|---|---|
| [awesome-moonbit](https://github.com/moonbitlang/awesome-moonbit) | README/项目目录 | 作为生态入口，不是完整索引。 |
| [posix fcntl](https://github.com/moonbit-community/posix/blob/master/src/posix/fcntl.mbt) | 实际接口文件 | 现成 FFI 与锁诊断用途区分；不拷贝实现。 |
| [MiniVCDMBT](https://github.com/alicedhaha/MiniVCDMBT) | README、根树、issues API（空列表）、最近提交 API（2026-08-21） | 有完整解析/查询/比较；虽无 assertion 命中，另一个 VCD 库已覆盖，故淘汰该方向。 |
| [moonbit-vcd](https://github.com/lqhy1234567/moonbit-vcd) | README、根源码树 | assertion_engine.mbt、transaction_monitor.mbt、protocol_replay.mbt 已存在，不继续重复。 |
| [Linux v6.12 locks.c](https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux/+/refs/tags/v6.12/fs/locks.c) | lock_get_status、locks_show、__show_fd_locks | 输出 ID 为当次列表序号；相同 ID 下，阻塞树先序遍历，箭头前每多一个空格表示更深一层；PID 0/-1、lease 状态与未知类型需要保留。通过官方镜像 format=TEXT 解码读取。 |
| [util-linux lslocks.c](https://github.com/util-linux/util-linux/blob/master/misc-utils/lslocks.c) | get_lock、get_blocker、fdinfo 处理 | lslocks 是成熟诊断工具与独立 oracle。它按相同 ID 查根持有者；本项目补充可重用的逐层等待链与受影响规模 API，不能宣称发明了锁诊断。 |
| [proc_locks(5)](https://man7.org/linux/man-pages/man5/proc_locks.5.html) | 字段、范围、OFD、namespace 说明 | OFD 不归属单一 PID；结束字节包含在范围内，EOF 为无界后缀；可见范围受 proc 挂载 PID namespace 影响。 |

未找到可引用的 MoonBit 文件锁等待树 issue；不把推断的生态缺口虚构为已被用户提出的 issue。Linux 内核是格式语义依据，util-linux 是外部对照，两者实现均不拷贝进本项目。GitHub 限流使第一次 raw 内核请求失败，后改用官方 googlesource 镜像；subproc 链接 404，留为未能审阅。

与本批项目边界：Netlink 观察网络对象；MoonPressure 处理 cgroup/PSI；MoonFlacTag 改写音频元数据；MoonMount 解释挂载拓扑。本项目以 inode+device、字节范围、锁等待关系为独立对象，不复用它们的代码或验收证据。
