# 本地交付 0.1.0

源码模块：local/moonlocklens，正式发布 namespace 待定。版本与本地归档一致，仓库地址未编造。

运行 `moon package` 生成 `_build/publish/local-moonlocklens-0.1.0.zip`，实际 35 个文件。最终交付副本位于 `release-local/local-moonlocklens-0.1.0.zip`；文件清单与双后端解包消费结果位于 release-local/package-files.json、release-local/package-evidence.json。消费者只包含 ZIP 解包副本和独立调用工程，不引用工作树源码；解包后的 CLI 也已独立构建执行。

实际归档排除了 .git、.github、research、release-local、_build、target、tmp、output 和缓存。保留源码、接口、fixture、README、许可证、可复现检查脚本和必要说明。PDF 单独位于 output/pdf/submission-proposal.pdf，未进入库包；申报 Markdown 保留。

本地 Git 保留调研→功能→验证/文档阶段的真实提交。作者为明确的本地自动化占位，人员身份尚未指定。已检查分发文本/文件名，未纳入原始网页、工具链、主机原始锁快照或账号台账。

后续发布需指定：仓库 owner/repo、真实 Git 贡献者信息、Mooncakes 账号与 namespace；随后核对公开 CI 默认分支 SHA、实际包清单和确切版本 registry 消费。用户当前仅授权本地保存，本次到本地交付停止。
