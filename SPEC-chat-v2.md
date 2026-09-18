# iOS 聊天页 v2 · 任务书(9.16 Pearl 定,Fable 出单,Codex 施工,Pearl 在 Mac 上编译截图,Fable 验收)

## 一句话需求
把现在 PWA 的聊天页(dark.pearl-sylus.org/pages/chat.html)**一模一样**搬进 SwiftUI,在此基础上加四样她要的:
1. **壁纸自己换**:从相册选图当聊天背景(也保留内置的几张),持久保存。
2. **看得清**:气泡和思考链在玻璃上看不清。给两把旋钮:气泡不透明度(60%-100%)、正文字重/字色(深/浅两档 + 自定义颜色)。默认值取"看得清"的一档,不是现在 PWA 的。
3. **颜色随她改**:主题色、她的气泡色、他的气泡色、正文字色、思考链字色,五个颜色选择器,改了立刻预览,持久保存,一键恢复默认。
4. 其余先照 PWA 现状做,细节她后面慢慢磨。

## 保留 / 重做
- **保留**:`ChatAPI.swift`、`ChatModels.swift`、`ChatViewModel.swift`(接口、模型、流式、分页、搜索、发图发语音、停止、旋钮都能用)。
- **重做**:整个视图层。`ChatView.swift` 一千行拆成组件(见第四节)。**禁止任何硬写的 RGB**,所有颜色/模糊/圆角/间距/字号只能从 `Theme.swift` 读。

## 二、Theme.swift(设计 token,先做,别的都依赖它)
从 PWA 的 `public/css/glass.css` / `purrden.css` / `js/tidal-theme.js` 抠出来,默认值如下,全部做成可被"外观设置"覆盖的 `@Published` 值,存 UserDefaults:

| token | 默认 | 来源 |
|---|---|---|
| accent 主题色 | #526b81 | --ui-accent |
| cardSolid 他的气泡底 | #f5f7f9 | --ui-card-solid |
| mineSolid 她的气泡底 | #dfe7ee | --ui-mine-solid |
| fieldSolid 输入框底 | #f8fbfc | --ui-field-solid |
| bubbleText 正文字色 | #2b2a2a | .bubble-text |
| metaText 工具行/思考标签色 | #3a3a3e | .step-agg summary |
| thinkLabel 思考标签 | #8e8e93 | .think-label |
| glassAlpha 气泡不透明度 | 84%(她要求默认改成 92%) | --g-alpha |
| glassBlur 模糊 | 18pt(0-40 可调) | --g-blur |
| glassTint 主题色掺入 | 12%(0-40 可调) | --g-tint |
| rim 玻璃描边 | rgba(255,255,255,.62) 浅 / .14 深 | --g-rim |
| shadow | 0 10 28 rgba(30,42,60,.10) + 0 1 2 .05 | --g-shadow |
| shine 高光 | 135° 白 .42→.08(38%)→0(60%) | --g-shine |
| thinkBg 思考正文底 | 白 .5,描边黑 .06,圆角 16,内边距 10/15 | .think-text |
| bubble 圆角 | 22 | .bubble |
| 正文字号/行高 | 15pt / 1.6 | .bubble-text |
| 工具行/思考标签字号 | 12.5pt / 1.3 | summary |
| 输入框字号 | 15.5pt | composer textarea |
| 气泡混色公式 | 他:card 掺 accent×(tint/3);她:mine 掺 accent×(tint×2.2);再按 glassAlpha 透明 | --g-his / --g-mine |

- **字体**:打包 `LXGW WenKai Screen`(霞鹜文楷屏幕版 TTF,开源 OFL)进 app,Info.plist 加 UIAppFonts;字体选项和 PWA 一样八种,系统字体外的先只打包霞鹜文楷,其他后补。
- **壁纸**:内置 PWA 现有的浅/深两张 + 相册选图(PhotosPicker,存到 app 沙盒,记路径);壁纸上盖一层可调的白/黑纱(0-60%),方便看清。

## 三、外观设置页(一个 sheet,右上角按钮进)
分组:壁纸(内置/相册/纱)、玻璃(开关、模糊、不透明度、掺色)、颜色(五个 ColorPicker + 恢复默认)、字体(列表)、可读性(字重 常规/中黑、字号 14/15/16)。所有改动实时反映在后面的聊天页上,不用返回。

## 四、组件清单(每项一个 commit,一张真机截图,和 PWA 同一段聊天记录对照)
1. `ChatBackground` 壁纸+纱
2. `GlassBubble` 她/他两色气泡(含 shine、rim、shadow、圆角、时间戳与缓存命中小字)
3. `ThinkBlock` 思考折叠(默认折叠,「✦ 他想过」标签,展开是 thinkBg 卡)
4. `StepRow` 工具行:横排、同类归并 `执行命令 ×N ⎿ Done`、点开每条平铺原命令+回执(照 PWA 9.12 版)
5. `AlarmBlock` 闹钟轮:一行小字 + 正常气泡,无粉块
6. `VoiceBar` 语音条(圆角胶囊、播放键、五根波纹、秒数,她右浅他左深)
7. `MusicCard` 点歌卡(封面、歌名、艺人、附言、播放)
8. `TarotCard` 排阵卡
9. `WriteCard` 碎碎念/记忆/暗房/邮件草稿/便签卡(现有 PWA 卡样式)
10. `AlbumRef` 图片消息与相册引用
11. `Composer` 输入框:一模一样(占位文案「把想说的放进来」,左「+」、模型·effort 标签、麦克风、发送三个等大圆钮)
12. 顶栏:「慢慢说」标题、副标题一句、搜索、水位小圆环
13. 外观设置 sheet(第三节)
14. 「看更早」「回到现在」、按日期跳转、搜索高亮 —— 沿用现有 VM

