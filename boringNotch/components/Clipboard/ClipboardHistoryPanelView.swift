//
//  ClipboardHistoryPanelView.swift
//  boringNotch
//

import AppKit
import Defaults
import Sparkle
import SwiftUI

struct ClipboardHistoryPanelView: View {
    @ObservedObject private var viewModel = ClipboardHistoryViewModel.shared
    @Default(.clipboardHistoryEnabled) private var historyEnabled
    @Default(.clipboardHistoryShowSourceApps) private var showSourceApps
    @Default(.useCustomAccentColor) private var useCustomAccentColor
    @Default(.customAccentColorData) private var customAccentColorData

    let updater: SPUUpdater?

    init(updater: SPUUpdater? = nil) {
        self.updater = updater
    }

    var body: some View {
        ZStack {
            ClipboardPanelBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                if historyEnabled {
                    activeContent
                } else {
                    ClipboardOnboardingView {
                        viewModel.enableHistory()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }

                footer
            }
        }
        .frame(width: 430, height: 580)
        .effectiveAccentColor(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        )
        .onAppear {
            viewModel.start()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 18, height: 18)

                Text("Clipboard")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)

                HStack(spacing: 5) {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(viewModel.statusText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if historyEnabled {
                    Button {
                        viewModel.toggleUserPaused()
                    } label: {
                        Image(systemName: viewModel.isUserPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(viewModel.isUserPaused ? "Resume clipboard history" : "Pause clipboard history")
                }
            }

            if historyEnabled {
                ClipboardSearchField(text: $viewModel.searchText)
                ClipboardFilterTabs(selection: $viewModel.selectedFilter)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var activeContent: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                ClipboardEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 18)
            } else if viewModel.visibleItems.isEmpty {
                ClipboardNoResultsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 18)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.sections) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.caption2.weight(.semibold))
                                    .textCase(.uppercase)
                                    .tracking(0.4)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)

                                ForEach(section.items) { item in
                                    ClipboardHistoryRow(
                                        item: item,
                                        image: viewModel.thumbnail(for: item),
                                        sourceIcon: showSourceApps ? viewModel.sourceIcon(for: item) : nil,
                                        isCopied: viewModel.copiedItemID == item.id,
                                        onCopy: { viewModel.copy(item) },
                                        onPin: { viewModel.togglePinned(item) },
                                        onDelete: { viewModel.remove(item) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(.separator)

            HStack(spacing: 10) {
                Text("\(viewModel.items.count) items")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(viewModel.storageText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                if historyEnabled && !viewModel.items.isEmpty {
                    Button("Clear") {
                        viewModel.clear()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.caption.weight(.semibold))
                }

                Button {
                    SettingsWindowController.shared.showWindow()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .help("Settings")

                Menu {
                    if let updater {
                        CheckForUpdatesView(updater: updater)
                        Divider()
                    }
                    Button("Restart minitap") {
                        ApplicationRelauncher.restart()
                    }
                    Button("Quit", role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }
}

private struct ClipboardPanelBackground: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.18))
        .ignoresSafeArea()
    }
}

private struct ClipboardSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search history", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ClipboardFilterTabs: View {
    @Binding var selection: ClipboardHistoryFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ClipboardHistoryFilter.allCases) { filter in
                filterButton(filter)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.045), in: Capsule())
        .frame(height: 26)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard filter")
    }

    private func filterButton(_ filter: ClipboardHistoryFilter) -> some View {
        let isSelected = selection == filter

        return Button {
            selection = filter
        } label: {
            Text(filter.label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(width: 58, height: 22)
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
                .background(isSelected ? Color.effectiveAccent : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(filter.label)
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    let image: NSImage?
    let sourceIcon: NSImage?
    let isCopied: Bool
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onCopy) {
                HStack(alignment: .center, spacing: 10) {
                    thumbnail
                    textContent
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            rowActions
                .opacity(isHovering || isCopied ? 1 : 0)
                .animation(.smooth(duration: 0.16), value: isHovering)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Copies this item back to the clipboard")
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.previewTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(item.kind == .text ? 2 : 1)
                    .multilineTextAlignment(.leading)

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.effectiveAccent)
                }

                if isCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 5) {
                if let sourceIcon {
                    Image(nsImage: sourceIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }

                Text(metadataLine)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))

            if item.kind == .image, let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 42, height: 42)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var rowActions: some View {
        HStack(spacing: 6) {
            Button(action: onPin) {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.isPinned ? Color.effectiveAccent : Color.primary.opacity(0.58))
            .help(item.isPinned ? "Unpin" : "Pin")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
    }

    private var rowBackground: some ShapeStyle {
        if isCopied {
            return AnyShapeStyle(Color.green.opacity(0.10))
        }
        if isHovering {
            return AnyShapeStyle(Color.primary.opacity(0.045))
        }
        return AnyShapeStyle(Color.clear)
    }

    private var rowStrokeColor: Color {
        if isCopied {
            return Color.green.opacity(0.18)
        }
        if isHovering {
            return Color.primary.opacity(0.08)
        }
        return Color.clear
    }

    private var metadataLine: String {
        "\(item.detailText) • \(sourceLine)"
    }

    private var sourceLine: String {
        let app = item.sourceAppName ?? "Unknown app"
        let relative = RelativeDateTimeFormatter.clipboardFormatter.localizedString(for: item.createdAt, relativeTo: Date())
        return "\(app) • \(relative)"
    }

    private var accessibilityLabel: String {
        "\(item.kind.label), \(item.previewTitle), \(sourceLine)"
    }
}

private struct ClipboardOnboardingView: View {
    let onEnable: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            ZStack {
                Circle()
                    .fill(Color.effectiveAccent.opacity(0.16))
                    .frame(width: 118, height: 118)
                    .blur(radius: 18)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(width: 92, height: 92)
                    .overlay(
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Color.effectiveAccent)
                    )
            }

            VStack(spacing: 8) {
                Text("Your clipboard, beautifully remembered")
                    .font(MinitapBrand.Fonts.heading(size: 24))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("minitap can save copied text and real image data, then bring it back with one click from the menu bar.")
                    .font(MinitapBrand.Fonts.body(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                ClipboardPrivacyPoint(icon: "lock.shield", text: "Opt-in only. Nothing is recorded until you enable it.")
                ClipboardPrivacyPoint(icon: "eye.slash", text: "Private and transient pasteboard items are skipped.")
                ClipboardPrivacyPoint(icon: "photo", text: "Images are stored locally as bounded PNG history.")
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(action: onEnable) {
                Text("Enable Clipboard History")
                    .font(MinitapBrand.Fonts.body(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.effectiveAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 6)
        }
    }
}

private struct ClipboardPrivacyPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: 18)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

private struct ClipboardEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 74, height: 74)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text("Copy something")
                .font(.system(size: 20, weight: .semibold, design: .default))
                .foregroundStyle(.primary)
            Text("Text and screenshots you copy from now on will appear here.")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ClipboardNoResultsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No matches")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Try another search or filter.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private extension RelativeDateTimeFormatter {
    static let clipboardFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

#Preview {
    ClipboardHistoryPanelView()
}
