import Foundation
import PatcherProtocol

enum BottleChoice: String, CaseIterable, Identifiable, Sendable {
    case patchExisting
    case copyExisting
    case createNew

    var id: String { rawValue }

    var coreMode: BottlePatchMode {
        switch self {
        case .patchExisting: .patchExisting
        case .copyExisting: .copyExisting
        case .createNew: .createNew
        }
    }

    var title: String {
        switch self {
        case .patchExisting: "Patch 当前容器"
        case .copyExisting: "复制当前容器后 Patch（推荐）"
        case .createNew: "新建 Win11 容器后 Patch"
        }
    }

    var detail: String {
        switch self {
        case .patchExisting:
            "直接修改所选容器；执行前会备份受管配置。"
        case .copyExisting:
            "通过 CrossOver 官方复制接口完整迁移数据，并生成新的 BottleID。"
        case .createNew:
            "忽略现有容器，创建一个干净的 win11_64 容器。"
        }
    }
}
