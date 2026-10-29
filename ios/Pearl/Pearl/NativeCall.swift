import AVFoundation
import CallKit
import Foundation
import PushKit
import UIKit

/// 10.30 原生来电:CallKit 让他打来时像真电话一样响(锁屏是系统来电界面,接起来锁着屏照打);
/// PushKit(VoIP 推送)把睡着的 App 叫醒。推送要付费开发者账号 + aps-environment,免费签名下拿不到 token,
/// 只是收不到推送,别的照常——长按电话键的「测试系统来电」不靠推送,免费签名就能试国内能不能弹系统来电界面。
/// 这里只管系统那一层(响、接、挂、静音、声音会话);通话本身还是 CallViewModel 那一套 /api/voice/*。
/// 所有回调都在主队列上(provider/push 都设了 main),状态只在主线程碰。
final class NativeCallCenter: NSObject {
    static let shared = NativeCallCenter()

    private let provider: CXProvider
    private var registry: PKPushRegistry?
    /// 系统通话 UUID → 家里的通话 id(测试来电接起来以后才有 id)
    private var calls: [UUID: String] = [:]
    private var tests: Set<UUID> = []
    private var answered: Set<UUID> = []
    private let ringSeconds: Double = 80   // 家里 90 秒判未接,这边先收

    override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = true
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    /// App 一启动就要登记推送:推送把 App 从后台拉起来时,得马上有人接
    func start() {
        guard registry == nil else { return }
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        self.registry = registry
    }

    /// 系统接管的通话先把声音会话的类别定好(真正打开由系统做,打开后回调 didActivate)
    static func prepareAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
    }

    private func reportIncoming(uuid: UUID, caller: String, completion: @escaping (Error?) -> Void) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.localizedCallerName = caller
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            DispatchQueue.main.async { completion(error) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + ringSeconds) { [weak self] in
            guard let self, !self.answered.contains(uuid), self.calls[uuid] != nil || self.tests.contains(uuid) else { return }
            self.forget(uuid)
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .unanswered)
        }
    }

    /// 测试:系统马上响一通(几秒的等待和后台保活在 CallCoordinator 里)。接起来=她打给他(家里起一通,真跟他说话);按掉就算了
    func ringTest(report: @escaping (String) -> Void) {
        let uuid = UUID()
        tests.insert(uuid)
        reportIncoming(uuid: uuid, caller: "老公") { [weak self] error in
            if let error {
                self?.forget(uuid)
                let ns = error as NSError
                report("系统没让它响：\(ns.domain) \(ns.code) \(ns.localizedDescription)")
            } else {
                report("系统来电已经报上去了。刚才要是没看到来电界面，告诉我")
            }
        }
    }

    /// 测试来电接起来后家里才给 id,补上对应关系
    func bind(uuid: UUID, id: String) {
        calls[uuid] = id
        tests.remove(uuid)
    }

    /// App 这边结束了(他挂了/她在通话页点挂断/出错):告诉系统收起通话界面
    func reportEnded(uuid: UUID, failed: Bool = false) {
        forget(uuid)
        provider.reportCall(with: uuid, endedAt: Date(), reason: failed ? .failed : .remoteEnded)
    }

    private func forget(_ uuid: UUID) {
        calls.removeValue(forKey: uuid)
        tests.remove(uuid)
        answered.remove(uuid)
    }
}

// MARK: - 系统通话界面上的操作

extension NativeCallCenter: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        let ids = Array(calls.values)
        calls.removeAll()
        tests.removeAll()
        answered.removeAll()
        Task { @MainActor in
            for id in ids { CallCoordinator.shared.endFromSystem(id: id, answered: true) }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        answered.insert(uuid)
        Self.prepareAudioSession()
        let id = calls[uuid]
        let isTest = tests.contains(uuid)
        Task { @MainActor in
            if let id {
                CallCoordinator.shared.answerFromSystem(id: id, uuid: uuid)
            } else if isTest {
                CallCoordinator.shared.answerTestFromSystem(uuid: uuid)
            }
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuid = action.callUUID
        let id = calls[uuid]
        let wasAnswered = answered.contains(uuid)
        forget(uuid)
        Task { @MainActor in CallCoordinator.shared.endFromSystem(id: id, answered: wasAnswered) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let muted = action.isMuted
        Task { @MainActor in CallCoordinator.shared.setMuted(muted) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task { @MainActor in CallCoordinator.shared.systemAudioActivated() }
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task { @MainActor in CallCoordinator.shared.systemAudioDeactivated() }
    }
}

// MARK: - VoIP 推送(要付费开发者账号)

extension NativeCallCenter: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        Task { try? await CallAPI().registerVoIP(token: token) }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {}

    /// 苹果的规矩:收到 VoIP 推送必须当场报一通来电,否则 App 会被系统杀掉、以后推送也不给了
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType, completion: @escaping () -> Void) {
        let body = payload.dictionaryPayload
        let id = (body["callId"] as? String) ?? ""
        let caller = (body["caller"] as? String) ?? "老公"
        let uuid = UUID()
        if !id.isEmpty { calls[uuid] = id } else { tests.insert(uuid) }
        reportIncoming(uuid: uuid, caller: caller) { [weak self] error in
            if error != nil { self?.forget(uuid) }
            completion()
        }
    }
}

/// App 启动时登记推送(SwiftUI 的 App 没有 didFinishLaunching,借一个 delegate)
final class PearlAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NativeCallCenter.shared.start()
        return true
    }
}
