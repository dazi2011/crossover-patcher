import Foundation
import PatcherProtocol

protocol CoreExecution: AnyObject {
    func cancel()
}

protocol PatchCoreClient: AnyObject {
    var isAvailable: Bool { get }

    @discardableResult
    func run(
        request: RuntimePatchRequest,
        onEvent: @escaping (PatchCoreEvent) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> CoreExecution?
}

struct PatchCoreClientError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class BundledPatchCoreClient: PatchCoreClient {
    private let fileManager: FileManager
    private let environment: [String: String]

    init(fileManager: FileManager = .default, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.fileManager = fileManager
        self.environment = environment
    }

    var isAvailable: Bool {
        guard let url = coreURL else { return false }
        return fileManager.isExecutableFile(atPath: url.path)
    }

    @discardableResult
    func run(
        request: RuntimePatchRequest,
        onEvent: @escaping (PatchCoreEvent) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> CoreExecution? {
        guard let coreURL, fileManager.isExecutableFile(atPath: coreURL.path) else {
            completion(.failure(PatchCoreClientError(
                message: "这个构建没有包含闭源 PatchCore。请从官方 Release 下载完整 Patcher.app。"
            )))
            return nil
        }

        do {
            let process = Process()
            let standardInput = Pipe()
            let standardOutput = Pipe()
            let standardError = Pipe()
            let stream = CoreEventStream(onEvent: onEvent)

            process.executableURL = coreURL
            process.arguments = ["apply-app-json"]
            process.standardInput = standardInput
            process.standardOutput = standardOutput
            process.standardError = standardError

            standardOutput.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stream.append(data)
                }
            }

            process.terminationHandler = { process in
                standardOutput.fileHandleForReading.readabilityHandler = nil
                stream.finish()
                let stderrData = standardError.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(decoding: stderrData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        completion(.success(()))
                    } else {
                        let detail = stderr.isEmpty ? "没有附加错误信息。" : stderr
                        completion(.failure(PatchCoreClientError(
                            message: "PatchCore 失败（退出码 \(process.terminationStatus)）：\(detail)"
                        )))
                    }
                }
            }

            try process.run()
            let input = try JSONEncoder().encode(request)
            standardInput.fileHandleForWriting.write(input)
            standardInput.fileHandleForWriting.write(Data([0x0a]))
            try standardInput.fileHandleForWriting.close()
            return CoreProcessExecution(process: process)
        } catch {
            completion(.failure(error))
            return nil
        }
    }

    private var coreURL: URL? {
        if let override = environment["MINGCHAO_PATCH_CORE"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/PatchCore", isDirectory: false)
    }
}

private final class CoreProcessExecution: CoreExecution {
    private let process: Process

    init(process: Process) {
        self.process = process
    }

    func cancel() {
        guard process.isRunning else { return }
        process.interrupt()
    }
}

private final class CoreEventStream: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.crossover-patcher.core-events")
    private var buffer = Data()
    private let decoder = JSONDecoder()
    private let onEvent: (PatchCoreEvent) -> Void

    init(onEvent: @escaping (PatchCoreEvent) -> Void) {
        self.onEvent = onEvent
    }

    func append(_ data: Data) {
        queue.async {
            self.buffer.append(data)
            self.drainCompleteLines()
        }
    }

    func finish() {
        queue.sync {
            drainCompleteLines()
            if !buffer.isEmpty {
                decode(buffer)
                buffer.removeAll(keepingCapacity: false)
            }
        }
    }

    private func drainCompleteLines() {
        while let newline = buffer.firstIndex(of: 0x0a) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            if !line.isEmpty { decode(Data(line)) }
        }
    }

    private func decode(_ data: Data) {
        guard let event = try? decoder.decode(PatchCoreEvent.self, from: data) else { return }
        DispatchQueue.main.async { self.onEvent(event) }
    }
}
