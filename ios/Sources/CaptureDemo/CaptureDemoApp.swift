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
                        Button("Run synthetic replay") { model.showReplay() }.buttonStyle(.bordered)
                            .accessibilityIdentifier("run-replay")
                            .accessibilityLabel("Run synthetic replay demo")
                        Text("Synthetic replay is the safe fallback when camera access is unavailable.")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding()
                case .guided:
                    GuidedCaptureView(model: model)
                case .replay:
                    ProgressView("Loading replay…").task { model.runReplay() }
                case .profile:
                    VehicleProfileView(model: model)
                case .results:
                    ResultsView(model: model)
                }
            }
            // Give each presentation state a fresh identity so a cancelled camera
            // session cannot leave its guided controls layered over the start view.
            .id(model.screen)
            .navigationTitle("Toyota Next Move")
        }
    }
}


private struct GuidedCaptureView: View {
    @ObservedObject var model: CapturePresentationModel
    var body: some View {
        let pulseStatus = model.captureStatus.lowercased()
        GeometryReader { proxy in
            ZStack {
#if canImport(ARKit) && canImport(UIKit)
                if model.cameraAvailable && model.arPoseAvailable {
                    ARCameraScannerView(model: model).ignoresSafeArea()
                } else if model.cameraAvailable {
#if canImport(AVFoundation)
                    LiveCapturePreview(session: model.activeCaptureSession).ignoresSafeArea()
#else
                    Color.black.ignoresSafeArea()
#endif
                } else { Color.black.ignoresSafeArea() }
#else
                Color.black.ignoresSafeArea()
#endif
                LinearGradient(colors: [.black.opacity(0.58), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 190).ignoresSafeArea(edges: .top)
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 290).ignoresSafeArea(edges: .bottom).frame(maxHeight: .infinity, alignment: .bottom)
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") { model.cancelScan() }.accessibilityLabel("Cancel scan")
                        Spacer()
                        Button("Finish") { model.finishScan() }.disabled(model.coveredCount == 0)
                            .accessibilityLabel(model.coveredCount == 0 ? "Finish unavailable until evidence is captured" : "Finish scan")
                    }.font(.headline).padding(.horizontal, 22).padding(.top, 8)
                    Text(model.scanMessage).font(.body.weight(.semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center).padding(.horizontal, 18).padding(.vertical, 12)
                        .frame(maxWidth: proxy.size.width - 42)
                        .background(.ultraThinMaterial, in: Capsule()).id(model.scanMessage)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.22), value: model.scanMessage)
                        .padding(.top, 18).accessibilityAddTraits(.isHeader)
                    Spacer()
                    VStack(spacing: 10) {
                        VehicleCoverageMap(progress: model.progress)
                            .vehicleObservationPulse(isVisible: model.vehicleMatchStatus == "Vehicle visible" && !pulseStatus.contains("no new coverage recorded") && !pulseStatus.contains("analyzing") && !pulseStatus.contains("paused") && !pulseStatus.contains("resumed") && !pulseStatus.contains("unavailable") && !pulseStatus.contains("failed") && !pulseStatus.contains("could not complete"))
                            .frame(height: min(220, proxy.size.height * 0.27))
                            .accessibilityLabel("Vehicle scan progress. Neutral surfaces are unseen; colored surfaces have been observed.")
                        HStack(spacing: 18) {
                            Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }
                            Button("Retake") { model.retakeCurrent() }
                            Button("Skip") { model.skipCurrent() }
                        }.buttonStyle(.bordered).font(.subheadline).tint(.white)
                        HStack {
                            Image(systemName: model.cameraAvailable ? "camera.fill" : "play.rectangle.fill")
                            Text(model.cameraAvailable ? "Live camera" : "Replay demo")
                            Spacer(); Text("Move around the vehicle")
                        }.font(.caption).foregroundStyle(.white.opacity(0.75))
                    }.padding(.horizontal, 18).padding(.bottom, 14)
                }
            }
        }.foregroundStyle(.white).preferredColorScheme(.dark)
    }
}

