import SwiftUI
#if SWIFT_PACKAGE
import CaptureCore
#endif
#if canImport(SceneKit) && canImport(UIKit)
import SceneKit
import UIKit
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
                            Button("Use synthetic replay") { model.showReplay() }
                                .buttonStyle(.borderedProminent).padding()
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("GUIDED CAPTURE").font(.caption.weight(.semibold)).tracking(1.4)
                    Spacer()
                    Text("\(model.coveredCount)/12").font(.headline.monospacedDigit())
                }
                Text("Capture the vehicle").font(.title.bold())
                ProgressView(value: Double(model.coveredCount), total: 12).tint(.cyan)
                Text("Coverage: \(model.coveredCount) of 12 regions").foregroundStyle(.secondary)
                if let step = model.nextGuideStep {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Next: \(step.title)", systemImage: "location.fill").font(.headline)
                        Text(step.instruction)
                        Text("Safety: \(step.safetyNote)").font(.footnote).foregroundStyle(.yellow)
                        Text(step.lowerPhonePrompt).font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button(model.isPaused ? "Resume" : "Pause") { model.togglePause() }.buttonStyle(.bordered)
                            Button("Capture \(step.title)") { model.captureSample() }.buttonStyle(.borderedProminent)
                            Button("Skip / blocked") { model.skipCurrent() }.buttonStyle(.bordered)
                        }
                        Button("Retake / quality limited") { model.retakeCurrent() }.font(.footnote)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("capture-next")
                        Button("Lower phone before moving") { model.lowerPhone() }.font(.footnote)
                    }.padding().background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
                } else { Text("Every region is covered.").font(.headline) }
                Text(model.captureStatus).font(.footnote).foregroundStyle(.secondary)
                VehicleCoverageMap(progress: model.progress)
                    .frame(height: 260)
                    .accessibilityLabel("Progressive vehicle coverage map")
                CoverageList(model: model, title: "Coverage details").frame(minHeight: 500)
            }.padding()
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.025, green: 0.055, blue: 0.12).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct VehicleCoverageMap: View {
    let progress: CaptureProgress
    var body: some View {
#if canImport(SceneKit) && canImport(UIKit)
        SceneKitVehicleView(progress: progress)
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
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(); view.scene = makeScene(); view.pointOfView = view.scene?.rootNode.childNodes.first(where: { $0.camera != nil }); view.allowsCameraControl = false; view.backgroundColor = UIColor(red: 0.025, green: 0.055, blue: 0.12, alpha: 1); view.accessibilityLabel = "Three dimensional vehicle coverage map"
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) { view.scene = makeScene() }
    private func makeScene() -> SCNScene {
        let scene = SCNScene(); scene.background.contents = UIColor(red: 0.025, green: 0.055, blue: 0.12, alpha: 1)
        let root = scene.rootNode
        let body = SCNNode(geometry: SCNBox(width: 3.8, height: 0.65, length: 7.0, chamferRadius: 0.35)); body.geometry?.materials = [material(.gray, state: .unseen)]; root.addChildNode(body)
        let cabin = SCNNode(geometry: SCNBox(width: 3.05, height: 0.85, length: 3.25, chamferRadius: 0.3)); cabin.position.y = 0.68; cabin.geometry?.materials = [material(.blue, state: .covered)]; root.addChildNode(cabin)
        for x in [-1.72, 1.72] { for z in [-2.35, 2.35] { let wheel = SCNNode(geometry: SCNCylinder(radius: 0.48, height: 0.28)); wheel.eulerAngles.z = .pi / 2; wheel.position = SCNVector3(x, -0.28, z); wheel.geometry?.materials = [material(.black, state: .covered)]; root.addChildNode(wheel) } }
        for z in [-3.48, 3.48] { let light = SCNNode(geometry: SCNBox(width: 2.2, height: 0.14, length: 0.12, chamferRadius: 0.04)); light.position = SCNVector3(0, 0.04, z); light.geometry?.materials = [material(.yellow, state: progress[z > 0 ? .front : .rear])]; root.addChildNode(light) }
        for region in [CaptureRegion.frontLeft, .frontRight, .rearLeft, .rearRight] { let marker = SCNNode(geometry: SCNSphere(radius: 0.12)); marker.position = markerPosition(region); marker.geometry?.materials = [material(.red, state: progress[region])]; marker.isHidden = progress[region] == .covered || progress[region] == .unseen; root.addChildNode(marker) }
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.fieldOfView = 48; camera.position = SCNVector3(7, 5.2, 9); camera.look(at: SCNVector3(0, 0.2, 0)); root.addChildNode(camera)
        let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni; light.light?.intensity = 900; light.position = SCNVector3(4, 7, 5); root.addChildNode(light)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.color = UIColor(white: 0.35, alpha: 1); root.addChildNode(ambient)
        return scene
    }
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
                Text("Vision map and findings").font(.headline)
                VehicleCoverageMap(progress: model.progress).frame(height: 260)
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
                    .accessibilityLabel("\(region.id), \(region.state), \(region.quality). \(region.note)")
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
                    Text("Confidence is limited to this synthetic scenario: \(recommendation.confidence, specifier: "%.2f")")
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
