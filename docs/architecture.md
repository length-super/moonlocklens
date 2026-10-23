# 架构与解释要点

0.2.0：selection.mbt 组合 PID/file/waiter 过滤；with_blockers 从精确匹配的 source line 集合出发，逆序沿 parent 指针闭包，只加入实际阻塞者。返回仍保持快照顺序。matching 的 PID 必须为正数，OFD/不可见 owner 不伪装为进程。选择 API 不暴露内部数组。

CLI 按 host/options/commands/render 分包内文件：host 仅做有界 I/O、独占新建与 Linux stat；options 校验参数；commands 调用公开库；render 负责文本/JSON。过滤结果明确区分 matched_lines 与附加 blocker context。scope 中根的影响统计注明为整个可见快照计数。JSON 错误的 line 是数字或 null，而非 MoonBit Option 编码。

独立运行包把编译 JS 置于 lib/main.cjs，附 Windows/POSIX 启动器、说明、许可和 synthetic fixture；不依赖工作树、MoonBit、Python、注册表或第三方 JS 模块。去掉未分发 source map 的引用。capture 只创建新文件，读取/解析失败或已有目标均不覆盖既有内容。

numbers.mbt 用逐位有界累计解析 decimal/hex；先检查 `(cap-digit)/base` 再乘加，避免 UInt64 溢出。ByteRange 使用 inclusive 上界，None 表示 EOF，相交判断直接比较端点，避免最大 offset 加一溢出。

parser.mbt 先限制输入，再逐行解析七个锁字段。冒号后的第一个空格为 kernel 固定前缀；箭头之前总空格数恰为深度。stack[d] 是最近接受的深度 d 记录下标；同深度兄弟替换槽位，更深祖先被弹出。新根清空旧栈，blocked depth 不得超过栈长且 ordinal 必须匹配。父下标始终小于子下标，因此不可形成父指针环。

queries.mbt 按父下标还原 witness；逆序累计子树规模，每个等待项向直接父贡献 1+后代数。bottlenecks 只排名根记录；query_range 按 device/inode 和 inclusive range 筛选，不输出推测的“冲突”或“死锁”。查询返回新的数组，Entry 及其嵌套类型均为无可变字段值。

复杂度：解析在输入长度上近似线性（根 ID 使用哈希 Map）；bottlenecks O(n+r log r)，r 为有等待者的根数；source line 查询/children/range 为 O(n)，wait_chain 为 O(n+d)，d 为深度。默认预算限制规模，未宣传高吞吐或流式能力。

宿主边界：cmd/main 的 JS FFI 仅参数、UTF-8 文件读取、platform 与错误退出。所有字段、层级、整数、范围和影响计算均在 MoonBit。Node 库读取失败显式退出；不提供 host 凭据、全机 fd 扫描或 C 桥。

AI 辅助用于设计、编码、测试和文档。参赛者需能说明：为什么不能把 ordinal 当稳定 ID；OFD 为何不能归属单一 PID；kernel 缩进如何得到直接 blocker；区间相交为何不等于锁授予冲突；链为何不构成死锁结论。尚未取得参赛者本人理解确认，不代其声称官方 AI 可解释项已通过。
