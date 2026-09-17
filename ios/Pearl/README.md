# 家 · iOS

App 打开即进入 SwiftUI 原生聊天页，不再用 `WKWebView` 承载整站。无第三方依赖。

- 最低系统：iOS 16。
- 原生聊天支持历史分页、搜索/日期定位、SSE 流式正文与思考、停止生成、照片和语音发送。
- 消息流支持图片/语音回放、工具步骤、闹钟、推送、通话、卡片、音乐和 HTML 小作品。
- 顶栏可以看记忆水位，并调整模型、思考强度和原生思考开关。
- 当前只做聊天页，视觉统一为低饱和潮汐背景、半透明层次、细描边和克制的原生控件；其他页面暂不进入安装包。
- GitHub Actions 的 `Build unsigned iOS app` 生成未签名 IPA；在 Mac 上也可以直接用 Xcode 选择自己的 Team 后装到真机。

> 免费七天签名包不带 HealthKit entitlement，避免 Personal Team 在安装阶段拒绝。
