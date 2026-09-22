import Foundation
import Combine

@MainActor
final class ApprovalsStore: ObservableObject {
    @Published var items: [ApprovalItem] = []
    @Published var generatedDate: Date?
    @Published var loadError: String?

    private let stateURL: URL
    private var timer: Timer?

    static let staleThreshold: TimeInterval = 2 * 60 * 60 // 2 hours

    init() {
        stateURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("approvals-widget/state.json")
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    var isStale: Bool {
        guard let generatedDate else { return true }
        return Date().timeIntervalSince(generatedDate) > Self.staleThreshold
    }

    var statusLabel: String {
        if isStale { return "⏳ ?" }
        return items.isEmpty ? "⏳" : "⏳ \(items.count)"
    }

    func reload() {
        do {
            let data = try Data(contentsOf: stateURL)
            let decoded = try JSONDecoder().decode(ApprovalsState.self, from: data)
            self.items = decoded.items
            self.generatedDate = decoded.generatedDate
            self.loadError = nil
        } catch {
            self.loadError = "no data yet: \(error.localizedDescription)"
        }
    }
}
