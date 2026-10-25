import SwiftUI
#if canImport(WebKit)
import WebKit
#endif
#if SWIFT_PACKAGE
import CaptureCore
#endif
#if canImport(SceneKit) && canImport(UIKit)
import SceneKit
import UIKit
#if canImport(Vision)
import Vision
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(ARKit)
import ARKit
#endif
#endif

@main
struct CaptureDemoApp: App {
    var body: some Scene {
        WindowGroup { CaptureChecklistView() }
    }
}

@MainActor
struct CaptureChecklistView: View {
    @StateObject private var model = CapturePresentationModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.screen {
                case .start:
                    VStack(spacing: 20) {
                        Text("Toyota Next Move").font(.largeTitle.bold()).minimumScaleFactor(0.8)
                        Text("Guided exterior and interior capture").multilineTextAlignment(.center)
                        Button("Start scan") { model.startScan() }.buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("start-scan")
                            .accessibilityLabel("Start a guided scan")
                        Button("Run synthetic replay") { model.runReplay() }.buttonStyle(.bordered)
                            .accessibilityIdentifier("run-replay")
                            .accessibilityLabel("Run synthetic replay demo")
                        Text("Synthetic replay is the safe fallback when camera access is unavailable.")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding()
                case .guided:
                    GuidedCaptureView(model: model)
                        .safeAreaInset(edge: .bottom) {
                            VStack { Button(model.coveredCount >= 4 ? "Finish scan" : "Finish with missing coverage") { model.finishScan() }.buttonStyle(.borderedProminent)
                                .disabled(model.coveredCount == 0)
                                if !model.cameraAvailable { Button("Use synthetic replay") { model.useReplayFallback(); model.showReplay() }.buttonStyle(.bordered).font(.footnote) } }.padding()
                                .accessibilityIdentifier("guided-replay")
                                .accessibilityLabel("Use synthetic replay because camera capture is unavailable")
                        }
                case .replay:
                    ProgressView("Loading replay…").task { model.runReplay() }
                case .results:
                    ResultsView(model: model)
                }
            }
            .navigationTitle("Toyota Next Move")
        }
    }
}