private struct VehicleProfileView: View {
    @ObservedObject var model: CapturePresentationModel
    @State private var ownership = VehicleEvaluationProfile.Ownership.owned
    @State private var income = ""
    @State private var mileage = ""
    @State private var leasePayment = ""
    @State private var leaseMonths = ""
    @State private var year = "2022"
    @State private var vehicleModel = "Camry"
    @State private var trim = "Toyota"
    var body: some View {
        Form {
            Section("About the vehicle") {
                TextField("Vehicle year", text: $year)
                TextField("Vehicle model", text: $vehicleModel)
                TextField("Make / trim", text: $trim)
                TextField("Current mileage", text: $mileage)
            }
            Section("Your finances") {
                TextField("Annual gross income", text: $income)
                Picker("Ownership", selection: $ownership) { Text("Owned / financed").tag(VehicleEvaluationProfile.Ownership.owned); Text("Leased").tag(VehicleEvaluationProfile.Ownership.leased) }
                if ownership == .leased {
                    TextField("Monthly lease payment", text: $leasePayment)
                    TextField("Lease months remaining", text: $leaseMonths)
                }
            }
            Section { Button(model.evaluationLoading ? "Evaluating…" : "Evaluate my Toyota") {
                let profile = VehicleEvaluationProfile(ownership: ownership, annualIncome: Double(income) ?? 0, mileage: Int(mileage) ?? -1, leasePayment: Double(leasePayment), leaseMonthsRemaining: Int(leaseMonths), vehicleYear: Int(year) ?? 0, vehicleModel: vehicleModel, vehicleTrim: trim)
                model.submitEvaluation(profile)
            }.disabled(model.evaluationLoading) }
            Text("GPT reviews the captured images for visible observations, then combines them with these details for a rough resale range and Toyota Financial Services planning guidance. This is not a mechanical diagnosis or a TFS quote.").font(.footnote).foregroundStyle(.secondary)
            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Vehicle details")
    }
}

#if canImport(ARKit) && canImport(UIKit)
private extension Notification.Name { static let resetARCalibration = Notification.Name("resetARCalibration") }

private struct ARCameraScannerView: UIViewRepresentable {
    @ObservedObject var model: CapturePresentationModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(); view.scene = SCNScene(); view.automaticallyUpdatesLighting = true; view.backgroundColor = .black; view.debugOptions = []
        context.coordinator.sceneView = view
        let config = ARWorldTrackingConfiguration(); view.session.delegate = context.coordinator; view.session.run(config)
        context.coordinator.installResetObserver(configuration: config)
        return view
    }
    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.sceneView = view
    }
    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) { coordinator.teardown() }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var model: CapturePresentationModel?
        weak var sceneView: ARSCNView?
        private var resetObserver: NSObjectProtocol?
        private var configuration: ARWorldTrackingConfiguration?
        init(model: CapturePresentationModel) { self.model = model }

        func installResetObserver(configuration: ARWorldTrackingConfiguration) {
            self.configuration = configuration
            resetObserver = NotificationCenter.default.addObserver(forName: .resetARCalibration, object: nil, queue: .main) { [weak self] _ in
                self?.sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            }
        }

        func teardown() {
            if let resetObserver {
                NotificationCenter.default.removeObserver(resetObserver)
                self.resetObserver = nil
            }
            sceneView?.session.pause()
            configuration = nil
            sceneView = nil
        }

        func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor [weak self] in
                self?.model?.handleARSessionInterruption()
            }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor [weak self] in
                guard let self, let configuration = self.configuration else { return }
                session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                self.model?.handleARSessionInterruptionEnded()
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor [weak self] in
                self?.model?.handleARSessionFailure()
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let pixelBuffer = frame.capturedImage
            let timestamp = frame.timestamp
            Task { @MainActor [weak self] in
                self?.model?.consumeARFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
            }
        }



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
    var vehicleObservationPulseVisible = false
    @State private var baseRotation: Double = 0
    @State private var dragRotation: Double = 0
    var body: some View {
        ZStack {
#if canImport(SceneKit) && canImport(UIKit)
        VStack(spacing: 4) {
            Group {
#if canImport(WebKit)
                VehicleGLBView(progress: progress)
                    .frame(maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
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
            Text("Drag to rotate").font(.caption2).foregroundStyle(.white.opacity(0.62))
        }
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
        .overlay {
            VehicleObservationPulse(isVisible: vehicleObservationPulseVisible)
                .allowsHitTesting(false)
        }
    }
    private func label(for region: CaptureRegion) -> String { region.rawValue.replacingOccurrences(of: "interior-", with: "int ").capitalized }
    private func color(for state: CoverageState) -> Color { switch state { case .covered: .green; case .partial: .orange; case .blocked: .red; case .unseen: Color.gray.opacity(0.65) } }
    private func mapPosition(_ region: CaptureRegion, in size: CGSize) -> CGPoint {
        let points: [CaptureRegion: CGPoint] = [.front: CGPoint(x: size.width/2, y: 18), .frontLeft: CGPoint(x: size.width*0.24, y: 45), .left: CGPoint(x: size.width*0.12, y: size.height/2), .rearLeft: CGPoint(x: size.width*0.24, y: size.height-45), .rear: CGPoint(x: size.width/2, y: size.height-18), .rearRight: CGPoint(x: size.width*0.76, y: size.height-45), .right: CGPoint(x: size.width*0.88, y: size.height/2), .frontRight: CGPoint(x: size.width*0.76, y: 45), .roof: CGPoint(x: size.width/2, y: size.height/2), .interiorFront: CGPoint(x: size.width*0.42, y: size.height*0.38), .interiorRear: CGPoint(x: size.width*0.58, y: size.height*0.62), .trunk: CGPoint(x: size.width/2, y: size.height*0.82)]
        return points[region] ?? CGPoint(x: size.width/2, y: size.height/2)
    }

    func vehicleObservationPulse(isVisible: Bool) -> VehicleCoverageMap {
        var copy = self
        copy.vehicleObservationPulseVisible = isVisible
        return copy
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

private struct VehicleObservationPulse: View {
    let isVisible: Bool
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .stroke(Color.cyan.opacity(isVisible ? (isExpanded ? 0.2 : 0.7) : 0), lineWidth: 3)
            .frame(width: 58, height: 58)
            .scaleEffect(isVisible && isExpanded ? 1.18 : 0.88)
            .onAppear { updateAnimation(for: isVisible) }
            .onChange(of: isVisible) { _, newValue in updateAnimation(for: newValue) }
    }

    private func updateAnimation(for visible: Bool) {
        guard visible else {
            withAnimation(.easeOut(duration: 0.16)) { isExpanded = false }
            return
        }
        isExpanded = false
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { isExpanded = true }
    }
}

#if canImport(WebKit) && canImport(UIKit)
/// Loads the authored Blender GLB through the bundled WebGL material viewer.
/// This keeps the exact mesh/material reveal authored in Vision assets instead
/// of substituting the old rounded-box SceneKit placeholder.
private struct VehicleGLBView: UIViewRepresentable {
    let progress: CaptureProgress
    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.isScrollEnabled = false
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "VehicleViewer") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        let covered = progress.coverage.values.filter { $0 == .covered }.count
        let ratio = Double(covered) / Double(max(1, CaptureRegion.allCases.count))
        view.evaluateJavaScript("window.vehicleStudy && window.vehicleStudy.setProgress(\(ratio));", completionHandler: nil)
    }
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
    @State private var selectedFinding: PresentationFinding?
    @State private var showingFinding = false
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
                ZStack {
                    VehicleCoverageMap(progress: model.progress, findings: model.visionFindings)
                    GeometryReader { proxy in
                        ForEach(model.visionFindings) { finding in
                            Button {
                                selectedFinding = finding
                                showingFinding = true
                            } label: {
                                Image(systemName: "exclamationmark").font(.caption.bold()).foregroundStyle(.white)
                                    .frame(width: 28, height: 28).background(.red, in: Circle()).overlay(Circle().stroke(.white, lineWidth: 2))
                            }.accessibilityLabel("Issue: \(finding.description)")
                                .position(findingPosition(finding.region, in: proxy.size))
                        }
                    }
                }.frame(height: 260)
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
                if let evaluation = model.evaluation {
                    Text("Vehicle evaluation").font(.headline)
                    HStack(spacing: 10) {
                        EvaluationMetric(title: "Resale range", value: "$\(evaluation.resaleLow)–$\(evaluation.resaleHigh)")
                        EvaluationMetric(title: "Visible issues", value: "\(evaluation.findings.count)")
                    }
                    HStack(spacing: 10) {
                        EvaluationMetric(title: "Replacement", value: evaluation.replacementHorizon)
                        if let burden = evaluation.leaseBurden { EvaluationMetric(title: "Payment burden", value: burden) }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issues found").font(.subheadline.bold())
                        if evaluation.findings.isEmpty { Text("No visible issues identified in the submitted evidence.").font(.footnote) }
                        ForEach(evaluation.findings) { EvaluationFindingRow(finding: $0) }
                    }.padding(12).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ownership outlook").font(.subheadline.bold())
                        Text(evaluation.longevityParagraph).font(.footnote)
                    }.padding(12).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Toyota Financial Services next step").font(.subheadline.bold())
                        Text(evaluation.financialServicesRecommendation).font(.footnote)
                    }.padding(12).background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    ForEach(evaluation.assumptions, id: \.self) { Text("Assumption · \($0)").font(.caption).foregroundStyle(.secondary) }
                    ForEach(evaluation.uncertainty, id: \.self) { Text("Uncertainty · \($0)").font(.caption).foregroundStyle(.secondary) }
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
        .alert("Visible issue", isPresented: $showingFinding) {
            Button("Done", role: .cancel) { selectedFinding = nil }
        } message: {
            if let finding = selectedFinding {
                Text("\(finding.description)\n\nRegion: \(finding.region)\nConfidence: \(finding.confidence * 100, specifier: "%.0f")%\nEvidence: \(finding.evidence)")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func findingPosition(_ region: String, in size: CGSize) -> CGPoint {
        let p: [String: CGPoint] = ["front": CGPoint(x: size.width / 2, y: 30), "front-left": CGPoint(x: size.width * 0.25, y: 65), "left": CGPoint(x: size.width * 0.14, y: size.height / 2), "rear-left": CGPoint(x: size.width * 0.25, y: size.height - 55), "rear": CGPoint(x: size.width / 2, y: size.height - 28), "rear-right": CGPoint(x: size.width * 0.75, y: size.height - 55), "right": CGPoint(x: size.width * 0.86, y: size.height / 2), "front-right": CGPoint(x: size.width * 0.75, y: 65), "roof": CGPoint(x: size.width / 2, y: size.height / 2), "trunk": CGPoint(x: size.width / 2, y: size.height * 0.78)]
        return p[region] ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

private struct EvaluationFindingRow: View {
    let finding: VehicleEvaluationFinding
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(.orange).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.issue.capitalized).font(.subheadline.bold())
                Text("\(finding.region.rawValue) · \(Int(finding.confidence * 100))% confidence").font(.caption).foregroundStyle(.secondary)
                Text(finding.recommendedCheck).font(.caption)
            }
        }
    }
}

private struct EvaluationMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).lineLimit(3).minimumScaleFactor(0.75)
        }.frame(maxWidth: .infinity, minHeight: 58, alignment: .leading).padding(10)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
