import AppKit
import SwiftUI
import CoreGraphics
import Translation

private struct AppLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

@MainActor
private final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @Published var selectedCode = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
    @Published private(set) var availableLanguages = [AppLanguage(code: "ko", name: "한국어")]
    @Published private(set) var translations: [String: String] = [:]
    @Published private(set) var isTranslating = false
    @Published private(set) var loadingLanguages = false
    @Published private(set) var translationError: String?

    private let sourceLanguage = Locale.Language(identifier: "ko")
    private let sourceStrings = [
        "조준점", "색상과 효과", "화면 보정", "언어", "설정", "조준점 표시 중", "조준점 숨김", "설정은 자동 저장됩니다",
        "보정 켜짐", "보정 꺼짐", "앱 종료", "실제 모양 미리보기", "화면 중앙 조준점의 모양과 정밀도를 설정합니다.",
        "모양과 배치", "모양", "간격 십자", "플러스", "점", "원", "원 + 점", "대각선 X", "사각형", "다이아몬드", "네 모서리", "T자",
        "크기", "중앙 간격", "회전", "중앙 점 표시", "중앙 점 크기", "선과 효과", "선 두께", "불투명도", "대비 외곽선", "외곽선 색", "외곽선 두께", "네온 빛 번짐", "번짐 강도", "조준점 초기화",
        "조준점 색상", "사용자 지정 색상", "즐겨찾기", "최근 사용", "현재 색을 즐겨찾기에 보관", "저장됨 ★", "즐겨찾기 ☆", "조준점 투명도", "화면 색조", "어두운 부분에 적용할 색", "색조 강도", "선택한 색조는 화면 보정을 켰을 때 적용됩니다.",
        "화면 톤", "감마 곡선으로 어두운 영역을 들어 올립니다.", "보정 시작", "보정 중지", "화면 조정", "노출", "암부 들어 올리기", "감마", "대비", "색조 색상", "어두운 맵 추천값 적용", "보정은 Roblox 창 위에 검은 화면을 덮지 않고, 디스플레이 전체의 모든 앱에 적용됩니다.",
        "앱 언어", "이 Mac에서 사용할 수 있는 번역 언어를 검색하고 선택하세요.", "언어 검색", "언어 목록을 불러오는 중…", "번역 준비 중…", "번역 언어를 사용할 수 없습니다.", "선택한 언어로 번역하지 못했습니다. 한국어 화면을 유지합니다.", "한국어 (기본)",
        "화면 전체에 적용하는 암부 보정입니다.", "이 디스플레이의 감마 조정을 적용하지 못했습니다.", "암부 보정 적용 중 — 이 디스플레이의 모든 앱 화면에 적용됩니다.", "원래 디스플레이 색상으로 복원했습니다.", "설정 열기", "화면 보정 중지",
        "Roblox Overlay · 설정은 자동 저장됩니다", "화면 중앙 조준점의 모양과 정밀도를 설정합니다.", "현재 색을 즐겨찾기에 보관", "어두운 부분에 적용할 색", "선택한 색조는 화면 보정을 켰을 때 적용됩니다.", "감마 곡선으로 어두운 영역을 들어 올립니다.", "보정은 Roblox 창 위에 검은 화면을 덮지 않고, 디스플레이 전체의 모든 앱에 적용됩니다.", "화면 전체에 적용하는 암부 보정입니다.", "화면 중앙 조준점의 모양과 정밀도를 설정합니다.", "앱 언어", "이 Mac에서 사용할 수 있는 번역 언어를 검색하고 선택하세요.", "언어 검색", "언어 목록을 불러오는 중…", "번역 준비 중…", "번역 언어를 사용할 수 없습니다.", "선택한 언어로 번역하지 못했습니다. 한국어 화면을 유지합니다.", "한국어 (기본)", "지원되는 언어만 표시됩니다. 언어별 모델 다운로드가 필요할 수 있습니다.",
        "한국어"
    ]

    func text(_ source: String) -> String { translations[source] ?? source }

    func select(_ code: String) {
        selectedCode = code
        UserDefaults.standard.set(code, forKey: "appLanguage")
        translations = [:]
        translationError = nil
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    func loadLanguages() async {
        guard !loadingLanguages else { return }
        loadingLanguages = true
        defer { loadingLanguages = false }
        let availability = LanguageAvailability()
        let supported = await availability.supportedLanguages
        var choices = [AppLanguage(code: "ko", name: "한국어")]
        for language in supported {
            let code = language.minimalIdentifier
            guard code != "ko" else { continue }
            let status = await availability.status(from: sourceLanguage, to: language)
            guard status == .installed || status == .supported else { continue }
            let name = Locale(identifier: "ko").localizedString(forIdentifier: code) ?? code
            choices.append(AppLanguage(code: code, name: name))
        }
        availableLanguages = choices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func translate(using session: TranslationSession) async {
        guard selectedCode != "ko" else { translations = [:]; return }
        isTranslating = true
        translationError = nil
        defer { isTranslating = false }
        var translated: [String: String] = [:]
        do {
            for start in stride(from: 0, to: sourceStrings.count, by: 24) {
                let batch = Array(sourceStrings[start..<min(start + 24, sourceStrings.count)])
                let requests = batch.map { TranslationSession.Request(sourceText: $0) }
                let responses = try await session.translations(from: requests)
                for (source, response) in zip(batch, responses) { translated[source] = response.targetText }
            }
            translations = translated
            NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
        } catch {
            translations = [:]
            translationError = "선택한 언어로 번역하지 못했습니다. 한국어 화면을 유지합니다."
        }
    }
}

private extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}