## 五、验收标准(Fable 执行)
- 每个组件截图与 PWA 同内容截图并排,像素级看:颜色、圆角、间距、字号、字体一致(允许 iOS 字体渲染差异)。
- 外观设置每个旋钮:改动即时生效、杀 app 重开仍在、恢复默认一键回到上表默认值。
- 可读性:默认设置下,白壁纸和深壁纸各截一张,正文和思考链肉眼清楚。
- 功能不丢:第四节 14 项全部可用,且 README 里现有功能(分页/搜索/日期/发图/发语音/停止/旋钮/水位)一个不少。
- 代码:`grep -rn "Color(red" ios --include=*.swift` 必须为 0;`grep -rn "\.font(\.system" ios --include=*.swift` 只允许在 Theme.swift 内。

## 六、施工规矩
- 顺序:Theme.swift → 外观设置 → 背景/气泡/思考 → 工具行/闹钟 → 语音/音乐/塔罗/卡片 → 输入框/顶栏。每步 commit 推 main,Pearl 在 Mac 上编译截图给 Fable。
- 本机无 Xcode,`swift` 语法自检能做的做;真编译在她 Mac。
- 不动 darkroom 服务端;需要新接口先在 WORKLOG 记【待拍板】。
- 其他页面(首页/日子/相册/设置)暂用 PWA 套壳(WKWebView)挂底栏,底栏只做「说话 / 家」两格,「家」进 PWA。

## 七、验收节奏(9.16 她定:不买开发者会员,不走每次 GitHub 打包)
- 她在 Mac 上 clone 仓库,每次 `git pull` 后 Xcode 选 iPhone 模拟器 Cmd+R 截图,不需要签名。真机只在节点装。
- 三个验收节点:①Theme + 外观设置 + 背景/气泡/思考;②工具行/闹钟/语音/音乐/塔罗/卡片;③输入框/顶栏/收尾。每个节点 Codex 在 WORKLOG 记一条"节点 N 可验",她截图,Fable 验。

## 八、自动截图(9.16 她定:她不会用 Xcode,Fable 在 Linux 没模拟器,借 GitHub 的 macOS runner 截)
- 新 workflow `.github/workflows/screenshots.yml`:push main 或手动触发 → macOS runner 编译 simulator 版 → `xcrun simctl` 起 iPhone 15 Pro → 跑 XCUITest 目标 `PearlScreenshots`。
- UI 测试按顺序截图并用 `XCTAttachment` 或 `xcrun simctl io booted screenshot` 存 PNG:
  1. `01-chat-default.png` 聊天页默认(滚到含他/她气泡+折叠思考的一段)
  2. `02-think-open.png` 同一段,点开一个思考块
  3. `03-steps-folded.png` / `04-steps-open.png` 有连续工具调用的一段,折叠与点开 ×N
  4. `05-voice-music.png` 含语音条与音乐卡的一段(用搜索定位关键词"点歌"或按日期跳 9.12)
  5. `06-composer.png` 输入框空态(三个圆钮)
  6. `07-appearance.png` 外观设置整页;`08-appearance-applied.png` 把气泡不透明度设 60%、换内置深色壁纸后回到聊天页
  7. `09-home-tab.png` 底栏「家」(PWA 套壳)
- 数据源:直接连线上 `https://dark.pearl-sylus.org`(聊天接口公开可读);若需登录态,用 repo secret 注入 cookie,不得把口令写进代码。
- 截图提交回仓库 `screenshots/<run号>/*.png`,用 `GITHUB_TOKEN` 以 `[skip ci]` 提交到 `shots` 分支(避免触发自身)。Fable 在服务器 `git fetch origin shots` 后读 PNG 验收。
- 第一次跑通后,以后每个 push 自动出一套图。

## 九、节点 4 · 她装上真机后的补齐单(9.18 起,持续追加)
照 PWA 的样子,不是"有这个功能"而是"在同一个位置、同样的手势能用":
1. 每条气泡下面的小图标行:时间戳右边有 **复制** 图标,她的消息还有 **重发** 图标(PWA 是常显小图标,不是藏在长按菜单里)。长按菜单可以保留,但小图标必须有。
2. **回到底部悬浮按钮**:往上翻历史时,右下角出现一个圆形 ↓ 按钮(PWA 有),点一下滚到最新;在底部时隐藏。现在只有历史分页模式才有"回到现在",普通往上滚没有。
3. 其余六种字体(思源宋/寒蝉圆/小赖/悠哉/月星楷/朱雀仿宋)打包进 app,设置里能选。
6. (待她继续补)……
验收:她在真机上和 PWA 并排操作,同一手势同一结果。
4. **思考链默认折叠**:现在 app 默认展开。照 PWA:默认只露「✦ 他想过」一行,点开才展开;直播中的思考也一样折叠,结束后保持折叠。
5. **卡顿**:她真机反馈"有点卡"。排查方向(按嫌疑大小):每条气泡各自一层 .ultraThinMaterial/blur(玻璃皮逐条算,列表一滚就掉帧)→ 改成背景一层玻璃、气泡用预混好的纯色+描边;LazyVStack 里每行的 AttributedString/Markdown 解析放到模型层缓存,不在 body 里算;历史一次只装 40 条;图片/封面异步加载并降采样。修完在真机上滚 200 条不掉帧为准。
