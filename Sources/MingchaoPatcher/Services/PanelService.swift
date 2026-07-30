import AppKit
import UniformTypeIdentifiers

@MainActor
struct PanelService {
    func chooseCrossOver() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择受支持的 CrossOver.app"
        panel.prompt = "选择"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseDestination(for source: URL) -> URL? {
        let panel = NSSavePanel()
        panel.title = "保存 Patch 后的 CrossOver 副本"
        panel.prompt = "保存并开始"
        panel.nameFieldLabel = "名称："
        panel.nameFieldStringValue = "\(source.deletingPathExtension().lastPathComponent) Patched.app"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.directoryURL = source.deletingLastPathComponent()
        return panel.runModal() == .OK ? panel.url : nil
    }
}