private struct GammaTable {
    var red: [CGGammaValue]
    var green: [CGGammaValue]
    var blue: [CGGammaValue]
}

@MainActor
private final class DisplayToneController {
    static let shared = DisplayToneController()
    private var originalTables: [CGDirectDisplayID: GammaTable] = [:]

    func apply(exposure: Double, shadowLift: Double, gamma: Double, tintStrength: Double, tintColor: Color, contrast: Double) -> Int {
        let displays = NSScreen.screens.compactMap { screen -> CGDirectDisplayID? in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
        }
        var applied = 0
        for display in displays {
            if originalTables[display] == nil {
                guard let table = readTable(for: display) else { continue }
                originalTables[display] = table
            }
            guard let source = originalTables[display] else { continue }
            let count = min(source.red.count, min(source.green.count, source.blue.count))
            guard count > 1 else { continue }
            var red = [CGGammaValue](repeating: 0, count: count)
            var green = red
            var blue = red
            let exposureGain = pow(2.0, exposure)
            let tint = (NSColor(tintColor).usingColorSpace(.deviceRGB) ?? .systemBlue)
            let tintRed = Double(tint.redComponent)
            let tintGreen = Double(tint.greenComponent)
            let tintBlue = Double(tint.blueComponent)
            let tintLuma = max(0.01, tintRed * 0.2126 + tintGreen * 0.7152 + tintBlue * 0.0722)
            for index in 0..<count {
                let r = Double(source.red[index]), g = Double(source.green[index]), b = Double(source.blue[index])
                let y = max(0, min(1, r * 0.2126 + g * 0.7152 + b * 0.0722))
                let t = min(1, max(0, y / 0.42))
                let smooth = t * t * (3 - 2 * t)
                let shadowMask = 1 - smooth
                let liftedY = y + (sqrt(y) - y) * shadowLift * shadowMask
                let scale = (y > 0.0001 ? liftedY / y : 1) * exposureGain
                var rr = max(0, r * scale), gg = max(0, g * scale), bb = max(0, b * scale)
                rr = pow(max(0, (rr - 0.5) * contrast + 0.5), 1 / max(0.1, gamma))
                gg = pow(max(0, (gg - 0.5) * contrast + 0.5), 1 / max(0.1, gamma))
                bb = pow(max(0, (bb - 0.5) * contrast + 0.5), 1 / max(0.1, gamma))
                let luma = rr * 0.2126 + gg * 0.7152 + bb * 0.0722
                let tintMask = min(1, max(0, tintStrength))
                rr = rr * (1 - tintMask) + min(1, luma * tintRed / tintLuma) * tintMask
                gg = gg * (1 - tintMask) + min(1, luma * tintGreen / tintLuma) * tintMask
                bb = bb * (1 - tintMask) + min(1, luma * tintBlue / tintLuma) * tintMask
                red[index] = CGGammaValue(min(1, rr))
                green[index] = CGGammaValue(min(1, gg))
                blue[index] = CGGammaValue(min(1, bb))
            }
            let result = red.withUnsafeBufferPointer { rp in
                green.withUnsafeBufferPointer { gp in
                    blue.withUnsafeBufferPointer { bp in
                        CGSetDisplayTransferByTable(display, UInt32(count), rp.baseAddress, gp.baseAddress, bp.baseAddress)
                    }
                }
            }
            if result == .success { applied += 1 }
        }
        return applied
    }

    func restore() {
        for (display, table) in originalTables {
            let count = min(table.red.count, min(table.green.count, table.blue.count))
            _ = table.red.withUnsafeBufferPointer { rp in
                table.green.withUnsafeBufferPointer { gp in
                    table.blue.withUnsafeBufferPointer { bp in
                        CGSetDisplayTransferByTable(display, UInt32(count), rp.baseAddress, gp.baseAddress, bp.baseAddress)
                    }
                }
            }
        }
        originalTables.removeAll()
    }

    private func readTable(for display: CGDirectDisplayID) -> GammaTable? {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 1 else { return nil }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red, blue = red
        var sampleCount: UInt32 = 0
        let result = red.withUnsafeMutableBufferPointer { rp in
            green.withUnsafeMutableBufferPointer { gp in
                blue.withUnsafeMutableBufferPointer { bp in
                    CGGetDisplayTransferByTable(display, capacity, rp.baseAddress, gp.baseAddress, bp.baseAddress, &sampleCount)
                }
            }
        }
        guard result == .success, sampleCount > 1 else { return nil }
        let count = Int(min(sampleCount, capacity))
        return GammaTable(red: Array(red.prefix(count)), green: Array(green.prefix(count)), blue: Array(blue.prefix(count)))
    }
}

