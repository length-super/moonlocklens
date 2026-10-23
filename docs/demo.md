# 三分钟演示

0:00-0:30：`moon run examples/demo`，说明数据为 synthetic，展示 300 → 200 → 100 的两层等待，以及 OFD unknown owner。

0:30-1:15：`inspect fixtures/contention.locks`，查看 direct_waiters=2、total_waiters=3；`chain ... 3` 按行追踪直接父，说明不能把同 ordinal 所有等待者平铺在根上。

1:15-1:45：`range ... 08:01:42 99 99`，显示边界字节 99 与有限区间相交；改为 100 只剩 EOF 后缀请求。library 的 include_waiters=false 可只查根记录。

1:45-2:30：Linux `python3 scripts/linux_oracle.py`，展示三类真实锁竞争与 lslocks/Python 对照摘要。只有实际执行通过后才能把该段称为实机结果；synthetic 输出不替代它。

2:30-3:00：展示孤儿/跳层输入被拒绝；总结 API 用于诊断，namespace 可见性和 owner 语义由报告明确表达。无须 root，不操作用户业务锁。
