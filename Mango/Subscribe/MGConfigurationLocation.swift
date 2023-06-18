import Foundation

@frozen
public enum MGConfigurationLocation: String, CaseIterable, Identifiable, CustomStringConvertible {
    
    public var id: Self { self }
    
    case local, remote
    
    public var description: String {
        switch self {
        case .local:
            return "Local"
        case .remote:
            return "Remotely"
        }
    }
}