enum ReticleStyle: String, CaseIterable, Identifiable {
    case cross, plus, dot, ring, ringDot, x, square, diamond, corners, tShape
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cross: "간격 십자"
        case .plus: "플러스"
        case .dot: "점"
        case .ring: "원"
        case .ringDot: "원 + 점"
        case .x: "대각선 X"
        case .square: "사각형"
        case .diamond: "다이아몬드"
        case .corners: "네 모서리"
        case .tShape: "T자"
        }
    }
}

@MainActor
final class OverlaySettings: ObservableObject {
    @Published var crosshairOn = OverlaySettings.savedBool("crosshairOn", default: true) { didSet { save(crosshairOn, key: "crosshairOn"); OverlayManager.shared.refresh() } }
    @Published var crosshairSize = OverlaySettings.savedDouble("crosshairSize", default: 12) { didSet { save(crosshairSize, key: "crosshairSize"); OverlayManager.shared.refresh() } }
    @Published var gap = OverlaySettings.savedDouble("gap", default: 3.5) { didSet { save(gap, key: "gap"); OverlayManager.shared.refresh() } }
    @Published var thickness = OverlaySettings.savedDouble("thickness", default: 1.5) { didSet { save(thickness, key: "thickness"); OverlayManager.shared.refresh() } }
    @Published var opacity = OverlaySettings.savedDouble("opacity", default: 1) { didSet { save(opacity, key: "opacity"); OverlayManager.shared.refresh() } }
    @Published var rotation = OverlaySettings.savedDouble("rotation", default: 0) { didSet { save(rotation, key: "rotation"); OverlayManager.shared.refresh() } }
    @Published var centerDotOn = OverlaySettings.savedBool("centerDotOn", default: true) { didSet { save(centerDotOn, key: "centerDotOn"); OverlayManager.shared.refresh() } }
    @Published var centerDotSize = OverlaySettings.savedDouble("centerDotSize", default: 1.4) { didSet { save(centerDotSize, key: "centerDotSize"); OverlayManager.shared.refresh() } }
    @Published var outlineOn = OverlaySettings.savedBool("outlineOn", default: true) { didSet { save(outlineOn, key: "outlineOn"); OverlayManager.shared.refresh() } }
    @Published var outlineWidth = OverlaySettings.savedDouble("outlineWidth", default: 1.6) { didSet { save(outlineWidth, key: "outlineWidth"); OverlayManager.shared.refresh() } }
    @Published var outlineColor = OverlaySettings.savedColor("outlineColor", default: .black) { didSet { save(outlineColor, key: "outlineColor"); OverlayManager.shared.refresh() } }
    @Published var glowOn = OverlaySettings.savedBool("glowOn", default: true) { didSet { save(glowOn, key: "glowOn"); OverlayManager.shared.refresh() } }
    @Published var glowStrength = OverlaySettings.savedDouble("glowStrength", default: 5) { didSet { save(glowStrength, key: "glowStrength"); OverlayManager.shared.refresh() } }
    @Published var exposure = OverlaySettings.savedDouble("exposure", default: 0.65) { didSet { save(exposure, key: "exposure"); OverlayManager.shared.updateFilterSettings() } }
    @Published var shadowLift = OverlaySettings.savedDouble("shadowLift", default: 0.92) { didSet { save(shadowLift, key: "shadowLift"); OverlayManager.shared.updateFilterSettings() } }
    @Published var gamma = OverlaySettings.savedDouble("gamma", default: 1.15) { didSet { save(gamma, key: "gamma"); OverlayManager.shared.updateFilterSettings() } }
    @Published var blueTint = OverlaySettings.savedDouble("blueTint", default: 0.28) { didSet { save(blueTint, key: "blueTint"); OverlayManager.shared.updateFilterSettings() } }
    @Published var tintColor = OverlaySettings.savedColor("tintColor", default: Color(red: 0.24, green: 0.68, blue: 1)) { didSet { save(tintColor, key: "tintColor"); OverlayManager.shared.updateFilterSettings() } }
    @Published var contrast = OverlaySettings.savedDouble("contrast", default: 1.02) { didSet { save(contrast, key: "contrast"); OverlayManager.shared.updateFilterSettings() } }
    @Published var crosshairColor = OverlaySettings.savedColor("crosshairColor", default: Color(red: 0.12, green: 0.92, blue: 1.0)) {
        didSet {
            OverlayManager.shared.refresh()
            save(crosshairColor, key: "crosshairColor")
            rememberColor(crosshairColor)
        }
    }
    @Published var reticleStyle = ReticleStyle(rawValue: UserDefaults.standard.string(forKey: "reticleStyle") ?? "cross") ?? .cross {
        didSet { UserDefaults.standard.set(reticleStyle.rawValue, forKey: "reticleStyle"); OverlayManager.shared.refresh() }
    }
    @Published private(set) var recentColorHexes: [String] = []
    @Published private(set) var favoriteColorHexes: [String] = []

    private let recentColorsKey = "recentCrosshairColors"
    private let favoriteColorsKey = "favoriteCrosshairColors"

    init() {
        recentColorHexes = UserDefaults.standard.stringArray(forKey: recentColorsKey) ?? []
        favoriteColorHexes = UserDefaults.standard.stringArray(forKey: favoriteColorsKey) ?? []
    }

