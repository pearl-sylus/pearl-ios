# 家 · iOS

当前版本先用 `WKWebView` 直接承载现有整站 UI；打开 App 就进入“家”，聊天、日记、相册、设置等页面沿用网页现有导航。无第三方依赖。

- 最低系统：iOS 16。
- iOS 26 及以上：输入栏使用系统 Liquid Glass。
- iOS 16–18：同一处自动退回系统毛玻璃。
- 网页 UI 更新后，App 无需重新发版即可同步看到。
- 保留现有 SwiftUI 聊天源码，后续可以逐块替换成原生页面。
- 壳层支持页面内导航手势、音视频播放、麦克风及照片选择。
- GitHub Actions 的 `Build unsigned iOS app` 生成未签名 IPA，之后在 Windows 用免费 Apple 账户签名安装。

> 免费七天签名先只验纯聊天。苹果能力表里的“Apple Developer”不等于 Xcode 的
> “Personal Team”；已有近期真机记录显示 HealthKit entitlement 可能被 Personal Team
> 拒绝。等聊天包签进真机后，再用独立 HealthKit 探针实测，不能让它卡住主 App。