private struct GuidedCaptureView: View {
    @ObservedObject var model: CapturePresentationModel
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
#if canImport(ARKit) && canImport(UIKit)
                if model.cameraAvailable && model.arPoseAvailable {
                    ARCameraScannerView(model: model)
                        .ignoresSafeArea()
                } else if model.cameraAvailable {
#if canImport(AVFoundation)
                    LiveCapturePreview(session: model.activeCaptureSession)
                        .ignoresSafeArea()
#else
                    Color.black.ignoresSafeArea()
#endif
                } else {
                    Color(red: 0.025, green: 0.055, blue: 0.12).ignoresSafeArea()
                }
#else
                Color(red: 0.025, green: 0.055, blue: 0.12).ignoresSafeArea()
#endif
                LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                    .ignoresSafeArea(edges: .top)
                VStack(spacing: 12) {
                    HStack {
                        Button { model.cancelScan() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Cancel scan")
                        Spacer()
                        Button { model.finishScan() } label: { Image(systemName: "checkmark") }
                            .disabled(model.coveredCount == 0)
                            .accessibilityLabel(model.coveredCount == 0 ? "Finish unavailable until a view is captured" : "Finish scan")
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    GuidancePill(message: model.scanMessage)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                VStack(spacing: 12) {
                    Spacer()
                    VehicleCoverageMap(progress: model.progress, compact: true)
                        .frame(height: min(180, proxy.size.height * 0.22))
                        .padding(.horizontal, 28)
                        .accessibilityLabel("3D vehicle progress indicator")
                    HStack {
                        Button { model.togglePause() } label: { Image(systemName: model.isPaused ? "play.fill" : "pause.fill") }
                            .accessibilityLabel(model.isPaused ? "Resume scan" : "Pause scan")
                        Button { model.retakeCurrent() } label: { Image(systemName: "arrow.counterclockwise") }
                            .accessibilityLabel("Retake current view")
                        Button { model.skipCurrent() } label: { Image(systemName: "forward.end.fill") }
                            .accessibilityLabel("Skip current view")
                        if !model.cameraAvailable {
                            Button { model.useReplayFallback(); model.showReplay() } label: { Image(systemName: "film") }
                                .accessibilityLabel("Use video replay")
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.subheadline)
                    .padding(.bottom, 12)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

private struct GuidancePill: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles").accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live guidance")
        .accessibilityValue(message)
    }
}

#if canImport(ARKit) && canImport(UIKit)
private extension Notification.Name { static let resetARCalibration = Notification.Name("resetARCalibration") }

private final class VehiclePulseOverlay: UIView {
    private let fill = CAGradientLayer()
    private let glow = CAGradientLayer()
    private let fillMask = CALayer()
    private let glowMask = CALayer()
    private let sweepContainer = CALayer()
    private let sweepMask = CALayer()
    private let sweep = CAGradientLayer()
    private var isAnimating = false
    private let context = CIContext()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        isUserInteractionEnabled = false
        layer.addSublayer(glow); layer.addSublayer(fill); layer.addSublayer(sweepContainer)
        sweepContainer.addSublayer(sweep)
        fill.colors = [UIColor.white.withAlphaComponent(0.18).cgColor, UIColor.lightGray.withAlphaComponent(0.04).cgColor, UIColor.white.withAlphaComponent(0.12).cgColor]
        fill.startPoint = CGPoint(x: 0, y: 0); fill.endPoint = CGPoint(x: 1, y: 1); fill.cornerRadius = 18; fill.masksToBounds = true
        glow.colors = [UIColor.white.withAlphaComponent(0.24).cgColor, UIColor.clear.cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0); glow.endPoint = CGPoint(x: 0.5, y: 1); glow.opacity = 0.9
        sweep.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.8).cgColor, UIColor.clear.cgColor]
        sweep.startPoint = CGPoint(x: 0.5, y: 0); sweep.endPoint = CGPoint(x: 0.5, y: 1); sweep.cornerRadius = 4
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(maskPixelBuffer: CVPixelBuffer, in bounds: CGRect) {
        guard let mask = VehiclePulseMask.image(from: maskPixelBuffer, context: context), bounds.width > 0, bounds.height > 0 else { hide(); return }
        frame = bounds
        fillMask.contents = mask; glowMask.contents = mask; sweepMask.contents = mask
        isHidden = false
        setNeedsLayout()
        if !isAnimating { startAnimations() }
    }

    func hide() {
        isHidden = true
        layer.removeAllAnimations()
        sweepContainer.removeAllAnimations()
        sweep.removeAllAnimations()
        isAnimating = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = bounds; glow.frame = bounds
        fill.mask = fillMask; glow.mask = glowMask
        fillMask.frame = bounds; glowMask.frame = bounds
        fillMask.contentsGravity = .resizeAspectFill; glowMask.contentsGravity = .resizeAspectFill
        sweepContainer.frame = bounds
        sweepContainer.mask = sweepMask
        sweepMask.frame = bounds
        sweepMask.contentsGravity = .resizeAspectFill
        sweep.frame = CGRect(x: 0, y: -bounds.height, width: bounds.width, height: bounds.height * 2)
    }

    private func startAnimations() {
        isAnimating = true
        let pulse = CABasicAnimation(keyPath: "opacity"); pulse.fromValue = 0.38; pulse.toValue = 0.95; pulse.duration = 0.72; pulse.autoreverses = true; pulse.repeatCount = .greatestFiniteMagnitude
        glow.add(pulse, forKey: "vehicle-pulse")
        let scan = CABasicAnimation(keyPath: "position.y"); scan.fromValue = -bounds.height * 0.5; scan.toValue = bounds.height * 1.5; scan.duration = 1.15; scan.repeatCount = .greatestFiniteMagnitude
        sweep.add(scan, forKey: "scan-sweep")
    }
}

private struct ARCameraScannerView: UIViewRepresentable {
    @ObservedObject var model: CapturePresentationModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(); view.scene = SCNScene(); view.automaticallyUpdatesLighting = true; view.backgroundColor = .black; view.debugOptions = []
        context.coordinator.sceneView = view
        context.coordinator.attachPulseOverlay()
        let config = ARWorldTrackingConfiguration(); view.session.delegate = context.coordinator; view.session.run(config)
        context.coordinator.installResetObserver(configuration: config)
        return view
    }
    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.sceneView = view
        context.coordinator.attachPulseOverlay()
    }
    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) { coordinator.teardown() }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var model: CapturePresentationModel?
        weak var sceneView: ARSCNView?
        private let pulseOverlay = VehiclePulseOverlay()
        private var resetObserver: NSObjectProtocol?
        private var configuration: ARWorldTrackingConfiguration?
        init(model: CapturePresentationModel) { self.model = model }

        func installResetObserver(configuration: ARWorldTrackingConfiguration) {
            self.configuration = configuration
            resetObserver = NotificationCenter.default.addObserver(forName: .resetARCalibration, object: nil, queue: .main) { [weak self] _ in
                self?.sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            }
        }

        @MainActor
        func attachPulseOverlay() {
            guard let sceneView else { return }
            if pulseOverlay.superview !== sceneView {
                sceneView.addSubview(pulseOverlay)
                pulseOverlay.frame = .zero
            }
        }

        func teardown() {
            if let resetObserver {
                NotificationCenter.default.removeObserver(resetObserver)
                self.resetObserver = nil
            }
            pulseOverlay.hide()
            pulseOverlay.removeFromSuperview()
            sceneView?.session.pause()
            configuration = nil
            sceneView = nil
        }

        func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor [weak self] in
                self?.pulseOverlay.hide()
                self?.model?.handleARSessionInterruption()
            }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor [weak self] in
                guard let self, let configuration = self.configuration else { return }
                session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                self.pulseOverlay.hide()
                self.model?.handleARSessionInterruptionEnded()
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor [weak self] in
                self?.pulseOverlay.hide()
                self?.model?.handleARSessionFailure()
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let pixelBuffer = frame.capturedImage
            let timestamp = frame.timestamp
            Task { @MainActor [weak self] in
                self?.attachPulseOverlay()
                self?.model?.consumeARFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
            }
            guard timestamp - lastRectangleTimestamp > 0.2 else { return }
            lastRectangleTimestamp = timestamp
            detectVehicleMask(in: pixelBuffer)
        }

        private var lastRectangleTimestamp = -Double.infinity

        private func detectVehicleMask(in pixelBuffer: CVPixelBuffer) {
            #if canImport(Vision)
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
            DispatchQueue.global(qos: .userInitiated).async(execute: DispatchWorkItem {
                do {
                    try handler.perform([request])
                    guard let observation = request.results?.first else {
                        Task { @MainActor [weak self] in self?.pulseOverlay.hide() }
                        return
                    }
                    let instance = Self.largestCentralInstance(in: observation)
                    let mask = try observation.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler)
                    Task { @MainActor [weak self] in
                        guard let self, let sceneView = self.sceneView else { return }
                        guard self.model?.vehicleMatchStatus == "Vehicle visible" else {
                            self.pulseOverlay.hide()
                            return
                        }
                        self.pulseOverlay.show(maskPixelBuffer: mask, in: sceneView.bounds)
                    }
                } catch {
                    Task { @MainActor [weak self] in self?.pulseOverlay.hide() }
                }
            })
            #endif
        }

        #if canImport(Vision)
        private static func largestCentralInstance(in observation: VNInstanceMaskObservation) -> Int {
            let mask = observation.instanceMask
            CVPixelBufferLockBaseAddress(mask, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
            guard let base = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self) else { return observation.allInstances.first ?? 1 }
            let width = CVPixelBufferGetWidth(mask); let height = CVPixelBufferGetHeight(mask); let stride = CVPixelBufferGetBytesPerRow(mask)
            var counts: [Int: Int] = [:]; var sums: [Int: (x: Int, y: Int)] = [:]
            for y in 0..<height {
                for x in 0..<width {
                    let label = Int(base[y * stride + x]); guard label > 0 else { continue }
                    counts[label, default: 0] += 1; sums[label, default: (0, 0)].x += x; sums[label, default: (0, 0)].y += y
                }
            }
            let centerX = Double(width) / 2; let centerY = Double(height) / 2
            return counts.max { lhs, rhs in
                func score(_ item: (key: Int, value: Int)) -> Double {
                    let centroid = sums[item.key]!; let x = Double(centroid.x) / Double(item.value); let y = Double(centroid.y) / Double(item.value)
                    let distance = hypot((x - centerX) / centerX, (y - centerY) / centerY)
                    return Double(item.value) * max(0.2, 1.0 - distance * 0.45)
                }
                return score(lhs) < score(rhs)
            }?.key ?? observation.allInstances.first ?? 1
        }
        #endif

    }
}
#endif

