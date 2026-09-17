# 家 · iOS

当前版本打开即进入原生 SwiftUI 聊天页，不再用 `WKWebView` 承载整站。聊天数据、流式回复、照片、录音、工具卡片、旧话搜索和模型设置都走原生视图；网页只在消息本身确实是一张 HTML 卡片时作为内容查看器使用。无第三方依赖。

- 最低系统：iOS 16。
- 当前只做聊天页：先把消息、思考、工具步骤和输入体验做完整、做漂亮，其他页面暂不进入安装包。
- GitHub Actions 的 `Build unsigned iOS app` 生成未签名 IPA；在 Mac 上也可以直接用 Xcode 选择自己的 Team 后装到真机。

> 免费七天签名包不带 HealthKit entitlement，避免 Personal Team 在安装阶段拒绝。
