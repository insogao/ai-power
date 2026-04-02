import AppKit
import SwiftUI

struct MenuBarView: View {
    private static let discoverCarouselInterval: Duration = .seconds(5)

    @ObservedObject var model: AppModel
    @State private var dragSelection: WakeTrackSelection?
    @State private var isDragging = false
    @State private var optionsExpanded = false
    @State private var discoverExpanded = false
    @State private var discoverCardIndex = 0
    @State private var discoverCarouselRevision = 0
    @State private var isHoveringDiscoverCard = false
    @State private var monitorsExpanded = false
    @State private var debugExpanded = false
    @State private var monitorsEditing = false
    @State private var customKeywordInput = ""
    @State private var customPortInput = ""
    @State private var monitorFeedback: String?

    var body: some View {
        let contentSelection = MenuBarSelectionPresentation.contentSelection(
            committedSelection: model.currentTrackSelection,
            previewSelection: displaySelection,
            isDragging: isDragging
        )
        let contentPresentation = MenuBarContentPresentation.make(
            selection: contentSelection,
            activityBadges: model.activityBadges,
            builtInSummaryText: model.builtInToolsSummaryText
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("AI Power")
                    .font(.headline)

                Spacer()

                Text(model.buildVersionText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                if let remainingText = model.remainingText, isDragging == false {
                    Text(remainingText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.16)))
                }
            }

            if let permissionCard = model.permissionCard {
                PermissionCardView(card: permissionCard) {
                    model.performPermissionCardAction()
                }
            }

            HStack {
                Text(selectionBadgeText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(selectionBadgeColor))
                Spacer()
            }

            WakeTrackControl(
                selection: displaySelection,
                isDragging: isDragging,
                onSelectionChanged: { selection in
                    dragSelection = selection
                    isDragging = true
                },
                onSelectionCommitted: { selection in
                    dragSelection = nil
                    isDragging = false
                    model.applyTrackSelection(selection)
                }
            )
            .frame(width: 320, height: 74)

            if let primaryText = contentPresentation.primaryText {
                Text(primaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.primaryStatusText)
                    .font(.body.weight(.medium))
            }