#if canImport(AVFoundation) && canImport(UIKit)
private struct LiveCapturePreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
#endif

private struct VehicleCoverageMap: View {
    let progress: CaptureProgress
    var findings: [PresentationFinding] = []
    var compact = false
    @State private var baseRotation: Double = 0
    @State private var dragRotation: Double = 0
    var body: some View {
#if canImport(SceneKit) && canImport(UIKit)
        VStack(spacing: 4) {
            Group {
#if canImport(WebKit)
                VehicleGLBView(progress: progress, compact: compact).frame(maxWidth: .infinity)
#else
                SceneKitVehicleView(progress: progress, findings: findings)
#endif
            }
                .rotation3DEffect(.degrees(baseRotation + dragRotation), axis: (x: 0, y: 1, z: 0))
                .simultaneousGesture(DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragRotation = Double(value.translation.width) * 0.42
                    }
                    .onEnded { value in
                        baseRotation += Double(value.translation.width) * 0.42
                        dragRotation = 0
                    })
            if !compact {
                Text("Drag to rotate").font(.caption2).foregroundStyle(.white.opacity(0.62))
            }
        }
#else
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 55).fill(Color.gray.opacity(0.34)).overlay(RoundedRectangle(cornerRadius: 55).stroke(Color.white.opacity(0.35), lineWidth: 2)).rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0))
                RoundedRectangle(cornerRadius: 30).fill(Color.gray.opacity(0.2)).frame(width: proxy.size.width * 0.34, height: proxy.size.height * 0.62)
                if !compact {
                    ForEach(CaptureRegion.allCases, id: \.self) { region in
                        let position = mapPosition(region, in: proxy.size)
                        Text(label(for: region)).font(.caption2.bold()).foregroundStyle(.white).padding(6)
                            .background(color(for: progress[region])).clipShape(Capsule()).position(position)
                            .accessibilityLabel("\(region.rawValue): \(progress[region].rawValue)")
                    }
                }
            }.padding(32)
        }