    private static func savedBool(_ key: String, default fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }
    private static func savedDouble(_ key: String, default fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? fallback
    }
    private static func savedColor(_ key: String, default fallback: Color) -> Color {
        UserDefaults.standard.string(forKey: key).map(Color.init(hex:)) ?? fallback
    }
    private func save(_ value: Bool, key: String) { UserDefaults.standard.set(value, forKey: key) }
    private func save(_ value: Double, key: String) { UserDefaults.standard.set(value, forKey: key) }
    private func save(_ value: Color, key: String) {
        if let hex = value.hexString { UserDefaults.standard.set(hex, forKey: key) }
    }

    func selectColor(hex: String) { crosshairColor = Color(hex: hex) }

    func toggleFavorite(_ hex: String) {
        if favoriteColorHexes.contains(hex) {
            favoriteColorHexes.removeAll { $0 == hex }
        } else {
            favoriteColorHexes.insert(hex, at: 0)
        }
        UserDefaults.standard.set(favoriteColorHexes, forKey: favoriteColorsKey)
    }

    func isFavorite(_ hex: String) -> Bool { favoriteColorHexes.contains(hex) }

    private func rememberColor(_ color: Color) {
        guard let hex = color.hexString else { return }
        recentColorHexes.removeAll { $0 == hex }
        recentColorHexes.insert(hex, at: 0)
        recentColorHexes = Array(recentColorHexes.prefix(12))
        UserDefaults.standard.set(recentColorHexes, forKey: recentColorsKey)
    }
}

@MainActor
final class OverlayManager: ObservableObject {
    static let shared = OverlayManager()
    let settings = OverlaySettings()
    private var panels: [NSPanel] = []
    @Published private(set) var captureStatus = "화면 전체에 적용하는 암부 보정입니다."
    @Published private(set) var isCapturing = false

    func updateFilterSettings() {
        guard isCapturing else { return }
        let applied = DisplayToneController.shared.apply(
            exposure: settings.exposure,
            shadowLift: settings.shadowLift,
            gamma: settings.gamma,
            tintStrength: settings.blueTint,
            tintColor: settings.tintColor,
            contrast: settings.contrast
        )
        if applied == 0 {
            captureStatus = "이 디스플레이의 감마 조정을 적용하지 못했습니다."
        }
    }

    func toggleCapture() {
        if isCapturing {
            stopCapture()
            return
        }
        isCapturing = true
        updateFilterSettings()
        if captureStatus == "화면 전체에 적용하는 암부 보정입니다." {
            captureStatus = "암부 보정 적용 중 — 이 디스플레이의 모든 앱 화면에 적용됩니다."
        }
    }

    func stopCapture() {
        isCapturing = false
        DisplayToneController.shared.restore()
        captureStatus = "원래 디스플레이 색상으로 복원했습니다."
    }

    func refresh() {
        guard settings.crosshairOn else {
            panels.forEach { $0.close() }
            panels.removeAll()
            return
        }
        let screens = NSScreen.screens
        if panels.count != screens.count {
            panels.forEach { $0.close() }
            panels.removeAll()
        }
        if panels.isEmpty {
            for screen in screens {
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            // Apple documents canJoinAllApplications for floating windows and
            // system overlays that need to join other apps' full-screen spaces.
            panel.collectionBehavior = [.canJoinAllApplications, .canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.contentView = OverlayCanvas(
                frame: NSRect(origin: .zero, size: screen.frame.size),
                settings: settings
            )
            panel.orderFrontRegardless()
            panels.append(panel)
            }
        } else {
            for (panel, screen) in zip(panels, screens) {
                panel.setFrame(screen.frame, display: false)
                panel.contentView?.setFrameSize(screen.frame.size)
                panel.contentView?.needsDisplay = true
                panel.orderFrontRegardless()
            }
        }
    }

    func reassert() {
        if panels.isEmpty { refresh() }
        panels.forEach { $0.orderFrontRegardless() }
    }
}

@MainActor
final class OverlayAppDelegate: NSObject, NSApplicationDelegate {
    private var activationObserver: NSObjectProtocol?
    private var statusItem: NSStatusItem?
    private var languageObserver: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        languageObserver = NotificationCenter.default.addObserver(forName: .appLanguageDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureStatusItem() }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                // Reassert after Roblox enters or returns to its full-screen Space.
                OverlayManager.shared.reassert()
            }
        }
        OverlayManager.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        OverlayManager.shared.stopCapture()
    }

    private func configureStatusItem() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        let language = LanguageManager.shared
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Roblox Overlay")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: language.text("설정 열기"), action: #selector(showControls), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: language.text("화면 보정 중지"), action: #selector(stopCapture), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: language.text("앱 종료"), action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func showControls() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.title == "Roblox Overlay" })?.makeKeyAndOrderFront(nil)
    }

    @objc private func stopCapture() { OverlayManager.shared.stopCapture() }
    @objc private func quitApp() { NSApp.terminate(nil) }
    deinit {
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let languageObserver { NotificationCenter.default.removeObserver(languageObserver) }
    }
}

