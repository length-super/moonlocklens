# MoonLockLens 0.4.0 发布记录

账号与仓库保持 length-super，正式模块 length-super/moonlocklens@0.4.0。0.3.0 发布证据保留在 test-evidence/publishing.md；不覆盖已发布版本。

0.4.0 增加同任务会话对比、文件级观察（含 unknown OFD owner）和 CI 等待阈值检查。操作见 scenarios.md，验证见 test-evidence/scope-stage.md。Wasm-GC/JS 各 30 项核心测试、实际源码 ZIP 消费各 3 项、跨平台 CLI 与真实 Linux oracle 通过。运行包增至 9 文件。

版本正在完成正式发布；最终 CI 和确切版本 registry 消费结果将在完成后记录。CI 发布前验证已发布的 0.3.0，0.4.0 发布后切换新版本进行消费检查。

公开开发已有至少 10 条真实提交，新增三个功能分别提交，不拆分已有历史凑数。后续提交署名与上传账号均为 length-super；此前本地自动化历史保留真实作者及时间。

下载：https://github.com/length-super/moonlocklens/releases/tag/v0.4.0 。安装：`moon add length-super/moonlocklens@0.4.0`。项目申报书为 submission-proposal.md，单页 PDF 单独提供，不进入库包。官方报名和审核未执行。