#endif
    }
    private func label(for region: CaptureRegion) -> String { region.rawValue.replacingOccurrences(of: "interior-", with: "int ").capitalized }
    private func color(for state: CoverageState) -> Color { switch state { case .covered: .green; case .partial: .orange; case .blocked: .red; case .unseen: Color.gray.opacity(0.65) } }
    private func mapPosition(_ region: CaptureRegion, in size: CGSize) -> CGPoint {
        let points: [CaptureRegion: CGPoint] = [.front: CGPoint(x: size.width/2, y: 18), .frontLeft: CGPoint(x: size.width*0.24, y: 45), .left: CGPoint(x: size.width*0.12, y: size.height/2), .rearLeft: CGPoint(x: size.width*0.24, y: size.height-45), .rear: CGPoint(x: size.width/2, y: size.height-18), .rearRight: CGPoint(x: size.width*0.76, y: size.height-45), .right: CGPoint(x: size.width*0.88, y: size.height/2), .frontRight: CGPoint(x: size.width*0.76, y: 45), .roof: CGPoint(x: size.width/2, y: size.height/2), .interiorFront: CGPoint(x: size.width*0.42, y: size.height*0.38), .interiorRear: CGPoint(x: size.width*0.58, y: size.height*0.62), .trunk: CGPoint(x: size.width/2, y: size.height*0.82)]
        return points[region] ?? CGPoint(x: size.width/2, y: size.height/2)
    }
}