@MainActor
final class OverlayCanvas: NSView {
    private let settings: OverlaySettings
    init(frame: NSRect, settings: OverlaySettings) {
        self.settings = settings
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard settings.crosshairOn else { return }
        drawReticle(in: context)
    }

    private func drawReticle(in context: CGContext) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let arm = CGFloat(settings.crosshairSize)
        let gap = CGFloat(settings.gap)
        let color = settings.crosshairColor.nsColor.withAlphaComponent(settings.opacity)
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        let ringRadius = max(4, arm * 0.72)
        let ring = NSBezierPath(ovalIn: NSRect(x: -ringRadius, y: -ringRadius, width: ringRadius * 2, height: ringRadius * 2))

        switch settings.reticleStyle {
        case .cross:
            path.move(to: CGPoint(x: -arm, y: 0)); path.line(to: CGPoint(x: -gap, y: 0))
            path.move(to: CGPoint(x: gap, y: 0)); path.line(to: CGPoint(x: arm, y: 0))
            path.move(to: CGPoint(x: 0, y: -arm)); path.line(to: CGPoint(x: 0, y: -gap))
            path.move(to: CGPoint(x: 0, y: gap)); path.line(to: CGPoint(x: 0, y: arm))
        case .plus:
            path.move(to: CGPoint(x: -arm, y: 0)); path.line(to: CGPoint(x: arm, y: 0))
            path.move(to: CGPoint(x: 0, y: -arm)); path.line(to: CGPoint(x: 0, y: arm))
        case .dot:
            let radius = max(1, arm * 0.22)
            path.appendOval(in: NSRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        case .ring, .ringDot:
            path.append(ring)
        case .x:
            path.move(to: CGPoint(x: -arm, y: -arm)); path.line(to: CGPoint(x: arm, y: arm))
            path.move(to: CGPoint(x: -arm, y: arm)); path.line(to: CGPoint(x: arm, y: -arm))
        case .square:
            path.appendRect(NSRect(x: -arm * 0.72, y: -arm * 0.72, width: arm * 1.44, height: arm * 1.44))
        case .diamond:
            path.move(to: CGPoint(x: 0, y: arm)); path.line(to: CGPoint(x: arm * 0.72, y: 0))
            path.line(to: CGPoint(x: 0, y: -arm)); path.line(to: CGPoint(x: -arm * 0.72, y: 0)); path.close()
        case .corners:
            let inner = max(gap, arm * 0.42)
            for sx: CGFloat in [-1, 1] { for sy: CGFloat in [-1, 1] {
                path.move(to: CGPoint(x: sx * inner, y: sy * arm)); path.line(to: CGPoint(x: sx * inner, y: sy * inner))
                path.line(to: CGPoint(x: sx * arm, y: sy * inner))
            } }
        case .tShape:
            path.move(to: CGPoint(x: -arm, y: arm * 0.45)); path.line(to: CGPoint(x: arm, y: arm * 0.45))
            path.move(to: CGPoint(x: 0, y: arm * 0.45)); path.line(to: CGPoint(x: 0, y: -arm))
        }

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(settings.rotation * .pi / 180))
        path.lineWidth = CGFloat(settings.thickness)
        if settings.reticleStyle == .dot {
            if settings.outlineOn { settings.outlineColor.nsColor.withAlphaComponent(settings.opacity).setFill(); path.fill() }
            color.setFill(); path.fill()
        } else {
            if settings.glowOn && settings.glowStrength > 0 {
                context.setShadow(offset: .zero, blur: settings.glowStrength, color: color.withAlphaComponent(0.95).cgColor)
                color.setStroke(); path.stroke()
                context.setShadow(offset: .zero, blur: 0, color: nil)
            }
            if settings.outlineOn {
                settings.outlineColor.nsColor.withAlphaComponent(settings.opacity).setStroke()
                path.lineWidth = CGFloat(settings.thickness + settings.outlineWidth * 2)
                path.stroke()
            }
            color.setStroke(); path.lineWidth = CGFloat(settings.thickness); path.stroke()
        }
        if settings.centerDotOn && settings.reticleStyle != .dot {
            let r = CGFloat(settings.centerDotSize)
            let dot = NSBezierPath(ovalIn: NSRect(x: -r, y: -r, width: r * 2, height: r * 2))
            if settings.outlineOn {
                settings.outlineColor.nsColor.withAlphaComponent(settings.opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -(r + 1), y: -(r + 1), width: (r + 1) * 2, height: (r + 1) * 2)).fill()
            }
            color.setFill(); dot.fill()
        }
        context.restoreGState()
    }
}

extension Color {
    var nsColor: NSColor { NSColor(self) }
    var hexString: String? {
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }
        return String(format: "%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0x20EAF2
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

@main
struct RobloxOverlayApp: App {
    @NSApplicationDelegateAdaptor(OverlayAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup("Roblox Overlay") {
            ControlView(settings: OverlayManager.shared.settings, manager: OverlayManager.shared)
                .onAppear { OverlayManager.shared.refresh() }
        }
        .windowResizability(.contentSize)
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case reticle = "조준점", color = "색상과 효과", correction = "화면 보정", language = "언어"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .reticle: "scope"
        case .color: "paintpalette.fill"
        case .correction: "sun.max.fill"
        case .language: "globe"
        }
    }
}

private struct SettingsSliderRow: View {
    @ObservedObject private var language = LanguageManager.shared
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(language.text(title)).foregroundStyle(Color(hex: "B9C5D3"))
                Spacer()
                Text(valueText).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(hex: "78DCE8"))
            }.font(.system(size: 11, weight: .medium))
            Slider(value: $value, in: range).tint(Color(hex: "31C9D8"))
        }
    }
}

