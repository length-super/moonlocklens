# MoonLockLens 0.4.0 发布记录

账号与仓库保持 length-super，正式模块 length-super/moonlocklens@0.4.0。0.3.0 发布证据保留在 test-evidence/publishing.md；不覆盖已发布版本。

0.4.0 增加同任务会话对比、文件级观察（含 unknown OFD owner）和 CI 等待阈值检查。操作见 scenarios.md，验证见 test-evidence/scope-stage.md。Wasm-GC/JS 各 30 项核心测试、实际源码 ZIP 消费各 3 项、跨平台 CLI 与真实 Linux oracle 通过。运行包增至 9 文件。

0.4.0 已由 length-super 正式发布，Mooncakes 返回 200 OK。发布代码冻结在 6f0f7a5f498c2f50ee4cba996f6594dc7640a833，[发布代码 CI](https://github.com/length-super/moonlocklens/actions/runs/40842841047) 通过。

实际 registry 源码归档为 79 文件；SHA-256：4228e4f9572e6299343d3e49d78048c2ddc4c55a3b279017a05421cb416ae7d4。原发布归档保存在本地忽略目录，不以之后材料提交的重新打包结果替代。

独立模块执行 `moon add length-super/moonlocklens@0.4.0`，无 moon.work 重定向；Wasm-GC/JS 各 4 项消费者测试通过，包括文件会话、会话比较和 gate。CI 已切换确切版本 0.4.0 做 registry 消费检查；最终 main 的检查见 [verify](https://github.com/length-super/moonlocklens/actions/workflows/ci.yml)。

公开开发已有至少 10 条真实提交，新增三个功能分别提交，不拆分已有历史凑数。后续提交署名与上传账号均为 length-super；此前本地自动化历史保留真实作者及时间。

下载：https://github.com/length-super/moonlocklens/releases/tag/v0.4.0 。安装：`moon add length-super/moonlocklens@0.4.0`。申报书后续仅在本地维护，与代码和运行包分开处理。官方报名和审核未执行。

按用户要求，当前 Git 仓库和后续源码归档排除申报书 Markdown、PDF 及含申报正文的 PDF 生成脚本，本地保留。Release 只提供软件运行包。0.3.0/0.4.0 的既有历史与不可变旧包仍保留当时的副本，不重写既有提交或版本。

从 registry 下载的 0.4.0 模块编译 JS 后，POSIX/FLOCK/OFD oracle、任务采样、文件级释放/替换与 gate 均通过。新增材料清理不改变 0.4.0 的核心 API。