#if canImport(SceneKit) && canImport(UIKit)
private struct SceneKitVehicleView: UIViewRepresentable {
    let progress: CaptureProgress
    let findings: [PresentationFinding]
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(); view.scene = makeScene(); view.pointOfView = view.scene?.rootNode.childNodes.first(where: { $0.camera != nil }); view.allowsCameraControl = false; view.backgroundColor = UIColor(red: 0.025, green: 0.055, blue: 0.12, alpha: 1); view.accessibilityLabel = "Three dimensional vehicle coverage map"
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) { view.scene = makeScene() }
    private func makeScene() -> SCNScene {
        let scene = SCNScene(); scene.background.contents = UIColor(red: 0.025, green: 0.055, blue: 0.12, alpha: 1)
        let root = scene.rootNode
        let body = SCNNode(geometry: SCNBox(width: 3.8, height: 0.65, length: 7.0, chamferRadius: 0.35)); body.geometry?.materials = [material(.gray, state: aggregate(.front, .rear, .left, .right))]; root.addChildNode(body)
        let cabin = SCNNode(geometry: SCNBox(width: 3.05, height: 0.85, length: 3.25, chamferRadius: 0.3)); cabin.position.y = 0.68; cabin.geometry?.materials = [material(.blue, state: aggregate(.roof, .interiorFront, .interiorRear))]; root.addChildNode(cabin)
        for x in [-1.72, 1.72] { for z in [-2.35, 2.35] { let wheel = SCNNode(geometry: SCNCylinder(radius: 0.48, height: 0.28)); wheel.eulerAngles.z = .pi / 2; wheel.position = SCNVector3(x, -0.28, z); wheel.geometry?.materials = [material(.black, state: aggregate(z > 0 ? .front : .rear, x < 0 ? .left : .right))]; root.addChildNode(wheel) } }
        for z in [-3.48, 3.48] { let light = SCNNode(geometry: SCNBox(width: 2.2, height: 0.14, length: 0.12, chamferRadius: 0.04)); light.position = SCNVector3(0, 0.04, z); light.geometry?.materials = [material(.yellow, state: progress[z > 0 ? .front : .rear])]; root.addChildNode(light) }
        for region in [CaptureRegion.frontLeft, .frontRight, .rearLeft, .rearRight] { let marker = SCNNode(geometry: SCNSphere(radius: 0.12)); marker.position = markerPosition(region); marker.geometry?.materials = [material(.red, state: progress[region])]; marker.isHidden = progress[region] == .covered || progress[region] == .unseen; root.addChildNode(marker) }
        if findings.contains(where: { $0.region == "rear" }) { let marker = SCNNode(geometry: SCNSphere(radius: 0.18)); marker.position = SCNVector3(0, 0.45, -3.5); marker.geometry?.materials = [material(.red, state: .partial)]; root.addChildNode(marker) }
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.fieldOfView = 48; camera.position = SCNVector3(7, 5.2, 9); camera.look(at: SCNVector3(0, 0.2, 0)); root.addChildNode(camera)
        let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni; light.light?.intensity = 900; light.position = SCNVector3(4, 7, 5); root.addChildNode(light)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.color = UIColor(white: 0.35, alpha: 1); root.addChildNode(ambient)
        return scene
    }
    private func aggregate(_ regions: CaptureRegion...) -> CoverageState { regions.contains(where: { progress[$0] == .partial }) ? .partial : (regions.allSatisfy { progress[$0] == .covered } ? .covered : .unseen) }
    private func markerPosition(_ region: CaptureRegion) -> SCNVector3 { switch region { case .frontLeft: return SCNVector3(-1.9, 0.2, 2.8); case .frontRight: return SCNVector3(1.9, 0.2, 2.8); case .rearLeft: return SCNVector3(-1.9, 0.2, -2.8); case .rearRight: return SCNVector3(1.9, 0.2, -2.8); default: return SCNVector3Zero } }
    private func material(_ color: UIColor, state: CoverageState) -> SCNMaterial { let m = SCNMaterial(); m.diffuse.contents = state == .covered ? color : (state == .partial ? UIColor.orange : UIColor(white: 0.38, alpha: 1)); m.lightingModel = .physicallyBased; return m }
}
#endif

