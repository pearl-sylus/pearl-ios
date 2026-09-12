# 家 · iOS

当前版本打开即进入原生 SwiftUI 聊天页，不再用 `WKWebView` 承载整站。聊天数据、流式回复、照片、录音、工具卡片、旧话搜索和模型设置都走原生视图；网页只在消息本身确实是一张 HTML 卡片时作为内容查看器使用。无第三方依赖。

- 最低系统：iOS 16。
- 第一阶段先把现有 PWA 的浅蓝灰壁纸、软气泡、细标题栏和胶囊输入框搬到原生聊天页；后续再逐页原生化“家”、日记、相册和设置。
- GitHub Actions 的 `Build unsigned iOS app` 生成未签名 IPA，之后在 Windows 用免费 Apple 账户签名安装。

> 免费七天签名先只验纯聊天。苹果能力表里的“Apple Developer”不等于 Xcode 的
> “Personal Team”；已有近期真机记录显示 HealthKit entitlement 可能被 Personal Team
> 拒绝。等聊天包签进真机后，再用独立 HealthKit 探针实测，不能让它卡住主 App。
