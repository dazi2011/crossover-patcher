import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = PatcherStore()
    @State private var isDropTargeted = false
    private let panels = PanelService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                sourceSection
                if store.isSupported {
                    patchSection
                }
                statusSection
            }
            .padding(24)
        }
        .background(.regularMaterial)
        .onAppear(perform: detectDefaultCrossOver)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CrossOver Patcher")
                .font(.largeTitle.bold())
            Text("严格识别受支持版本，只修补所选 CrossOver 副本；不会修改游戏、反作弊文件或容器。")
                .foregroundStyle(.secondary)
        }
    }

    private var sourceSection: some View {
        GroupBox("1. 选择 CrossOver") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if let candidate = store.crossover {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: candidate.url.path))
                            .resizable()
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.displayName).fontWeight(.semibold)
                            Text(candidate.versionSummary.isEmpty ? "无法读取版本" : candidate.versionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("把受支持的 CrossOver.app 拖到这里")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(store.crossover == nil ? "选择…" : "更换…") {
                        if let url = panels.chooseCrossOver() { store.selectCrossOver(url) }
                    }
                    .disabled(store.isRunning)
                }

                supportStatus
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard !store.isRunning,
                      let url = urls.first(where: { $0.pathExtension.lowercased() == "app" })
                else { return false }
                store.selectCrossOver(url)
                return true
            } isTargeted: { isDropTargeted = $0 }
        }
    }

    @ViewBuilder
    private var supportStatus: some View {
        if let candidate = store.crossover {
            switch candidate.support {
            case let .supported(_, displayName):
                Label("已识别 \(displayName)；PatchCore 还会验证官方签名、完整哈希与 PE/Mach-O 结构。", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            case let .unsupported(reason):
                Label(reason, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }
    }

    private var patchSection: some View {
        GroupBox("2. 创建 Patch 后的 CrossOver 副本") {
            VStack(alignment: .leading, spacing: 10) {
                Label("原 App 不会被覆盖。三个目标模块会在输出 App 内生成相邻 .cxorig 备份。", systemImage: "externaldrive.badge.checkmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Label("兼容性修改存在非零账号处罚风险；请先阅读 Release README。", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                if !store.coreAvailable {
                    Label("当前是可公开编译的外壳构建，未包含闭源 PatchCore。官方 Release 会包含已编译核心。", systemImage: "lock.trianglebadge.exclamationmark")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("开始 Patch…") {
                        chooseDestinationAndStart()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isRunning || !store.coreAvailable)

                    if store.isRunning {
                        Button("安全取消") { store.cancel() }
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if store.isRunning || !store.logs.isEmpty || store.runState != .idle {
            GroupBox("进度与日志") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.phase).fontWeight(.medium)
                    ProgressView(value: store.progress)

                    if !store.logs.isEmpty {
                        ScrollView {
                            Text(store.logs.joined(separator: "\n"))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 90, maxHeight: 180)
                    }

                    switch store.runState {
                    case let .failed(message):
                        Label(message, systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    case let .succeeded(app, bottleName):
                        HStack {
                            Label("Patch 完成\(bottleName.map { "，容器：\($0)" } ?? "")", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("在 Finder 中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([app])
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
                .padding(8)
            }
        }
    }

    private func chooseDestinationAndStart() {
        guard let source = store.crossover?.url,
              let destination = panels.chooseDestination(for: source)
        else { return }
        store.start(destination: destination)
    }

    private func detectDefaultCrossOver() {
        guard store.crossover == nil else { return }
        for path in ["/Applications/CrossOver Preview.app", "/Applications/CrossOver.app"] {
            let candidate = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                store.selectCrossOver(candidate)
                return
            }
        }
    }
}
