import Combine
import Foundation
import PatcherProtocol

@MainActor
final class PatcherStore: ObservableObject {
    enum RunState: Equatable {
        case idle
        case running
        case succeeded(app: URL, bottleName: String?)
        case failed(String)
    }

    @Published private(set) var crossover: CrossOverCandidate?
    @Published private(set) var similarBottles: [BottleCandidate] = []
    @Published private(set) var allBottleNames: [String] = []
    @Published var selectedBottleID: String?
    @Published var bottleChoice: BottleChoice = .createNew
    @Published var newBottleName = ""
    @Published private(set) var phase = "等待开始"
    @Published private(set) var progress = 0.0
    @Published private(set) var logs: [String] = []
    @Published private(set) var runState: RunState = .idle

    private let inspector: CrossOverInspector
    private let bottleDiscovery: BottleDiscoveryService
    private let coreClient: PatchCoreClient
    private var execution: CoreExecution?

    init(
        inspector: CrossOverInspector = CrossOverInspector(),
        bottleDiscovery: BottleDiscoveryService = BottleDiscoveryService(),
        coreClient: PatchCoreClient = BundledPatchCoreClient()
    ) {
        self.inspector = inspector
        self.bottleDiscovery = bottleDiscovery
        self.coreClient = coreClient
    }

    var isSupported: Bool {
        guard let support = crossover?.support else { return false }
        if case .supported = support { return true }
        return false
    }

    var isRunning: Bool {
        runState == .running
    }

    var coreAvailable: Bool {
        coreClient.isAvailable
    }

    var selectedBottle: BottleCandidate? {
        similarBottles.first { $0.id == selectedBottleID }
    }

    var availableBottleChoices: [BottleChoice] {
        similarBottles.isEmpty ? [.createNew] : BottleChoice.allCases
    }

    func selectCrossOver(_ url: URL) {
        crossover = inspector.inspect(url)
        runState = .idle
        logs = []
        phase = "等待开始"
        progress = 0
        refreshBottles()
    }

    func refreshBottles() {
        let all = bottleDiscovery.allBottles()
        allBottleNames = all.map(\.name)
        similarBottles = all.filter { BottleNameMatcher.isSimilarGameBottle($0.name) }
        selectedBottleID = similarBottles.first?.id
        bottleChoice = similarBottles.isEmpty ? .createNew : .copyExisting
        refreshSuggestedBottleName()
    }

    func selectedBottleDidChange() {
        refreshSuggestedBottleName()
    }

    func refreshSuggestedBottleName() {
        let base = BottleNameMatcher.canonicalPatchedName(for: selectedBottle?.name)
        newBottleName = BottleNameMatcher.uniqueName(base: base, existingNames: allBottleNames)
    }

    func start(destination: URL) {
        guard let crossover else {
            runState = .failed("尚未选择 CrossOver。")
            return
        }
        guard case .supported = crossover.support else {
            runState = .failed("所选 CrossOver 不受支持。")
            return
        }
        guard destination.standardizedFileURL != crossover.url.standardizedFileURL else {
            runState = .failed("输出位置不能覆盖原版 CrossOver Preview.app。")
            return
        }

        let request = RuntimePatchRequest(
            sourceAppPath: crossover.url.path,
            destinationAppPath: destination.path
        )

        logs = []
        phase = "启动 PatchCore"
        progress = 0
        runState = .running
        execution = coreClient.run(request: request, onEvent: { [weak self] event in
            self?.consume(event)
        }, completion: { [weak self] result in
            guard let self else { return }
            self.execution = nil
            if case let .failure(error) = result, self.runState == .running {
                self.runState = .failed(error.localizedDescription)
            }
        })
    }

    func cancel() {
        execution?.cancel()
        logs.append("已请求取消；PatchCore 将在安全事务边界停止并回滚。")
    }

    private func consume(_ event: PatchCoreEvent) {
        if let phase = event.phase { self.phase = phase }
        if let fraction = event.fraction { progress = min(max(fraction, 0), 1) }
        if let message = event.message { logs.append(message) }
        switch event.kind {
        case .completed:
            let output = URL(fileURLWithPath: event.outputAppPath ?? crossover?.url.path ?? "")
            runState = .succeeded(app: output, bottleName: event.outputBottleName)
            progress = 1
        case .failed:
            runState = .failed(event.message ?? "PatchCore 报告失败。")
        default:
            break
        }
    }
}
