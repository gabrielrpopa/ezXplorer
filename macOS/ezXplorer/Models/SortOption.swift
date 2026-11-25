import Foundation

enum SortField: String, CaseIterable, Identifiable {
    case name = "Name"
    case fileExtension = "Ext"
    case size = "Size"
    case date = "Modified"

    var id: String { rawValue }
}

enum PaneSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var opposite: PaneSide {
        self == .left ? .right : .left
    }

    var displayName: String {
        self == .left ? "Left Pane" : "Right Pane"
    }
}

enum LayoutMode: String, CaseIterable, Identifiable {
    case dualPane = "Dual Pane (Commander)"
    case singlePane = "Single Pane (Explorer)"

    var id: String { rawValue }
}

enum CompareStatus: Equatable {
    case none
    case unique
    case newer
}
