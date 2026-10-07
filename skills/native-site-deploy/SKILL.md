---
name: native-site-deploy
description: Update and verify the NATIVE static website at native.mirachat.cn through ceci317/native. Use for routine site edits, releases, status checks, and rollback; not for Mira services or server configuration changes.
---

# NATIVE 网站更新

这是 `ceci317/native` 的发布技能。生产网站是 <https://native.mirachat.cn/>。服务器每约 2 分钟读取 GitHub `main`，仅发布 `index.html`、`native.html`，并生成公开的 `/version.json`。日常更新无需服务器账号；不要向朋友索取 Mira 的服务器 SSH 或其他服务密钥。

## 常规更新

1. 在仓库最新 `main` 上建立工作分支。修改页面时保持 `index.html` 和 `native.html` 内容完全一致；不要把 API Key 写入仓库。
2. 运行 `node scripts/validate-site.mjs`，检查页面中需要人工验证的交互，并提交代码。
3. 将分支推送到 `ceci317/native`，创建指向 `main` 的 PR。确认检查通过后，根据当前任务授权合并。
4. 读取 GitHub `main` 的最新提交 SHA，再访问 <https://native.mirachat.cn/version.json>。等待最多 5 分钟，直到 `commit` 与 SHA 一致，并实际检查更新的页面功能。

若版本没有更新，或网站行为不对，按 [发布、排障与回滚](references/operations.md) 处理。发布脚本只负责这个静态站；新增后端、构建链、域名或 Nginx 变更超出本技能的独立更新范围。

## 回滚

优先在 GitHub 上撤销造成问题的提交或合并 PR，重新合入 `main`；服务器会按新提交自动发布。不要强推主分支。服务器的健康检查失败时会自动恢复上一个版本；用 `/version.json` 确认实际在线版本。
