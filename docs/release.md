# MoonLockLens 0.3.0 发布记录

2026-10-29 用户授权发布到 length-super。仓库：https://github.com/length-super/moonlocklens 。正式模块：length-super/moonlocklens@0.3.0。

GitHub CLI 已核验登录 length-super（ID 335513007）；本仓库后续提交 author/committer 使用 length-super 和 GitHub noreply。此前五次本地开发提交保留真实自动化身份与时间；首次公开以实际推送时间为准。

发布准备包括：命名空间迁移、两个后端各 24 项核心测试、公开接口、Node 运行包、真实 Linux oracle、实际源码归档消费。发布代码 CI 已通过，Mooncakes 返回 200 OK，注册表确切版本安装后两个后端各 2 项消费者测试通过；下载包编译的 JS 也通过真实 Linux 文件锁与任务诊断流程。详细证据见 [发布验证](test-evidence/publishing.md)。

运行包 moonlocklens-0.3.0.zip 包含 8 文件，只需 Node.js 22+；由 scripts/build_cli.py 构建。源码归档由 moon package 产生 length-super-moonlocklens-0.3.0.zip，排除 output、research、release-local、工具链、缓存与 Git 元数据；PDF 作为 GitHub 文档/Release 附件提供。

正式发布不包含赛事报名、群聊加入或官方审核。此前本地阶段证据保留原时间和临时模块名，不冒充当时已经发布。

下载：[运行包与 PDF](https://github.com/length-super/moonlocklens/releases/tag/v0.3.0)。安装：`moon add length-super/moonlocklens@0.3.0`。[Mooncakes 文档](https://mooncakes.io/docs/length-super/moonlocklens@0.3.0)。

0.3.0 发布代码为 022ccd23fa70b9569782fcd9572024af8d7eb205，实际 registry 源码归档 64 文件；后续仅补充发布证据与 CI 步骤。原始已发布归档留在本地 release-local/length-super-moonlocklens-0.3.0.zip，不以工作树重新打包结果替代它。
