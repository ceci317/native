# 发布、排障与回滚

## 首次使用

把本仓库的 `skills/native-site-deploy` 文件夹复制到 Codex 的 `~/.codex/skills/native-site-deploy`，之后可以在任务中调用 `$native-site-deploy`。也可以直接让 Codex 读取仓库中的 `SKILL.md`。

需要 GitHub 上对 `ceci317/native` 的写入权限，以及本地 Git 和 Node.js 22。无需生产服务器权限。生产站点当前只有两份内容相同的静态 HTML；网页的 API Key 在用户自己的浏览器里保存，不属于发布物。

## 一次更新

```bash
git fetch origin main
git switch main
git pull --ff-only origin main
git switch -c feature/short-description
# 修改 index.html，然后同步到 native.html
node scripts/validate-site.mjs
git add index.html native.html
git commit -m "Describe the change"
git push -u origin feature/short-description
```

在 GitHub 创建 PR 并合入 `main`。若改了验证脚本、技能或工作流，把相应文件也纳入提交。CI 会再次执行 `node scripts/validate-site.mjs`。

访问 `https://github.com/ceci317/native/commits/main` 取得主分支提交 SHA。约 2 分钟后查看 <https://native.mirachat.cn/version.json>；最多等待 5 分钟。随后打开 <https://native.mirachat.cn/> 检查页面交互。`version.json` 的 SHA 与 GitHub 一致，才算部署完成。

## 发布未完成

- PR 检查失败：先修复、再次提交，不要绕过验证。
- 主分支已合入，但 5 分钟后 `version.json` 仍是旧 SHA：确认 GitHub 的主分支 SHA 和站点可访问性；不要连续合入相同改动。若有服务器权限，查看 `systemctl status native-deploy.timer native-deploy.service` 和 `journalctl -u native-deploy.service -n 80 --no-pager`。网络或服务故障需要服务器维护者处理。
- 站点返回旧页面但版本 SHA 已更新：检查浏览器缓存并强制刷新；也可在隐私窗口打开。
- 健康检查失败时，服务器自动恢复上一版本，`version.json` 仍显示旧 SHA。定位页面文件问题后提交修复。

## 回滚已发布的错误更新

在最新 `main` 上创建回滚分支，撤销自己的出错提交，验证并通过 PR 合入。若一个 PR 采用 squash 合并，只需撤销主分支上的那一个 squash 提交。

```bash
git fetch origin main
git switch main
git pull --ff-only origin main
git switch -c revert/broken-update
git revert <bad-commit-sha>
node scripts/validate-site.mjs
git push -u origin revert/broken-update
```

如果其他人的后续提交依赖这次改动，先检查差异并做针对性修复，不要盲目撤销。回滚 PR 合入后，以 `/version.json` 和页面实测确认。不要删除 GitHub 历史或强推主分支。

## 服务器边界

服务器上的定时任务以独立的 `native-deploy` 系统账号执行固定脚本 `/usr/local/sbin/deploy-native`。它只从公开仓库读取主分支的两份 HTML，不执行仓库里的脚本，也没有 Mira 服务和数据的写入权限。仓库的 `ops/` 文件是已安装配置的版本记录；修改它们不会自动修改服务器部署机制。
