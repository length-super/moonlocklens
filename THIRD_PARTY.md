# 来源与许可

MoonLockLens 自有实现采用 MIT（根 LICENSE）。没有复制第三方库、Linux 内核或 util-linux 源码；没有第三方运行模块依赖。MoonBit 标准库随工具链提供，属于外部工具链及其许可范围。

语义参考：

- [Linux v6.12 fs/locks.c](https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux/+/refs/tags/v6.12/fs/locks.c)：lock_get_status 和 locks_show 的输出格式与层级；只参考行为，不移植 GPL 实现。
- [proc_locks(5)](https://man7.org/linux/man-pages/man5/proc_locks.5.html)：字段与 PID namespace/OFD 解释。
- [util-linux lslocks](https://github.com/util-linux/util-linux/blob/master/misc-utils/lslocks.c)：作为独立 oracle 可执行工具，程序为 GPL-2.0-or-later；不将其源码/二进制包含在分发包内。

fixtures/contention.locks 为自有 synthetic fixture；没有宿主原始锁清单。Linux 集成测试自行创建文件和进程，结果仅发布脱敏摘要。原始网页与调研源码保留在忽略目录 research，不随包分发。

申报 PDF 由自有文字生成；使用 PDF 标准 CJK 字体引用，不附带或重新分发商业字体文件。