            if contentPresentation.primaryText == nil, let secondaryStatusText = model.secondaryStatusText {
                Text(secondaryStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if contentPresentation.showsActivityBadges {
                ActivityBadgeRow(badges: model.activityBadges)
            } else if contentPresentation.showsBuiltInSummary {
                BuiltInToolsSummaryPill(text: model.builtInToolsSummaryText)
            }

            ExpandableSection(title: "Options", isExpanded: $optionsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        "Prevent Computer Sleep",
                        isOn: Binding(
                            get: { model.wakeControlOptions.preventComputerSleep },
                            set: { model.setPreventComputerSleep($0) }
                        )
                    )

                    Toggle(
                        "Prevent Display Dimming",
                        isOn: Binding(
                            get: { model.wakeControlOptions.preventDisplaySleep },
                            set: { model.setPreventDisplaySleep($0) }
                        )
                    )

                    Toggle(
                        "Prevent Lock Screen",
                        isOn: Binding(
                            get: { model.wakeControlOptions.preventLockScreen },
                            set: { model.setPreventLockScreen($0) }
                        )
                    )

                    HStack {
                        Text("AI Idle Grace")
                        Spacer()
                        Picker(
                            "AI Idle Grace",
                            selection: Binding(
                                get: { model.wakeControlOptions.aiIdleGraceMinutes },
                                set: { model.setAIIdleGraceMinutes($0) }
                            )
                        ) {
                            ForEach(AppModel.aiIdleGraceMinuteOptions, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 92)
                    }

                    Text(model.aiIdleGraceDescriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("AI Network Threshold")
                        Spacer()
                        Text(model.aiNetworkThresholdSummaryText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(model.aiNetworkThresholdDescriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    MonitoredNetworkSparklineCard(
                        values: model.monitoredNetworkSparklineValues,
                        selectedThresholdKilobytes: model.wakeControlOptions.aiNetworkThresholdKilobytes,
                        scaleLabel: model.monitoredTrafficScaleText,
                        canIncreaseThreshold: model.canIncreaseAINetworkThreshold,
                        canDecreaseThreshold: model.canDecreaseAINetworkThreshold,
                        increaseThreshold: { model.increaseAINetworkThresholdKilobytes() },
                        decreaseThreshold: { model.decreaseAINetworkThresholdKilobytes() }
                    )

                    if model.wakeControlOptions.preventLockScreen {
                        Text("Best effort. macOS security settings may still lock the session.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)

            ExpandableSection(
                title: "Monitors",
                trailingText: model.monitorsSummaryText,
                isExpanded: $monitorsExpanded
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    monitorSection(
                        title: "Applications",
                        items: model.effectiveMonitoredApplications.map {
                            MonitorItem(
                                id: "app-\($0)-\(model.customProcessKeywords.contains($0) ? "custom" : "built-in")",
                                label: $0,
                                isCustom: model.customProcessKeywords.contains($0)
                            )
                        },
                        placeholder: "Add application",
                        input: $customKeywordInput,
                        onEditToggle: {
                            monitorsEditing.toggle()
                        },
                        onRemove: { item in
                            guard item.isCustom else { return }
                            if model.removeCustomKeyword(item.label) {
                                monitorFeedback = "Application removed"
                            }
                        }
                    ) {
                        let added = model.addCustomKeyword(customKeywordInput)
                        if added {
                            customKeywordInput = ""
                            monitorFeedback = "Application added"
                        } else {
                            monitorFeedback = "Application already exists or is invalid"
                        }
                    }

                    monitorSection(
                        title: "Ports",
                        items: model.effectiveMonitoredPorts.map {
                            MonitorItem(
                                id: "port-\($0)-\(model.customMonitoredPorts.contains($0) ? "custom" : "built-in")",
                                label: String($0),
                                isCustom: model.customMonitoredPorts.contains($0)
                            )
                        },
                        placeholder: "Add port",
                        input: $customPortInput,
                        onEditToggle: {
                            monitorsEditing.toggle()
                        },
                        onRemove: { item in
                            guard item.isCustom, let port = Int(item.label) else { return }
                            if model.removeCustomPort(port) {
                                monitorFeedback = "Port removed"
                            }
                        }
                    ) {
                        let added = model.addCustomPort(customPortInput)
                        if added {
                            customPortInput = ""
                            monitorFeedback = "Port added"
                        } else {
                            monitorFeedback = "Port is invalid or already exists"
                        }
                    }

                    if let monitorFeedback {
                        Text(monitorFeedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)

            if model.isDiscoverVisible, let discoverCard = discoverCard {
                DiscoverSection(
                    isExpanded: $discoverExpanded
                ) {
                    DiscoverCardSection(
                        card: discoverCard,
                        showsPaging: model.discoverCards.count > 1,
                        onPrevious: { showPreviousDiscoverCard() },
                        onNext: { showNextDiscoverCard() }
                    )
                    .onHover { hovering in
                        isHoveringDiscoverCard = hovering
                        if hovering == false {
                            restartDiscoverCarousel()
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.caption)
            }

            ExpandableSection(title: "Debug", isExpanded: $debugExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Version: \(model.buildVersionText)")
                    Text("Helper: \(model.helperStatusText)")
                    Text("Environment: \(model.environmentSummary)")
                    Text("Capability: \(model.effectiveCapabilityText)")
                    if let debugLogPath = model.debugLogPath {
                        Text("Debug Log: \(debugLogPath)")
                    }
                    ForEach(model.statusLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .font(.caption)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 344)
        .onAppear {
            model.panelDidOpen()
        }
        .onChange(of: model.discoverDefaultExpanded) { _, newValue in
            discoverExpanded = newValue
        }
        .onChange(of: model.discoverCards.count) { _, newValue in
            if newValue == 0 {
                discoverCardIndex = 0
            } else {
                discoverCardIndex = min(discoverCardIndex, newValue - 1)
            }
            restartDiscoverCarousel()
        }
        .onChange(of: discoverExpanded) { _, _ in
            restartDiscoverCarousel()
        }
        .task(id: discoverCarouselTaskKey) {
            guard DiscoverCarouselBehavior.shouldAutoRotate(
                isExpanded: discoverExpanded,
                cardCount: model.discoverCards.count,
                isHovering: isHoveringDiscoverCard
            ) else {
                return
            }

            try? await Task.sleep(for: Self.discoverCarouselInterval)

            guard Task.isCancelled == false else {
                return
            }

            guard DiscoverCarouselBehavior.shouldAutoRotate(
                isExpanded: discoverExpanded,
                cardCount: model.discoverCards.count,
                isHovering: isHoveringDiscoverCard
            ) else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                showNextDiscoverCard(manual: false)
            }
        }
    }

    private var displaySelection: WakeTrackSelection {
        dragSelection ?? model.currentTrackSelection
    }

    private var discoverCarouselTaskKey: String {
        [
            discoverExpanded ? "expanded" : "collapsed",
            "count-\(model.discoverCards.count)",
            isHoveringDiscoverCard ? "hovering" : "idle",
            "revision-\(discoverCarouselRevision)",
        ].joined(separator: "-")
    }

    private var discoverCard: DiscoverCard? {
        guard model.discoverCards.isEmpty == false else {
            return nil
        }

        let safeIndex = min(max(discoverCardIndex, 0), model.discoverCards.count - 1)
        return model.discoverCards[safeIndex]
    }

    private var selectionBadgeText: String {
        if isDragging {
            return displaySelection.label
        }

        return model.selectionBadgeText
    }

    private var selectionBadgeColor: Color {
        switch displaySelection {
        case .aiMode:
            return Color.blue.opacity(0.24)
        case .off:
            return Color.black.opacity(0.14)
        case .infinity:
            return Color.orange.opacity(0.24)
        case .timed:
            return Color.green.opacity(0.22)
        }
    }

    private func showPreviousDiscoverCard(manual: Bool = true) {
        guard model.discoverCards.isEmpty == false else {
            return
        }

        discoverCardIndex = (discoverCardIndex - 1 + model.discoverCards.count) % model.discoverCards.count
        if manual {
            restartDiscoverCarousel()
        }
    }

    private func showNextDiscoverCard(manual: Bool = true) {
        guard model.discoverCards.isEmpty == false else {
            return
        }

        discoverCardIndex = DiscoverCarouselBehavior.nextIndex(
            currentIndex: discoverCardIndex,
            cardCount: model.discoverCards.count
        )
        if manual {
            restartDiscoverCarousel()
        }
    }

    private func restartDiscoverCarousel() {
        discoverCarouselRevision += 1
    }

    private func monitorSection(
        title: String,
        items: [MonitorItem],
        placeholder: String,
        input: Binding<String>,
        onEditToggle: @escaping () -> Void,
        onRemove: @escaping (MonitorItem) -> Void,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))

                Spacer()

                Button(monitorsEditing ? "Done" : "Edit", action: onEditToggle)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 6) {
                ForEach(items) { item in
                    MonitorItemChip(
                        item: item,
                        isEditing: monitorsEditing,
                        onRemove: { onRemove(item) }
                    )
                }
            }

            HStack(spacing: 6) {
                TextField(placeholder, text: input)
                    .textFieldStyle(.roundedBorder)

                Button("Add", action: onAdd)
                    .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }
}

private struct MonitoredNetworkSparklineCard: View {
    let values: [Double]
    let selectedThresholdKilobytes: Int
    let scaleLabel: String
    let canIncreaseThreshold: Bool
    let canDecreaseThreshold: Bool
    let increaseThreshold: () -> Void
    let decreaseThreshold: () -> Void

    private var presentation: MonitoredTrafficChartPresentation {
        MonitoredTrafficChartPresentation(
            valuesInKilobytes: values,
            selectedThresholdKilobytes: selectedThresholdKilobytes
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last hour monitored traffic")
                .font(.caption.weight(.semibold))

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    thresholdButton(
                        systemImage: "chevron.up",
                        enabled: canIncreaseThreshold,
                        action: increaseThreshold
                    )

                    VStack(spacing: 0) {
                        Text("\(selectedThresholdKilobytes)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                        Text("KB")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 34)

                    thresholdButton(
                        systemImage: "chevron.down",
                        enabled: canDecreaseThreshold,
                        action: decreaseThreshold
                    )
                }
                .frame(width: 38)

                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.04))

                    if values.isEmpty {
                        Text("Traffic history will appear after AI Power observes monitored network activity.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(10)
                    } else {
                        ZStack {
                            MonitoredTrafficThresholdLine(guide: presentation.thresholdGuideLine)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)

                            MonitoredNetworkSparkline(values: presentation.normalizedValues)
                                .stroke(Color.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .frame(height: 54)
            }

            MonitoredTrafficTimeRuler(labels: presentation.timeAxisLabels)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }

    private func thresholdButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 14)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.45))
        .disabled(enabled == false)
    }
}

private struct MonitoredNetworkSparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else {
            return Path()
        }

        let stepX = rect.width / CGFloat(max(values.count - 1, 1))

        func point(at index: Int) -> CGPoint {
            let normalized = min(max(values[index], 0), 1)
            let x = rect.minX + CGFloat(index) * stepX
            let y = rect.maxY - CGFloat(normalized) * rect.height
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        path.move(to: point(at: 0))
        for index in 1..<values.count {
            path.addLine(to: point(at: index))
        }
        return path
    }
}

private struct MonitoredTrafficThresholdLine: View {
    let guide: MonitoredTrafficChartPresentation.GuideLine?

    var body: some View {
        GeometryReader { geometry in
            if let guide {
                let y = max(0, min(1, 1 - guide.normalizedY)) * geometry.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.black.opacity(0.42), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MonitoredTrafficTimeRuler: View {
    let labels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 2, height: 6)

                    Text(labels[index])
                        .font(.caption2.weight(.regular))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }
}

private struct DiscoverSection<Content: View>: View {
    @Binding var isExpanded: Bool
    let content: Content

    init(
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text("Discover")
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if isExpanded {
                content
            }
        }
    }
}

private struct DiscoverCardSection: View {
    let card: DiscoverCard
    let showsPaging: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsPaging {
                        HStack(spacing: 8) {
                            Button(action: onPrevious) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Button(action: onNext) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(card.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Link(destination: card.destinationURL!) {
                HStack(spacing: 6) {
                    Text(card.ctaText)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.cyan)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

enum DiscoverCarouselBehavior {
    static func shouldAutoRotate(isExpanded: Bool, cardCount: Int, isHovering: Bool = false) -> Bool {
        isExpanded && cardCount > 1 && isHovering == false
    }

    static func nextIndex(currentIndex: Int, cardCount: Int) -> Int {
        guard cardCount > 1 else {
            return 0
        }

        return (currentIndex + 1) % cardCount
    }
}

struct MenuBarSelectionPresentation {
    static func contentSelection(
        committedSelection: WakeTrackSelection,
        previewSelection: WakeTrackSelection,
        isDragging: Bool
    ) -> WakeTrackSelection {
        isDragging ? committedSelection : previewSelection
    }
}

struct MenuBarContentPresentation: Equatable {
    let primaryText: String?
    let showsBuiltInSummary: Bool
    let showsActivityBadges: Bool

    static func make(
        selection: WakeTrackSelection,
        activityBadges: [ActivityBadge],
        builtInSummaryText: String
    ) -> MenuBarContentPresentation {
        if selection == .off {
            return MenuBarContentPresentation(
                primaryText: "Move the control to AI Mode or a time slot to start keeping your Mac awake.",
                showsBuiltInSummary: false,
                showsActivityBadges: false
            )
        }

        switch selection {
        case .timed, .infinity:
            return MenuBarContentPresentation(
                primaryText: nil,
                showsBuiltInSummary: false,
                showsActivityBadges: false
            )
        case .aiMode, .off:
            break
        }

        if activityBadges.isEmpty == false {
            return MenuBarContentPresentation(
                primaryText: nil,
                showsBuiltInSummary: false,
                showsActivityBadges: true
            )
        }

        return MenuBarContentPresentation(
            primaryText: nil,
            showsBuiltInSummary: builtInSummaryText.isEmpty == false,
            showsActivityBadges: false
        )
    }
}

private struct MonitorItem: Identifiable, Equatable {
    let id: String
    let label: String
    let isCustom: Bool
}

private struct ExpandableSection<Content: View>: View {
    let title: String
    let trailingText: String?
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        trailingText: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailingText = trailingText
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)

                    Text(title)

                    Spacer()

                    if let trailingText {
                        Text(trailingText)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
    }
}

private struct BuiltInToolsSummaryPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cyan.opacity(0.92))

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.cyan.opacity(0.07))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ActivityBadgeRow: View {
    let badges: [ActivityBadge]

    var body: some View {
        let presentation = ActivityBadgePresentation.make(from: badges, maxVisible: 3)

        return HStack(spacing: 8) {
            ForEach(presentation.visibleBadges) { badge in
                ActivityBadgeView(badge: badge)
            }

            if presentation.overflowCount > 0 {
                OverflowBadgeView(count: presentation.overflowCount)
            }
        }
    }
}

struct ActivityBadgePresentation {
    let visibleBadges: [ActivityBadge]
    let overflowCount: Int

    static func make(from badges: [ActivityBadge], maxVisible: Int) -> ActivityBadgePresentation {
        guard maxVisible >= 0 else {
            return ActivityBadgePresentation(visibleBadges: [], overflowCount: badges.count)
        }

        let visibleBadges = Array(badges.prefix(maxVisible))
        let overflowCount = max(badges.count - visibleBadges.count, 0)
        return ActivityBadgePresentation(visibleBadges: visibleBadges, overflowCount: overflowCount)
    }
}

private struct OverflowBadgeView: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        _FlowLayout(spacing: spacing) {
            content
        }
    }
}

private struct _FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct MonitorItemChip: View {
    let item: MonitorItem
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(item.label)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            if isEditing && item.isCustom {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(item.isCustom ? Color.blue.opacity(0.10) : Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(item.isCustom ? Color.blue.opacity(0.16) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ActivityBadgeView: View {
    let badge: ActivityBadge

    var body: some View {
        HStack(spacing: 6) {
            if let image = resolvedIcon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else if badge.label.hasPrefix("port ") {
                Image(systemName: "network")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.9))
            }

            Text(displayLabel)
                .font(.caption.weight(.medium))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var displayLabel: String {
        if badge.label.hasPrefix("port ") {
            return badge.label
        }
        return badge.label.capitalized
    }

    private var resolvedIcon: NSImage? {
        for bundleIdentifier in ActivityBadgeIconResolver.bundleIdentifiers(for: badge.label) {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return NSWorkspace.shared.icon(forFile: appURL.path)
            }
        }
        return nil
    }
}

enum ActivityBadgeIconResolver {
    static func bundleIdentifiers(for label: String) -> [String] {
        switch label {
        case "codex":
            return ["com.openai.codex"]
        case "vscode":
            return ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"]
        case "cursor":
            return ["com.todesktop.230313mzl4w4u92"]
        case "windsurf":
            return ["com.exafunction.windsurf"]
        case "zed":
            return ["dev.zed.Zed"]
        case "kiro":
            return ["com.kiro.desktop"]
        case "kimi":
            return ["com.moonshot.kimi"]
        default:
            return []
        }
    }
}

private struct PermissionCardView: View {
    let card: PermissionActionCard
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                WarningOrbitIcon(size: 13)

                Text(card.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()
            }

            Text(card.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(card.actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.13),
                            Color.red.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct WakeTrackControl: View {
    let selection: WakeTrackSelection
    let isDragging: Bool
    let onSelectionChanged: (WakeTrackSelection) -> Void
    let onSelectionCommitted: (WakeTrackSelection) -> Void

    private let layout = WakeTrackLayout.default
    @State private var dragNormalizedPosition: Double?
    @State private var activeSnapZone: WakeTrackLayout.SnapZone?
    @State private var dragResetToken = UUID()

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knobX = width * effectiveKnobPosition

            ZStack(alignment: .leading) {
                trackBackground(width: width)

                tickMarks(width: width)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.76, green: 0.84, blue: 0.96).opacity(0.58),
                                Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.36),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: layout.knobOuterDiameter, height: layout.knobOuterDiameter)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.86, green: 0.92, blue: 1.0).opacity(0.96), lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .fill(Color(red: 0.94, green: 0.97, blue: 1.0).opacity(0.98))
                            .frame(width: layout.knobInnerDiameter, height: layout.knobInnerDiameter)
                    )
                    .shadow(color: Color(red: 0.38, green: 0.52, blue: 0.72).opacity(0.22), radius: 6, y: 2)
                    .position(x: knobX, y: layout.knobCenterY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalized = max(0, min(1, value.location.x / max(width, 1)))
                        dragNormalizedPosition = normalized
                        activeSnapZone = layout.snapZone(forNormalizedPosition: normalized)
                        onSelectionChanged(layout.selection(forNormalizedPosition: normalized))
                    }
                    .onEnded { value in
                        let normalized = max(0, min(1, value.location.x / max(width, 1)))
                        let committed = layout.selection(forNormalizedPosition: normalized)
                        let token = UUID()
                        dragResetToken = token
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                            dragNormalizedPosition = layout.position(for: committed)
                            activeSnapZone = layout.snapZone(forNormalizedPosition: normalized)
                        }
                        onSelectionCommitted(committed)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            guard dragResetToken == token else {
                                return
                            }
                            dragNormalizedPosition = nil
                            activeSnapZone = nil
                        }
                    }
            )
        }
    }

    private func trackBackground(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.09),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: layout.trackThickness)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .position(x: width / 2, y: layout.trackCenterY)

            if let activeSnapZone {
                zoneGlow(for: activeSnapZone, width: width)
                    .transition(.opacity)
            }

            ForEach(boundaryPositions, id: \.self) { position in
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 2, height: layout.trackThickness - 4)
                    .position(x: width * position, y: layout.trackCenterY)
            }
        }
    }

    private func tickMarks(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            ForEach(layout.ticks, id: \.title) { mark in
                tick(mark.title, at: mark.position, width: width)
            }

            tick("∞", at: layout.infinityLabelPosition, width: width)
        }
    }

    private func tick(_ title: String, at position: Double, width: CGFloat, showsStem: Bool = true) -> some View {
        let emphasized = emphasizedTickTitle == title

        return VStack(spacing: 5) {
            if showsStem {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1, height: 8)
            }
            Text(title)
                .font(emphasized ? .caption.weight(.semibold) : .caption2)
                .foregroundStyle(emphasized ? Color.primary.opacity(0.92) : .secondary)
                .padding(.horizontal, emphasized ? 8 : 0)
                .padding(.vertical, emphasized ? 3 : 0)
                .background(
                    Capsule(style: .continuous)
                        .fill(emphasized ? emphasisColor(for: title) : .clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(emphasized ? emphasisStrokeColor(for: title) : .clear, lineWidth: 1)
                )
                .shadow(color: emphasized ? emphasisColor(for: title).opacity(0.32) : .clear, radius: 8, y: 0)
        }
        .position(x: width * position, y: layout.tickY)
        .animation(.easeOut(duration: 0.16), value: emphasizedTickTitle)
    }

    private var boundaryPositions: [Double] {
        [layout.aiRange.upperBound, layout.offRange.upperBound, layout.infinitySnapStart]
    }

    private var effectiveKnobPosition: Double {
        dragNormalizedPosition ?? layout.position(for: selection)
    }

    private var emphasizedTickTitle: String? {
        switch selection {
        case .aiMode:
            return "AI"
        case .off:
            return "Off"
        case .infinity:
            return "∞"
        case let .timed(duration):
            let timedTicks = layout.ticks.filter { $0.title != "AI" && $0.title != "Off" }
            let selectionPosition = layout.position(for: .timed(duration: duration))
            return timedTicks.min { lhs, rhs in
                abs(lhs.position - selectionPosition) < abs(rhs.position - selectionPosition)
            }?.title
        }
    }

    private func zoneGlow(for zone: WakeTrackLayout.SnapZone, width: CGFloat) -> some View {
        let frame: (x: CGFloat, w: CGFloat, color: Color) = {
            switch zone {
            case .ai:
                return (
                    x: width * layout.aiCenter,
                    w: width * (layout.aiRange.upperBound - layout.aiRange.lowerBound),
                    color: Color.cyan.opacity(0.24)
                )
            case .off:
                return (
                    x: width * layout.offCenter,
                    w: width * (layout.offRange.upperBound - layout.offRange.lowerBound),
                    color: Color.white.opacity(0.16)
                )
            case .infinity:
                return (
                    x: width * layout.infinityAnchor,
                    w: width * 0.14,
                    color: Color.orange.opacity(0.26)
                )
            }
        }()

        return Capsule()
            .fill(frame.color)
            .frame(width: frame.w, height: layout.trackThickness + 4)
            .blur(radius: 2.2)
            .position(x: frame.x, y: layout.trackCenterY)
            .animation(.easeOut(duration: 0.14), value: zone)
    }

    private func emphasisColor(for title: String) -> Color {
        switch title {
        case "AI":
            return Color.cyan.opacity(0.22)
        case "Off":
            return Color.gray.opacity(0.18)
        case "∞":
            return Color.orange.opacity(0.22)
        default:
            return Color.white.opacity(0.16)
        }
    }

    private func emphasisStrokeColor(for title: String) -> Color {
        switch title {
        case "AI":
            return Color.cyan.opacity(0.34)
        case "Off":
            return Color.white.opacity(0.22)
        case "∞":
            return Color.orange.opacity(0.32)
        default:
            return Color.white.opacity(0.24)
        }
    }
}
