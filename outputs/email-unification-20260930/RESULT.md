# 邮箱统一核查结果（2026-09-30）

## 范围与结论

- 目标：将当前对外联系、支持、隐私、App Store/TestFlight 联系资料中的 `@starshoreai.com` 地址统一为 `service@starshoreai.com`。
- 保持不变：QQ/Gmail/163 等其他域名邮箱，以及 Apple 登录、恢复身份。
- KeepAwake 本地仓库扫描未找到 `@starshoreai.com`、`service@`、`support@`、`privacy@` 或 `contact@` 邮箱，因此本地无需替换。
- Apple 中国区公开商店页当前可见“开发者网站”和“隐私政策”两项，均指向 `https://github.com/koi-lee/KeepAwake`；页面没有单独列出技术支持链接，也没有显示联系邮箱。
- 本次未修改任何 App Store Connect 或 TestFlight 后台字段；未修改官网仓库、登录/恢复身份或历史发布证据；未提交、推送、部署或保存商店资料。

## 检查方式

- 检查当前分支及工作区差异后，对仓库内隐藏文件和常规文件进行邮箱域名搜索，并检查 README、App Store 上架流程、发布结果和项目状态文档。
- 检查上架流程文档列出的支持网址、营销网址、审核联系信息及隐私政策网址；该文档没有记录这些字段的实际邮箱值。
- 只读盘点后读取了 Chrome 中已有 App Store Connect 标签：该标签停在 `appstoreconnect.apple.com/login`，没有已登录会话；没有尝试登录或切换账号。
- 使用 Apple 中国区公开 App Store 页面核对对外链接；公开页面中的联系邮箱不可见，因此不能据此替代后台字段核验。

## 验证与未完成项

- `git status` 开始时为干净工作区；本次仅新增本核查结果及在项目状态文档中记录待核验项。
- 后台只读核验尚未完成：需在已登录的 App Store Connect 会话中核对 KeepAwake 的 App 信息支持/隐私链接、App Review 联系邮箱及 TestFlight 反馈联系邮箱。
- 额度星盘、Gaiqi、AIInterviewCards 的 TestFlight/App Review 邮箱也未核验，因为当前 App Store Connect 标签未登录；不能用本地文档或公开商店页代替后台实际值。
- 如果查到 `@starshoreai.com` 地址，先列出页面、字段名、当前值和建议值供审核；本次没有授权后台保存，不得直接提交修改。
