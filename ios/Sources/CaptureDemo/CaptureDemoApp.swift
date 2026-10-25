import SwiftUI
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
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") { model.cancelScan() }
                            .accessibilityLabel("Cancel scan")
                        Spacer()
                        Button("Finish") { model.finishScan() }
                            .disabled(model.coveredCount == 0)
                            .accessibilityLabel(model.coveredCount == 0 ? "Finish unavailable until a view is captured" : "Finish scan")
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    Spacer()
                }
                VStack(spacing: 12) {
                    Spacer()
                    if let step = model.nextGuideStep {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(step.title).font(.headline)
                                Spacer()
                                Text("\(model.coveredCount)/12").font(.subheadline.monospacedDigit())
                            }
                            Text(step.instruction).font(.body)
                            Text(model.scanMessage)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.white.opacity(0.92))
                                .id(model.scanMessage)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .animation(.easeInOut(duration: 0.2), value: model.scanMessage)
                            HStack {
                                Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }
                                Button("Retake") { model.retakeCurrent() }
                                Button("Skip") { model.skipCurrent() }
                            }
                            .buttonStyle(.bordered)
                            .font(.subheadline)
                            if !model.cameraAvailable {
                                Button("Use video replay") { model.useReplayFallback(); model.showReplay() }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 16)
                    }
                    VehicleCoverageMap(progress: model.progress)
                        .frame(height: min(180, proxy.size.height * 0.22))
                        .padding(.horizontal, 28)
                        .accessibilityLabel("3D vehicle progress indicator")
                    HStack {
                        Image(systemName: "gearshape")
                        Text(model.evidenceProvenance)
                        Spacer()
                        Text("Move slowly around the vehicle")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
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
        let image = CIImage(cvPixelBuffer: maskPixelBuffer)
        guard let mask = context.createCGImage(image, from: image.extent), bounds.width > 0, bounds.height > 0 else { hide(); return }
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
                    guard let observation = request.results?.first else { return }
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
                } catch { return }
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
    @State private var rotation: Double = 0
    var body: some View {
#if canImport(SceneKit) && canImport(UIKit)
        VStack { SceneKitVehicleView(progress: progress, findings: findings).rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0)); HStack { Button("Rotate view") { rotation = rotation >= 270 ? 0 : rotation + 90 }; Button("Reset view") { rotation = 0 } } }
#else
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 55).fill(Color.gray.opacity(0.34)).overlay(RoundedRectangle(cornerRadius: 55).stroke(Color.white.opacity(0.35), lineWidth: 2)).rotation3DEffect(.degrees(8), axis: (x: 1, y: 0, z: 0))
                RoundedRectangle(cornerRadius: 30).fill(Color.gray.opacity(0.2)).frame(width: proxy.size.width * 0.34, height: proxy.size.height * 0.62)
                ForEach(CaptureRegion.allCases, id: \.self) { region in
                    let position = mapPosition(region, in: proxy.size)
                    Text(label(for: region)).font(.caption2.bold()).foregroundStyle(.white).padding(6)
                        .background(color(for: progress[region])).clipShape(Capsule()).position(position)
                        .accessibilityLabel("\(region.rawValue): \(progress[region].rawValue)")
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

private struct CoverageList: View {
    @ObservedObject var model: CapturePresentationModel
    let title: String
    var body: some View {
        List(CaptureRegion.allCases, id: \.self) { region in
            HStack {
                Text(region.rawValue)
                Spacer()
                Text(model.progress[region].rawValue)
                    .foregroundStyle(model.progress[region] == .covered ? .green : .orange)
                    .accessibilityLabel(region.rawValue)
                    .accessibilityValue(model.progress[region].rawValue)
            }
        }
        .overlay(alignment: .top) { Text("\(model.coveredCount) of 12 covered").font(.headline).padding(.top, 8) }
        .navigationTitle(title)
    }
}

private struct ResultsView: View {
    @ObservedObject var model: CapturePresentationModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Scan results").font(.title.bold())
                Text("Coverage: \(model.coveredCount) of 12 regions")
                Text(model.replayStatus).font(.footnote).foregroundStyle(.secondary)
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                    Button("Retry synthetic replay") { model.showReplay() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Retry synthetic replay")
                }
                Text("3D vehicle scan and findings").font(.headline)
                VehicleCoverageMap(progress: model.progress, findings: model.visionFindings).frame(height: 260)
                if !model.visionAnalysis.isEmpty { Text(model.visionAnalysis).font(.subheadline) }
                if !model.visionUnknownRegions.isEmpty {
                    Text("Unknown / needs another view: \(model.visionUnknownRegions.joined(separator: ", "))").font(.footnote).foregroundStyle(.orange)
                }
                ForEach(model.visionRegions) { region in
                    HStack {
                        Text(region.id)
                        Spacer()
                        Text("\(region.state), \(region.quality)")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(region.id.replacingOccurrences(of: "-", with: " ").capitalized), \(region.state.replacingOccurrences(of: "_", with: " ")), \(region.quality) quality. \(region.note)")
                }
                if !model.visionFindings.isEmpty {
                    Text("Evidence-backed findings").font(.headline)
                    ForEach(Array(model.visionFindings.enumerated()), id: \.element.id) { index, finding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(finding.description)").font(.body.bold())
                            Text("Region: \(finding.region) · confidence \(finding.confidence, specifier: "%.2f")")
                            Text("Evidence: \(finding.evidence)").font(.footnote).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                }
                Text(model.findingSummary)
                if let description = model.findingDescription {
                    Text(description)
                    Text(model.findingEvidenceLabel ?? "Demo · synthetic image")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let check = model.findingRecommendedCheck {
                        Text("Recommended check: \(check)")
                            .font(.subheadline)
                    }
                }
                Text("Recommended next move").font(.headline)
                if let recommendation = model.recommendation {
                    Text(recommendation.nextMove).font(.title3.bold())
                    Text(recommendation.rationale)
                    Text("Confidence is limited; this is a bounded synthetic scenario.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(recommendation.caveats, id: \.self) { Text("Caveat: \($0)").font(.footnote).foregroundStyle(.secondary) }
                    Text("Based on: \(recommendation.basedOn.joined(separator: ", "))")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityLabel("Recommendation evidence: \(recommendation.basedOn.joined(separator: ", "))")
                }
                Button("Request human review") { model.requestHumanReview() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("request-human-review")
                if let status = model.humanActionStatus {
                    Text(status)
                }
                CoverageList(model: model, title: "Coverage details").frame(minHeight: 420)
            }.padding()
        }
        .accessibilityElement(children: .contain)
    }
}
