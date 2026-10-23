# Mooncakes 生态调查

读取日期：2026-10-23，十月赛。方法：读取公开 `https://mooncakes.io/api/v0/modules?q=icu`，实际响应为全部模块的 JSON 数组（q 未执行服务端筛选）；得到 3235 条、3235 个不同模块名，无分页字段。与首页统计 3235 相符。这是索引元数据覆盖，不是审阅全部源码。原始响应在本地忽略目录 research。

对 name/description/keywords 做大小写不敏感子串筛选，默认主题命中：AI 450、agent 94、workflow 23、parser 276、compiler 42、database 50、web 183、image 38、crypto 38、testing 60、devtool 6、wasm 249、visualization 15；AI 子串存在误命中，数量仅说明筛选方法，不作需求或贡献证据。定向词：locks、flock、fcntl、procfs、fdinfo、wait-for、linux。搜索范围内未发现 `/proc/locks` 等待树诊断模块，不证明不存在未索引实现。

| 相邻模块 | 索引版本/发布时间 | 实际边界与判断 |
|---|---|---|
| [illusory0x0/posix](https://mooncakes.io/docs/illusory0x0/posix) | 0.2.2 / 2025-06-25 | Apache-2.0 POSIX FFI；读取 fcntl.mbt 可见系统常量和调用适配；无锁快照/等待树公开层。可为调用方取得锁，不代替诊断核心。 |
| [chensuiyi/subproc](https://mooncakes.io/docs/chensuiyi/subproc) | 0.3.0 / 2026-10-06 | 进程、pidfd、procfs 采样；源仓库本次 404，未确认锁 API，故不宣称源码证明其缺失。 |
| [trail-it/moonpressure](https://mooncakes.io/docs/trail-it/moonpressure) | 0.3.0 / 2026-10-21 | cgroup/PSI 与任务准入；资源压力与文件字节区间锁等待需求不同。 |
| [Derk2006/sourcemap](https://mooncakes.io/docs/Derk2006/sourcemap) | 0.1.1 / 2026-08-11 | 已有 VLQ、查询、合成、裁剪、lint；同向方案淘汰。 |
| [Zhouz-z/moon_l10n](https://mooncakes.io/docs/Zhouz-z/moon_l10n) | 0.2.0 / 2026-08-16 | 跨目标 ICU 子集与 catalog linter；同向方案淘汰。 |
| [lqhy1234567/moonbit-vcd](https://mooncakes.io/docs/lqhy1234567/moonbit-vcd) | 0.3.1 / 2026-08-24 | 源树有 assertion_engine、transaction_monitor、latency_analysis；VCD 时序检查方向淘汰。 |

下载量与依赖采用数据未统一取得，不据此推断普及率。发布日期来自索引 created_at，与源码最近提交分开；MoonPressure 本机副本版本不同，不把本机旧版本当最新注册表事实。

结论：实现独立的 Linux 文件锁观察语义，纯 MoonBit 解析与等待树/区间查询，宿主只做读取；不再做通用 parser、HTTP 或 JSON 包装。
