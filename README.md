# NATIVE

更新网站时，在本仓库修改页面并保持 `index.html` 与 `native.html` 内容一致，运行 `node scripts/validate-site.mjs` 后将代码提交到 `main`（建议先经 PR 检查）。服务器约每 2 分钟自动读取 `main`，只发布这两份静态页面；访问 [线上版本](https://native.mirachat.cn/version.json) 核对 `commit` 是否等于 GitHub 主分支的提交 SHA，再打开 [网站](https://native.mirachat.cn/) 检查功能即可。发布失败会保留上一版本；如果已上线的改动有问题，在 GitHub 撤销对应提交并重新合入 `main`，服务器会自动发布回滚版本。日常更新不需要登录服务器。