#if canImport(WebKit) && canImport(UIKit)
private final class VehicleViewerSchemeHandler: NSObject, WKURLSchemeHandler {
    private let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = fileURL(for: requestURL),
              let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle viewer resource was not found."]))
            return
        }

        let response = URLResponse(url: requestURL, mimeType: Self.mimeType(for: fileURL),
            expectedContentLength: data.count, textEncodingName: Self.textEncodingName(for: fileURL))
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func fileURL(for requestURL: URL) -> URL? {
        guard requestURL.host == "bundle" else { return nil }
        let path = requestURL.path.removingPercentEncoding ?? requestURL.path
        guard path.hasPrefix("/"), !path.contains("\0") else { return nil }
        let components = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ $0 != "." && $0 != ".." && !$0.contains("\\") }) else { return nil }

        let candidate = components.reduce(rootURL) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }.standardizedFileURL
        let rootPath = rootURL.path
        let isDirectory = (try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? true
        guard candidate.path == rootPath || candidate.path.hasPrefix(rootPath + "/"),
              FileManager.default.fileExists(atPath: candidate.path),
              !isDirectory else { return nil }
        return candidate
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "glb": return "model/gltf-binary"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        default: return "application/octet-stream"
        }
    }

    private static func textEncodingName(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "html", "js", "mjs", "css", "json", "svg": return "utf-8"
        default: return nil
        }
    }
}

/// Loads the authored Blender GLB through the bundled WebGL material viewer.
/// This keeps the exact mesh/material reveal authored in Vision assets instead
/// of substituting the old rounded-box SceneKit placeholder.
private struct VehicleGLBView: UIViewRepresentable {
    let progress: CaptureProgress
    let compact: Bool

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "VehicleViewer") else {
            return WKWebView(frame: .zero, configuration: configuration)
        }
        configuration.setURLSchemeHandler(VehicleViewerSchemeHandler(rootURL: indexURL.deletingLastPathComponent()), forURLScheme: "toyota-viewer")
        if compact {
            let script = WKUserScript(source: "const s=document.createElement('style');s.textContent='header,.controls,#state,footer,#anchor,#loading,#error{display:none!important}';document.documentElement.appendChild(s);", injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            configuration.userContentController.addUserScript(script)
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.load(URLRequest(url: URL(string: "toyota-viewer://bundle/index.html")!))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let covered = progress.coverage.values.filter { $0 == .covered }.count
        let ratio = Double(covered) / Double(max(1, CaptureRegion.allCases.count))
        view.evaluateJavaScript("window.vehicleStudy && window.vehicleStudy.setProgress(\(ratio));", completionHandler: nil)
    }
}
#endif

private struct ResultsView: View {
    @ObservedObject var model: CapturePresentationModel
    @State private var leaseChoice = "Leased"
    @State private var incomeChoice = "$50–100k"
    @State private var accidentChoice = "None"
    @State private var mileage = ""
    @State private var showSheet = false
    @State private var showRecommendation = false
    @FocusState private var mileageFocused: Bool

    private let ink = Color(red: 0.06, green: 0.07, blue: 0.08)
    private let warm = Color(red: 0.91, green: 0.68, blue: 0.32)

