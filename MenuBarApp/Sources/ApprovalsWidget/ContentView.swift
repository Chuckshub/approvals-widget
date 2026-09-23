import SwiftUI
import AppKit

// MARK: - Palette

private enum Glass {
    /// Coarse color for the tab bar (one dot per source group).
    static func accent(for group: String) -> Color {
        switch group {
        case "NetSuite": return Color(red: 0.35, green: 0.55, blue: 1.0)
        case "Ramp": return Color(red: 0.45, green: 0.85, blue: 0.6)
        case "Campfire": return Color(red: 1.0, green: 0.6, blue: 0.35)
        default: return .accentColor
        }
    }

    /// Fine-grained per-row color - Ramp bills and reimbursements read
    /// differently at a glance even though they share a tab.
    static func accent(forSource source: String) -> Color {
        switch source {
        case "netsuite_je": return Color(red: 0.35, green: 0.55, blue: 1.0)
        case "ramp_bill": return Color(red: 0.30, green: 0.78, blue: 0.75)       // teal
        case "ramp_reimbursement": return Color(red: 0.68, green: 0.55, blue: 1.0) // violet
        case "campfire_invoice": return Color(red: 1.0, green: 0.6, blue: 0.35)   // orange
        case "campfire_bill": return Color(red: 1.0, green: 0.45, blue: 0.45)     // coral
        case "campfire_draft", "campfire": return Color(red: 0.85, green: 0.7, blue: 0.4) // amber
        default: return .accentColor
        }
    }

    static func icon(for source: String) -> String {
        switch source {
        case "netsuite_je": return "book.closed.fill"
        case "ramp_bill": return "doc.text.fill"
        case "ramp_reimbursement": return "airplane.circle.fill"
        case "campfire_invoice": return "flame.fill"
        case "campfire_bill": return "tray.full.fill"
        case "campfire_draft", "campfire": return "flame"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @ObservedObject var store: ApprovalsStore
    @State private var now = Date()
    @State private var selectedGroup: String = "All"
    @State private var hoveredID: String?

    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var groups: [String] {
        let present = Set(store.items.map(\.group))
        return ["All", "NetSuite", "Ramp", "Campfire"].filter { $0 == "All" || present.contains($0) }
    }

    private var filteredItems: [ApprovalItem] {
        let items = selectedGroup == "All" ? store.items : store.items.filter { $0.group == selectedGroup }
        return items.sorted { ($0.createdDate ?? .distantPast) < ($1.createdDate ?? .distantPast) }
    }

    private var totalAmount: Double {
        filteredItems.reduce(0) { $0 + ($1.amount ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if groups.count > 1 { tabBar }
            if store.isStale { staleBanner }

            Divider().opacity(0.15)

            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredItems) { item in
                            ApprovalRow(item: item, now: now, isHovered: hoveredID == item.id)
                                .onHover { hovering in
                                    hoveredID = hovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
                                }
                                .onTapGesture {
                                    if let link = item.link { NSWorkspace.shared.open(link) }
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .frame(height: 360)
            }

            Divider().opacity(0.15)
            footer
        }
        .frame(width: 400)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blending: .behindWindow)
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
        )
        .onReceive(clock) { now = $0 }
        .onChange(of: store.items.count) { _ in
            if !groups.contains(selectedGroup) { selectedGroup = "All" }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.blue, .purple, .orange, .blue],
                            center: .center
                        )
                    )
                    .frame(width: 26, height: 26)
                    .opacity(0.9)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Approvals")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                if !filteredItems.isEmpty {
                    Text(totalAmount, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                withAnimation(.snappy) { store.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(groups, id: \.self) { g in
                let selected = selectedGroup == g
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selectedGroup = g }
                } label: {
                    HStack(spacing: 4) {
                        if g != "All" {
                            Circle().fill(Glass.accent(for: g)).frame(width: 5, height: 5)
                        }
                        Text(g)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        selected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear),
                        in: Capsule()
                    )
                    .foregroundStyle(selected ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    private var staleBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text("Data is stale — refresh job may not be running")
                .font(.system(size: 10.5, design: .rounded))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: store.isStale ? "wifi.slash" : "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(store.isStale ? Color.secondary : Color.green)
            Text(store.isStale ? "No data available" : "Nothing pending")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    private var footer: some View {
        HStack {
            if let gen = store.generatedDate {
                Text("Updated \(gen.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

// MARK: - Row

private struct ApprovalRow: View {
    let item: ApprovalItem
    let now: Date
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Glass.accent(forSource: item.source).opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: Glass.icon(for: item.source))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Glass.accent(forSource: item.source))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(item.kindLabel.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Glass.accent(forSource: item.source))
                    if let detail = item.detail, !detail.isEmpty {
                        Text("· \(detail)")
                            .font(.system(size: 9.5, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedAmount)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill").font(.system(size: 7.5))
                    Text(item.age(now: now))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.secondary)
            }

            if item.link != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.10 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(isHovered ? 0.14 : 0.05), lineWidth: 0.75)
        )
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Vibrancy

/// NSVisualEffectView bridge so the popover reads as native macOS glass
/// (matching the system "Liquid Glass" material) instead of a flat SwiftUI sheet.
private struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}
