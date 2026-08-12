# KeepAwake 项目协作规则

## 应用与官网联动

每次修改 KeepAwake 应用后，都必须检查星岸AI网站中的 KeepAwake 介绍页是否需要同步更新：

- 网站仓库：`/Users/likeyi/Desktop/职业选择/项目/星岸AI/starshore-ai-website`
- 介绍页：`app/keepawake/page.tsx`

以下变化通常需要同步网站：

- 用户可见的功能、菜单、交互或使用流程
- 版本号、系统要求、安装包或 GitHub Release 下载地址
- 权限、管理员授权、隐私、联网行为或本地数据说明
- 功能限制、故障排查方法或使用边界
- 产品截图、演示内容、SEO 标题、描述或 FAQ 已与应用不一致

纯内部重构、格式调整、测试补充等不影响用户认知的变化，可以不修改网站，但仍需完成检查并在交付结果中明确说明“网站无需更新”及原因。

如果需要同步：

1. 只修改与本次应用变化直接相关的网站内容。
2. 分别执行 KeepAwake 构建检查和网站生产构建检查。
3. 发布应用时同步提交并部署网站，最后验证 GitHub Release 与线上页面。
4. 未经用户明确授权，不提交、推送、创建 Release 或触发生产部署。

## GitHub 推送认证

- 普通 Git 提交与推送优先使用本机已有的 GitHub SSH 公钥，不依赖 GitHub CLI Token。
- GitHub SSH 配置位于 `~/.ssh/config`，当前 `github.com` 使用 `~/.ssh/id_ed25519_github_nopass`。
- KeepAwake 的远端应保持为 `git@github.com:koi-lee/KeepAwake.git`。
- 推送异常时先检查 `git remote -v`，必要时使用 `ssh -T -o BatchMode=yes git@github.com` 验证身份；不要读取或输出私钥内容。
- `gh auth status` 显示 Token 失效，只表示 GitHub API/CLI 操作可能不可用，不代表 SSH `git push` 不能使用。只有创建 Release、查询 Actions 等必须调用 GitHub API 的操作才需要修复 `gh` 登录。
