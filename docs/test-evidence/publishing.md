# 0.3.0 正式发布验证

2026-10-29，用户指定 GitHub 上传账号、仓库 owner 与 Mooncakes 发布账号均为 length-super。

仓库：[length-super/moonlocklens](https://github.com/length-super/moonlocklens)。模块：[length-super/moonlocklens@0.3.0](https://mooncakes.io/docs/length-super/moonlocklens@0.3.0)。正式发布和注册表安装验证均已完成。

GitHub API 核验 login=length-super、ID=335513007。本仓库后续提交使用 length-super 和对应 GitHub noreply；原有五次本地自动化提交保留实际作者与时间，不改写为历史公开开发。

Mooncakes CLI 的项目隔离凭据仅核对 username=length-super，凭据本身不分发。发布前查询公开模块索引，未发现该模块，版本 0.3.0 尚无冲突。

| 项目 | 结果 |
|---|---|
| 命名空间迁移 | Wasm-GC/JS 各 24 项核心测试通过，原有 CLI 和任务会话 CLI 回放通过 |
| GitHub 公开来源 | main 分支发布代码提交 `022ccd23fa70b9569782fcd9572024af8d7eb205`；API 核实 author 与 committer 均关联 length-super |
| 发布代码 CI | [40831052704](https://github.com/length-super/moonlocklens/actions/runs/40831052704) success，含 Linux 真实 POSIX/FLOCK/OFD、任务五帧采样和实际归档消费 |
| Mooncakes 发布 | 2026-10-29 服务端返回 200 OK；公开模块索引确认 0.3.0、MIT 与正确 repository，yanked=false |
| 注册表独立消费 | `moon add length-super/moonlocklens@0.3.0`，依赖树确认确切版本且没有 moon.work 重定向；Wasm-GC/JS 各 2 项消费测试通过，执行锁链/范围/筛选与任务报告/Markdown API |
| 下载包 Linux 实测 | 从 registry 下载的模块编译 JS，运行 POSIX/FLOCK/OFD oracle 与真实父子任务五帧采样；身份、外部 blocker、文件 key、释放后变化、capture/replay/no-clobber 均通过 |
| 源码归档 | 实际发布 64 文件，SHA-256 `41883e5c404e604fd79d48db8e8f39206c20f7e27664b46d0482c657851cfa49`；不含输出、工具链、凭据、research 或 release-local |
| 独立运行包 | 8 文件，Windows/POSIX 启动器及解包回放通过；[版本下载](https://github.com/length-super/moonlocklens/releases/tag/v0.3.0) |

发布代码在上述提交冻结。发布后材料提交仅补充验证结果和 CI 的 registry consumer 步骤，不重复上传不可变的 0.3.0。最终 main 分支检查见 [verify 工作流](https://github.com/length-super/moonlocklens/actions/workflows/ci.yml)。

待推历史 5 个本地提交的 114 个不同 blob、发布新增文件及实际归档均进行目录和凭据模式核查；未发现所查模式命中。PDF 已更新账号/仓库并渲染检查，单页无截断。主机原始采集、登录凭据和发布辅助日志留在本地忽略目录。

范围为项目公开发布与验证。未提交赛事表单、未加入群聊、无官方审核结论。
