import Foundation
import AppKit

public enum ValidationResult {
    case valid
    case directoryNotFound
    case noJSONFiles
    case notDirectory
}

public final class ConfigService {
    public static let shared = ConfigService()

    private let importPathKey = "importPath"
    private let dataSourceConfirmedKey = "sync.dataSource.confirmed"

    public var importPath: String {
        get { UserDefaults.standard.string(forKey: importPathKey) ?? defaultImportPath }
        set { UserDefaults.standard.set(newValue, forKey: importPathKey) }
    }

    public var defaultImportPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/opencode/opencode.db")
            .path
    }

    public var isDataSourceConfirmed: Bool {
        get { UserDefaults.standard.bool(forKey: dataSourceConfirmedKey) }
        set { UserDefaults.standard.set(newValue, forKey: dataSourceConfirmedKey) }
    }

    public func validateImportPath(_ path: String) -> ValidationResult {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .directoryNotFound
        }

        guard !isDirectory.boolValue else {
            return .notDirectory
        }

        guard path.hasSuffix(".db") else {
            return .noJSONFiles
        }

        return .valid
    }

    public func resolveDatabasePath(from url: URL) -> String? {
        var isDirectory: ObjCBool = false
        let path = url.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            let candidate = url.appendingPathComponent("opencode.db").path
            return validateImportPath(candidate) == .valid ? candidate : nil
        }

        return validateImportPath(path) == .valid ? path : nil
    }

    public func ensureDataSourceReadyOnLaunch() -> Bool {
        let currentPath = importPath
        let currentValid = validateImportPath(currentPath) == .valid

        if currentValid && isDataSourceConfirmed {
            return true
        }

        if currentValid {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "确认数据来源"
            alert.informativeText = "当前数据来源路径：\n\(currentPath)\n\n是否使用该路径继续？"
            alert.addButton(withTitle: "确认并继续")
            alert.addButton(withTitle: "选择其他路径")
            alert.addButton(withTitle: "退出")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                isDataSourceConfirmed = true
                return true
            }
            if response == .alertThirdButtonReturn {
                return false
            }
        } else {
            showInvalidPathAlert(currentPath)
        }

        guard let selectedPath = selectDataSourcePathInteractively(initialPath: currentPath) else {
            return false
        }
        importPath = selectedPath
        isDataSourceConfirmed = true
        return true
    }

    public func selectDataSourcePathInteractively(initialPath: String? = nil) -> String? {
        while true {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.showsHiddenFiles = true
            panel.canCreateDirectories = false
            panel.title = "选择 OpenCode 数据来源"
            panel.message = "请选择 opencode.db 文件，或包含该文件的目录"
            panel.prompt = "选择"

            if let initialPath {
                panel.directoryURL = URL(fileURLWithPath: initialPath).deletingLastPathComponent()
            } else {
                panel.directoryURL = URL(fileURLWithPath: defaultImportPath).deletingLastPathComponent()
            }

            let result = panel.runModal()
            guard result == .OK, let url = panel.url else { return nil }

            if let resolved = resolveDatabasePath(from: url) {
                return resolved
            }

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "无效的数据来源"
            alert.informativeText = "请选择 opencode.db 文件，或包含 opencode.db 的目录。"
            alert.addButton(withTitle: "重新选择")
            alert.addButton(withTitle: "取消")
            let retry = alert.runModal()
            if retry != .alertFirstButtonReturn {
                return nil
            }
        }
    }

    private func showInvalidPathAlert(_ path: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "数据来源路径不可用"
        alert.informativeText = "当前路径无效：\n\(path)\n\n请重新选择数据来源。"
        alert.addButton(withTitle: "继续")
        alert.runModal()
    }

    public func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: importPathKey)
        UserDefaults.standard.removeObject(forKey: dataSourceConfirmedKey)
    }
}
