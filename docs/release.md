# 本地交付 0.2.0

源码模块：local/moonlocklens，正式发布 namespace 待定。版本与本地归档一致，仓库地址未编造。

面向使用者的免编译运行包为 `output/cli/moonlocklens-0.2.0.zip`，已解压目录为 `output/cli/moonlocklens-0.2.0/`。包含 lib/main.cjs、Windows/POSIX 启动器、说明、许可和 synthetic fixture，共 7 个文件；只需要 Node.js 22+，不需要 MoonBit、Python或联网。Windows 与 Linux 均实际运行解包副本。

库的源码归档由 `moon package` 生成 `_build/publish/local-moonlocklens-0.2.0.zip`，副本位于 `release-local/local-moonlocklens-0.2.0.zip`。实际文件数量和清单位于 release-local/package-files.json、package-evidence.json。独立消费者仅使用 ZIP 解包副本，不引用工作树；两个后端公共 API 和解包 CLI 均通过。

实际归档排除了 .git、.github、research、release-local、_build、target、tmp、output 和缓存。保留源码、接口、fixture、README、许可证、可复现检查脚本和必要说明。PDF 单独位于 output/pdf/submission-proposal.pdf，未进入库包；申报 Markdown 保留。

本地 Git 保留调研、核心开发及本次实际使用改进的真实提交。作者为明确的本地自动化占位，人员身份尚未指定。运行包不含 source map/本机源码路径；原始网页、工具链、主机锁快照和账号台账不分发。

后续发布需指定：仓库 owner/repo、真实 Git 贡献者信息、Mooncakes 账号与 namespace；随后核对公开 CI 默认分支 SHA、实际包清单和确切版本 registry 消费。用户当前仅授权本地保存，本次到本地交付停止。
