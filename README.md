# 家 · iOS

聊天页已用 SwiftUI 原生实现；“家”标签暂时用 `WKWebView` 打开现有站点。无第三方依赖。

- 最低系统：iOS 16。
- iOS 26 及以上：输入栏使用系统 Liquid Glass。
- iOS 16–18：同一处自动退回系统毛玻璃。
- 原生聊天支持历史分页、搜索/日期定位、SSE 流式正文与思考、停止生成、照片和语音发送。
- 消息流支持图片/语音回放、工具步骤、闹钟、推送、通话、卡片、音乐和 HTML 小作品。
- 顶栏可以看记忆水位，并调整模型、思考强度和原生思考开关。
- GitHub Actions 的 `Build unsigned iOS app` 生成未签名 IPA，之后在 Windows 用免费 Apple 账户签名安装。

> 免费七天签名先只验纯聊天。苹果能力表里的“Apple Developer”不等于 Xcode 的
> “Personal Team”；已有近期真机记录显示 HealthKit entitlement 可能被 Personal Team
> 拒绝。等聊天包签进真机后，再用独立 HealthKit 探针实测，不能让它卡住主 App。