    var body: some View {
        ZStack(alignment: .bottom) {
            ink.ignoresSafeArea()
            RadialGradient(colors: [Color(red: 0.16, green: 0.19, blue: 0.23).opacity(0.8), ink], center: .center, startRadius: 40, endRadius: 520)
                .ignoresSafeArea()
                .opacity(showSheet ? 0.72 : 0.48)
            PostScanVehicleHero(progress: model.progress)
                .ignoresSafeArea()
                .scaleEffect(showSheet ? 1 : 0.84)
                .opacity(showSheet ? 1 : 0)
                .animation(.easeOut(duration: 0.72), value: showSheet)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NEXT MOVE").font(.caption2.weight(.semibold)).tracking(2.2).foregroundStyle(warm)
                        Text("Your vehicle,\nmade actionable.").font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(warm)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .opacity(showSheet ? 1 : 0)
                .offset(y: showSheet ? 0 : 18)
                .animation(.easeOut(duration: 0.48).delay(0.16), value: showSheet)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("A few details help us shape your next step.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                        PostScanChoiceRow(title: "Ownership", choices: ["Leased", "Financed", "Owned"], selection: $leaseChoice)
                        PostScanChoiceRow(title: "Annual income", choices: ["Under $50k", "$50–100k", "$100k+"], selection: $incomeChoice)
                        PostScanChoiceRow(title: "Accident history", choices: ["None", "One", "Multiple"], selection: $accidentChoice)
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Current mileage").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.68))
                            HStack(spacing: 10) {
                                Image(systemName: "gauge.with.dots.needle.67percent").foregroundStyle(warm)
                                TextField("e.g. 42,000", text: $mileage)
#if canImport(UIKit)
                                    .keyboardType(.numberPad)
#endif
                                    .focused($mileageFocused)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .accessibilityLabel("Current mileage")
                            }
                            .padding(.horizontal, 14).frame(height: 50)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.12)))
                        }
                        Button {
                            mileageFocused = false
                            withAnimation(.easeOut(duration: 0.52)) { showRecommendation = true }
                        } label: {
                            HStack {
                                Text("Generate next step").font(.system(size: 16, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(ink)
                            .padding(.horizontal, 18).frame(height: 54)
                            .background(warm, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .accessibilityIdentifier("generate-next-step")
                        .disabled(mileage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(mileage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                        if showRecommendation { PostScanRecommendationCard(lease: leaseChoice, mileage: mileage, accent: warm).transition(.move(edge: .bottom).combined(with: .opacity)) }
                    }
                    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 28)
                }
                .frame(maxHeight: 440)
                .background(.ultraThinMaterial.opacity(0.96), in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.28)).frame(width: 38, height: 4).padding(.top, 9) }
                .offset(y: showSheet ? 0 : 420)
                .opacity(showSheet ? 1 : 0)
                .animation(.easeOut(duration: 0.68).delay(0.28), value: showSheet)
            }
        }
        .preferredColorScheme(.dark)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
#endif
        .onAppear { withAnimation { showSheet = true } }
    }
}

private struct PostScanVehicleHero: View {
    let progress: CaptureProgress

    var body: some View {
#if canImport(WebKit) && canImport(UIKit)
        VehicleGLBView(progress: progress, compact: false)
#else
        Color.clear
#endif
    }
}

private struct PostScanChoiceRow: View {
    let title: String
    let choices: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.68))
            HStack(spacing: 8) {
                ForEach(choices, id: \.self) { choice in
                    Button { withAnimation(.easeInOut(duration: 0.18)) { selection = choice } } label: {
                        Text(choice).font(.system(size: 13, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.72)
                            .foregroundStyle(selection == choice ? Color.black : .white.opacity(0.75))
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(selection == choice ? Color(red: 0.91, green: 0.68, blue: 0.32) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .accessibilityAddTraits(selection == choice ? .isSelected : [])
                }
            }
        }
    }
}

private struct PostScanRecommendationCard: View {
    let lease: String
    let mileage: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("NEXT BEST STEP", systemImage: "sparkles")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(accent)
                Spacer()
                Text("READY").font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(.white.opacity(0.5))
            }
            Text(lease == "Leased" ? "Start a lease-end review" : "Book a trade-in review")
                .font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Text(lease == "Leased" ? "Your current vehicle and mileage suggest planning early gives you the most flexibility. Compare buyout, renewal, and upgrade paths with a Toyota specialist." : "Your scan is a strong starting point for a value conversation. Bring the vehicle and mileage to a Toyota specialist for a personalized upgrade path.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                Text("Based on your \(mileage.isEmpty ? "reported" : mileage) miles and scan")
                    .font(.caption).foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(accent.opacity(0.34)))
    }
}
