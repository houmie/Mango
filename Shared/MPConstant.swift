import Foundation
import UniformTypeIdentifiers

@frozen public enum MPConstant {}

extension MPConstant {
    public static let suiteName = "group.\(Bundle.appID)"
}

extension Bundle {
    public static var appID: String {
        Bundle.main.infoDictionary?["APP_ID"] as! String
    }
}

extension UTType {
    public static let yaml: UTType = UTType(__UTTypeYAML.identifier)!
}

extension UserDefaults {
    public static let shared: UserDefaults = UserDefaults(suiteName: MPConstant.suiteName)!
}
