import Foundation

struct ApprovalItem: Codable, Identifiable {
    let source: String
    let id: String
    let title: String
    let amount: Double?
    let currency: String?
    let createdAt: String
    let detail: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case source, id, title, amount, currency, detail, url
        case createdAt = "created_at"
    }

    var createdDate: Date? {
        ApprovalItem.isoFormatter.date(from: createdAt)
            ?? ApprovalItem.isoFormatterFractional.date(from: createdAt)
    }

    var link: URL? {
        guard let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    var sourceLabel: String {
        switch source {
        case "campfire_invoice", "campfire_bill", "campfire_draft", "campfire": return "Campfire"
        case "netsuite_je": return "NetSuite"
        case "ramp_bill", "ramp_reimbursement": return "Ramp"
        default: return source.capitalized
        }
    }

    /// Coarser grouping used for the tab filter (NetSuite / Ramp / Campfire).
    var group: String {
        switch source {
        case "campfire_invoice", "campfire_bill", "campfire_draft", "campfire": return "Campfire"
        case "netsuite_je": return "NetSuite"
        case "ramp_bill", "ramp_reimbursement": return "Ramp"
        default: return "Other"
        }
    }

    var kindLabel: String {
        switch source {
        case "ramp_bill": return "Bill"
        case "ramp_reimbursement": return "Reimbursement"
        case "netsuite_je": return "Journal Entry"
        case "campfire_invoice": return "Invoice"
        case "campfire_bill": return "Bill"
        case "campfire_draft", "campfire": return "Draft"
        default: return source
        }
    }

    var formattedAmount: String {
        guard let amount else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency ?? "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    func age(now: Date) -> String {
        guard let created = createdDate else { return "?" }
        let seconds = max(0, now.timeIntervalSince(created))
        let days = Int(seconds / 86400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let isoFormatterFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

struct ApprovalsState: Codable {
    let generatedAt: String
    let items: [ApprovalItem]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case items
    }

    var generatedDate: Date? {
        ApprovalItem.isoFormatter.date(from: generatedAt)
    }
}