@MainActor
private struct ReticleCanvasPreview: NSViewRepresentable {
    let settings: OverlaySettings
    func makeNSView(context: Context) -> OverlayCanvas {
        OverlayCanvas(frame: .zero, settings: settings)
    }
    func updateNSView(_ view: OverlayCanvas, context: Context) { view.needsDisplay = true }
}

struct ControlView: View {
    @ObservedObject var settings: OverlaySettings
    @ObservedObject var manager: OverlayManager
    @State private var section: AppSection = .reticle
    @ObservedObject private var language = LanguageManager.shared
    @State private var languageSearch = ""
    @State private var translationConfiguration: TranslationSession.Configuration?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch section {
                        case .reticle: reticlePage
                        case .color: colorPage
                        case .correction: correctionPage
                        case .language: languagePage
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 1000, height: 700)
        .background(Color(hex: "0A1220"))
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await language.loadLanguages() }
            if language.selectedCode != "ko" { translationConfiguration = .init(source: Locale.Language(identifier: "ko"), target: Locale.Language(identifier: language.selectedCode)) }
        }
        .onChange(of: language.selectedCode) { _, code in
            translationConfiguration = code == "ko" ? nil : .init(source: Locale.Language(identifier: "ko"), target: Locale.Language(identifier: code))
        }
        .translationTask(translationConfiguration) { session in await language.translate(using: session) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [Color(hex: "14D9E8"), Color(hex: "376CF6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "scope").font(.system(size: 23, weight: .semibold)).foregroundStyle(.white)
                }.frame(width: 44, height: 44).shadow(color: .cyan.opacity(0.22), radius: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ROBLOX").font(.system(size: 12, weight: .black, design: .rounded)).tracking(1.1)
                    Text("OVERLAY CONTROL").font(.system(size: 8, weight: .bold)).tracking(1.2).foregroundStyle(Color(hex: "8296AF"))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(L("설정")).font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(Color(hex: "73849E"))
                ForEach(AppSection.allCases) { item in
                    Button { section = item } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.symbol).frame(width: 18)
                            Text(L(item.rawValue))
                            Spacer()
                            if section == item { Circle().fill(Color(hex: "42DDED")).frame(width: 6, height: 6) }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(section == item ? .white : Color(hex: "A8B5C8"))
                        .padding(.horizontal, 11).padding(.vertical, 10)
                        .background(section == item ? Color(hex: "1B2D42") : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle().fill(settings.crosshairOn ? Color(hex: "4AE0AE") : Color(hex: "8794A8")).frame(width: 7, height: 7)
                    Text(L(settings.crosshairOn ? "조준점 표시 중" : "조준점 숨김")).font(.system(size: 10, weight: .semibold))
                }.foregroundStyle(Color(hex: "C0CDDD"))
                Text(L("설정은 자동 저장됩니다")).font(.system(size: 10)).foregroundStyle(Color(hex: "71839B"))
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "111E2D"), in: RoundedRectangle(cornerRadius: 11))
        }
        .padding(18).frame(width: 212, alignment: .leading)
        .background(Color(hex: "0D1827"))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1) }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L(section.rawValue)).font(.system(size: 18, weight: .bold, design: .rounded))
                Text(L("Roblox Overlay · 설정은 자동 저장됩니다")).font(.system(size: 10)).foregroundStyle(Color(hex: "8393A8"))
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(manager.isCapturing ? Color(hex: "4AE0AE") : Color(hex: "8794A8")).frame(width: 7, height: 7)
                Text(L(manager.isCapturing ? "보정 켜짐" : "보정 꺼짐")).font(.system(size: 10, weight: .semibold))
            }.foregroundStyle(Color(hex: "C0CDDD")).padding(.horizontal, 10).padding(.vertical, 7).background(Color(hex: "132234"), in: Capsule())
            Toggle(L("조준점"), isOn: $settings.crosshairOn).labelsHidden().tint(Color(hex: "31C9D8"))
            Button { manager.stopCapture(); NSApp.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "AAB9CC"))
            }.buttonStyle(.plain).help("앱 종료")
        }
        .padding(.horizontal, 26).padding(.vertical, 15)
        .background(Color(hex: "0B1523").opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }

    private var reticlePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color(hex: "0D1725")).overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 1))
                    Circle().stroke(Color(hex: "25DCEA").opacity(0.15), lineWidth: 1).padding(20)
                    ReticleCanvasPreview(settings: settings).padding(25)
                }.frame(width: 132, height: 132)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("실제 모양 미리보기")).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(Color(hex: "67D9E6"))
                    Text(L("화면 중앙 조준점의 모양과 정밀도를 설정합니다.")).font(.system(size: 12)).foregroundStyle(Color(hex: "AEBBD0"))
                }
                Spacer()
            }.padding(16).appCard()
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 13) {
                    cardTitle(L("모양과 배치"), icon: "scope")
                    Picker(L("모양"), selection: $settings.reticleStyle) { ForEach(ReticleStyle.allCases) { style in Text(L(style.title)).tag(style) } }
                    SettingsSliderRow(title: "크기", value: $settings.crosshairSize, range: 4...48, valueText: "\(Int(settings.crosshairSize)) px")
                    SettingsSliderRow(title: "중앙 간격", value: $settings.gap, range: 0...18, valueText: String(format: "%.1f px", settings.gap))
                    SettingsSliderRow(title: "회전", value: $settings.rotation, range: 0...360, valueText: "\(Int(settings.rotation))°")
                    Toggle(L("중앙 점 표시"), isOn: $settings.centerDotOn).tint(.cyan)
                    if settings.centerDotOn { SettingsSliderRow(title: "중앙 점 크기", value: $settings.centerDotSize, range: 0.5...8, valueText: String(format: "%.1f px", settings.centerDotSize)) }
                }.padding(17).frame(maxWidth: .infinity, alignment: .leading).appCard()
                VStack(alignment: .leading, spacing: 13) {
                    cardTitle(L("선과 효과"), icon: "slider.horizontal.3")
                    SettingsSliderRow(title: "선 두께", value: $settings.thickness, range: 0.5...8, valueText: String(format: "%.1f px", settings.thickness))
                    SettingsSliderRow(title: "불투명도", value: $settings.opacity, range: 0.1...1, valueText: "\(Int(settings.opacity * 100))%")
                    Toggle(L("대비 외곽선"), isOn: $settings.outlineOn).tint(.cyan)
                    if settings.outlineOn {
                        ColorPicker(L("외곽선 색"), selection: $settings.outlineColor, supportsOpacity: false)
                        SettingsSliderRow(title: "외곽선 두께", value: $settings.outlineWidth, range: 0.5...6, valueText: String(format: "%.1f px", settings.outlineWidth))
                    }
                    Toggle(L("네온 빛 번짐"), isOn: $settings.glowOn).tint(.cyan)
                    if settings.glowOn { SettingsSliderRow(title: "번짐 강도", value: $settings.glowStrength, range: 0...16, valueText: "\(Int(settings.glowStrength))") }
                    Button(L("조준점 초기화")) { settings.resetReticle() }.buttonStyle(.bordered).tint(.white.opacity(0.3))
                }.padding(17).frame(maxWidth: .infinity, alignment: .leading).appCard()
            }
        }
    }

    private var colorPage: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle(L("조준점 색상"), icon: "paintpalette.fill")
                ColorPicker(L("사용자 지정 색상"), selection: $settings.crosshairColor, supportsOpacity: false)
                colorShelf(title: "즐겨찾기", colors: settings.favoriteColorHexes)
                colorShelf(title: "최근 사용", colors: settings.recentColorHexes)
                HStack(spacing: 9) {
                    ForEach(["29E7F2", "3478F6", "A077FF", "FF5F9E", "FF624A", "5BDB89", "FFD34D", "FFFFFF"], id: \.self) { hex in
                        Button { settings.selectColor(hex: hex) } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 25, height: 25).overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain).help("#\(hex)")
                    }
                }
                HStack {
                    Text(L("현재 색을 즐겨찾기에 보관")).font(.system(size: 11)).foregroundStyle(Color(hex: "AAB8C9"))
                    Spacer()
                    Button(L(settings.isFavorite(settings.crosshairColor.hexString ?? "") ? "저장됨 ★" : "즐겨찾기 ☆")) {
                        if let hex = settings.crosshairColor.hexString { settings.toggleFavorite(hex) }
                    }.buttonStyle(.bordered).tint(.cyan)
                }
                SettingsSliderRow(title: "조준점 투명도", value: $settings.opacity, range: 0.1...1, valueText: "\(Int(settings.opacity * 100))%")
            }.padding(19).appCard()
            VStack(alignment: .leading, spacing: 13) {
                cardTitle(L("화면 색조"), icon: "circle.lefthalf.filled")
                ColorPicker(L("어두운 부분에 적용할 색"), selection: $settings.tintColor, supportsOpacity: false)
                HStack(spacing: 8) {
                    Circle().fill(settings.tintColor).frame(width: 13, height: 13)
                    Text(settings.tintColor.hexString.map { "#\($0)" } ?? "사용자 지정 색상").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(hex: "AAB8C9"))
                }
                SettingsSliderRow(title: "색조 강도", value: $settings.blueTint, range: 0...1, valueText: "\(Int(settings.blueTint * 100))%")
                Text(L("선택한 색조는 화면 보정을 켰을 때 적용됩니다.")).font(.system(size: 10)).foregroundStyle(Color(hex: "8295AC"))
            }.padding(19).appCard()
        }
    }

    private var correctionPage: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 13) {
                Image(systemName: "sun.max.fill").font(.system(size: 23)).foregroundStyle(Color(hex: "73E5ED"))
                    .frame(width: 48, height: 48).background(Color(hex: "143244"), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("화면 톤")).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(Color(hex: "6EDDE8"))
                    Text("감마 곡선으로 어두운 영역을 들어 올립니다.").font(.system(size: 12)).foregroundStyle(Color(hex: "B5C1D0"))
                }
                Spacer()
                Button(manager.isCapturing ? "보정 중지" : "보정 시작") { manager.toggleCapture() }
                    .buttonStyle(.borderedProminent).tint(Color(hex: "19B9CB"))
            }.padding(17).appCard()
            VStack(alignment: .leading, spacing: 15) {
                cardTitle(L("화면 조정"), icon: "slider.horizontal.3")
                SettingsSliderRow(title: "노출", value: $settings.exposure, range: -1...2, valueText: String(format: "%.1f EV", settings.exposure))
                SettingsSliderRow(title: "암부 들어 올리기", value: $settings.shadowLift, range: 0...1, valueText: "\(Int(settings.shadowLift * 100))%")
                SettingsSliderRow(title: "감마", value: $settings.gamma, range: 0.6...1.6, valueText: String(format: "%.2f", settings.gamma))
                SettingsSliderRow(title: "대비", value: $settings.contrast, range: 0.75...1.4, valueText: String(format: "%.2f", settings.contrast))
                ColorPicker(L("색조 색상"), selection: $settings.tintColor, supportsOpacity: false)
                SettingsSliderRow(title: "색조 강도", value: $settings.blueTint, range: 0...1, valueText: "\(Int(settings.blueTint * 100))%")
                Button(L("어두운 맵 추천값 적용")) { settings.applyDarkMapPreset() }.buttonStyle(.bordered).tint(.cyan)
            }.padding(19).appCard()
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(Color(hex: "65D8E4"))
                Text(L("보정은 Roblox 창 위에 검은 화면을 덮지 않고, 디스플레이 전체의 모든 앱에 적용됩니다.")).font(.system(size: 10)).foregroundStyle(Color(hex: "A5B3C6"))
            }.padding(13).appCard()
            Text(L(manager.captureStatus)).font(.system(size: 10)).foregroundStyle(Color(hex: "8496AC"))
        }
    }

    private func L(_ source: String) -> String { language.text(source) }

    private var languagePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L("앱 언어")).font(.system(size: 19, weight: .bold, design: .rounded))
                Text(L("이 Mac에서 사용할 수 있는 번역 언어를 검색하고 선택하세요.")).font(.system(size: 11)).foregroundStyle(Color(hex: "AAB8C9"))
            }
            TextField(L("언어 검색"), text: $languageSearch).textFieldStyle(.roundedBorder)
            if language.loadingLanguages { ProgressView(L("언어 목록을 불러오는 중…")) }
            if language.isTranslating { ProgressView(L("번역 준비 중…")) }
            if let error = language.translationError { Text(L(error)).foregroundStyle(Color(hex: "FF9B9B")) }
            Text(L("지원되는 언어만 표시됩니다. 언어별 모델 다운로드가 필요할 수 있습니다.")).font(.system(size: 10)).foregroundStyle(Color(hex: "8496AC"))
            LazyVStack(spacing: 5) {
                ForEach(language.availableLanguages.filter { languageSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(languageSearch) || $0.code.localizedCaseInsensitiveContains(languageSearch) }) { item in
                    Button { language.select(item.code) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.code == language.selectedCode ? "checkmark.circle.fill" : "circle").foregroundStyle(item.code == language.selectedCode ? Color(hex: "42DDED") : Color(hex: "62748A"))
                            Text(item.code == "ko" ? L("한국어 (기본)") : item.name).foregroundStyle(.white)
                            Spacer()
                            Text(item.code).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(hex: "8294AA"))
                        }.padding(11).background(Color(hex: item.code == language.selectedCode ? "1B2D42" : "101B2B"), in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(18).appCard()
    }

    private func cardTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
    }

    @ViewBuilder private func colorShelf(title: String, colors: [String]) -> some View {
        if !colors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: "8294AA"))
                HStack(spacing: 9) {
                    ForEach(colors, id: \.self) { hex in
                        Button { settings.selectColor(hex: hex) } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 25, height: 25)
                                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                                .overlay(settings.crosshairColor.hexString == hex ? Circle().stroke(.white, lineWidth: 2).padding(3) : nil)
                        }.buttonStyle(.plain).help("#\(hex)")
                    }
                }
            }
        }
    }
}

private extension View {
    func appCard() -> some View {
        background(LinearGradient(colors: [Color(hex: "142236"), Color(hex: "101B2B")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

extension OverlaySettings {
    func resetReticle() {
        reticleStyle = .cross
        crosshairSize = 12
        gap = 3.5
        thickness = 1.5
        opacity = 1
        rotation = 0
        centerDotOn = true
        centerDotSize = 1.4
        outlineOn = true
        outlineWidth = 1.6
        outlineColor = .black
        glowOn = true
        glowStrength = 5
        crosshairColor = Color(red: 0.12, green: 0.92, blue: 1.0)
    }

    func applyDarkMapPreset() {
        exposure = 0.65
        shadowLift = 0.92
        gamma = 1.15
        blueTint = 0.28
        contrast = 1.02
        tintColor = Color(red: 0.24, green: 0.68, blue: 1)
    }
}
