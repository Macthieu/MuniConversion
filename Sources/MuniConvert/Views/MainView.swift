// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showRealConversionConfirmation = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HSplitView {
                leftPanel
                    .frame(minWidth: 360, idealWidth: 460)

                resultsZone
                    .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(minWidth: 1200, minHeight: 780)
        .environment(\.locale, viewModel.uiLocale)
        .alert(item: $viewModel.alertInfo) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(t("alert.ok")))
            )
        }
        .confirmationDialog(
            t("dialog.confirm_conversion.title"),
            isPresented: $showRealConversionConfirmation,
            titleVisibility: .visible
        ) {
            Button(t("dialog.confirm.launch"), role: .destructive) {
                viewModel.startConversion()
            }
            Button(t("dialog.confirm.cancel"), role: .cancel) {}
        } message: {
            Text(viewModel.conversionConfirmationMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t("app.title"))
                    .font(.title2.weight(.semibold))
                Text(t("app.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusPill(
                title: t("status.libreoffice"),
                value: viewModel.libreOfficeFound ? t("status.found") : t("status.not_found"),
                isGood: viewModel.libreOfficeFound
            )

            if viewModel.dryRunOnly {
                statusPill(title: t("status.mode"), value: t("status.simulation"), isGood: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var leftPanel: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    selectionZone
                    conversionZone
                    settingsZone
                }
                .frame(width: max(proxy.size.width - 1, 0), alignment: .leading)
            }
            .clipped()
        }
        .frame(maxHeight: .infinity)
    }

    private var selectionZone: some View {
        SectionCard(step: "1", title: t("section.selection")) {
            VStack(alignment: .leading, spacing: 10) {
                folderPickerRow(
                    label: t("label.source_folder"),
                    buttonTitle: t("button.choose_source_folder"),
                    pathText: viewModel.sourcePathText,
                    buttonStyle: .prominent,
                    isDisabled: false,
                    action: viewModel.chooseSourceFolder
                )

                Toggle(t("toggle.include_subdirs"), isOn: $viewModel.includeSubdirectories)
                Toggle(t("toggle.use_separate_output"), isOn: $viewModel.useSeparateOutputFolder)
                Toggle(t("toggle.preserve_tree"), isOn: $viewModel.preserveRelativeStructure)
                    .disabled(!viewModel.useSeparateOutputFolder)
                Toggle(t("toggle.dry_run"), isOn: $viewModel.dryRunOnly)
                Toggle(t("toggle.ignore_hidden"), isOn: $viewModel.ignoreHiddenFiles)

                folderPickerRow(
                    label: t("label.output_folder"),
                    buttonTitle: t("button.choose_output_folder"),
                    pathText: viewModel.outputPathText,
                    buttonStyle: .regular,
                    isDisabled: !viewModel.useSeparateOutputFolder,
                    action: viewModel.chooseOutputFolder
                )
            }
        }
    }

    private var conversionZone: some View {
        SectionCard(step: "2", title: t("section.conversion")) {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.dryRunOnly {
                    requirementBox(
                        title: t("box.simulation.title"),
                        lines: [t("box.simulation.line")],
                        color: .orange
                    )
                }

                labeledRow(label: t("label.profile_search")) {
                    TextField(t("placeholder.profile_search"), text: $viewModel.profileSearchText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                labeledRow(label: t("label.conversion_type")) {
                    Picker(t("label.conversion_type"), selection: $viewModel.selectedProfileID) {
                        if !viewModel.hasFilteredProfiles {
                            Text(t("picker.no_profile")).tag(String?.none)
                        }
                        Text(t("picker.select")).tag(String?.none)
                        ForEach(viewModel.filteredProfiles) { profile in
                            Text(profile.displayName).tag(String?.some(profile.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                labeledRow(label: t("label.collision")) {
                    Picker(t("label.collision"), selection: $viewModel.collisionPolicy) {
                        ForEach(CollisionPolicy.allCases) { policy in
                            Text(policy.compactDisplayName(language: viewModel.appLanguage)).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help(t("helper.collision_help"))
                }

                HStack(spacing: 8) {
                    Button(t("button.analyze")) {
                        viewModel.analyze()
                    }
                    .disabled(!viewModel.canAnalyze)

                    Button(t("button.start_conversion")) {
                        if viewModel.dryRunOnly {
                            viewModel.startConversion()
                        } else {
                            showRealConversionConfirmation = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartConversion)

                    Button(t("button.stop")) {
                        viewModel.stopCurrentRun()
                    }
                    .disabled(!viewModel.isRunning)
                }

                requirementBox(
                    title: t("box.profile_summary.title"),
                    lines: viewModel.profileSummaryLines,
                    color: .blue
                )

                requirementBox(
                    title: t("box.sensitive.title"),
                    lines: viewModel.sensitiveSettingsLines,
                    color: .secondary
                )

                if !viewModel.canStartConversion {
                    requirementBox(
                        title: t("box.blocked.title"),
                        lines: viewModel.conversionBlockers,
                        color: .red
                    )
                } else {
                    requirementBox(
                        title: t("box.available.title"),
                        lines: [t("box.available.line")],
                        color: .green
                    )
                }
            }
        }
    }

    private var settingsZone: some View {
        SectionCard(step: "4", title: t("section.settings")) {
            VStack(alignment: .leading, spacing: 10) {
                labeledRow(label: t("label.language")) {
                    Picker(t("label.language"), selection: $viewModel.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName(in: viewModel.appLanguage)).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                labeledRow(label: t("label.libreoffice")) {
                    TextField(t("placeholder.libreoffice_path"), text: $viewModel.libreOfficePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                HStack(spacing: 8) {
                    Button(t("button.detect")) {
                        viewModel.refreshLibreOfficeStatus()
                    }
                    Button(t("button.test_libreoffice")) {
                        viewModel.testLibreOfficePath()
                    }
                }

                HStack(spacing: 8) {
                    Text(viewModel.libreOfficeFound ? t("status.state_found") : t("status.state_not_found"))
                        .foregroundStyle(viewModel.libreOfficeFound ? .green : .red)
                        .font(.caption)

                    if !viewModel.libreOfficeVersion.isEmpty {
                        Text(t("status.version_format", viewModel.libreOfficeVersion))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button(t("button.open_output_folder")) {
                        viewModel.openOutputFolderInFinder()
                    }
                    .disabled(viewModel.activeOutputFolder == nil)

                    Button(t("button.export_log")) {
                        viewModel.exportLogs()
                    }
                    .disabled(viewModel.logs.isEmpty)

                    Button(t("button.clear_log")) {
                        viewModel.clearLogs()
                    }
                }
            }
        }
    }

    private var resultsZone: some View {
        SectionCard(step: "3", title: t("section.results")) {
            VStack(alignment: .leading, spacing: 10) {
                runStateBanner
                ProgressView(value: viewModel.progress)
                Text(viewModel.progressMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.runSummary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                statsSummary

                Table(viewModel.logs) {
                    TableColumn(t("label.source_folder")) { entry in
                        Text(entry.sourcePath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 320)

                    TableColumn(t("label.status")) { entry in
                        Text(entry.status.displayName(language: viewModel.appLanguage))
                            .font(.caption)
                    }
                    .width(min: 110, max: 140)

                    TableColumn(t("label.output_folder")) { entry in
                        Text(entry.outputPath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 300)

                    TableColumn(t("label.message")) { entry in
                        Text(entry.message)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(minHeight: 420)

                Text(viewModel.stats.summaryLine(language: viewModel.appLanguage))
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private var runStateBanner: some View {
        HStack(spacing: 8) {
            Text(t("run.state"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.runState.displayName(language: viewModel.appLanguage).uppercased())
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(viewModel.runState.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(viewModel.runState.color.opacity(0.12))
                )
            Spacer(minLength: 0)
        }
    }

    private var statsSummary: some View {
        HStack(spacing: 8) {
            statPill(title: "Scannés", value: viewModel.stats.totalScanned)
            statPill(title: "Correspondants", value: viewModel.stats.totalMatched)
            statPill(title: "Convertis", value: viewModel.stats.converted)
            statPill(title: "Simulation", value: viewModel.stats.dryRun)
            statPill(title: "Ignorés", value: viewModel.stats.ignored)
            statPill(title: "Cible existe", value: viewModel.stats.skippedExisting)
            statPill(title: "Erreurs", value: viewModel.stats.errors)
            Spacer(minLength: 0)
        }
    }

    private func folderPickerRow(
        label: String,
        buttonTitle: String,
        pathText: String,
        buttonStyle: RowButtonStyle,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                switch buttonStyle {
                case .regular:
                    Button(buttonTitle, action: action)
                        .disabled(isDisabled)
                case .prominent:
                    Button(buttonTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .disabled(isDisabled)
                }
                pathField(pathText)
            }
        }
    }

    private func labeledRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            content()
        }
    }

    private func pathField(_ path: String) -> some View {
        Text(path)
            .font(.system(.caption, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
    }

    private func statPill(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func statusPill(title: String, value: String, isGood: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.uppercased())
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(isGood ? Color.green : Color.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func t(_ key: String) -> String {
        viewModel.tr(key)
    }

    private func t(_ key: String, _ args: CVarArg...) -> String {
        viewModel.tr(key, args: args)
    }

    private func requirementBox(title: String, lines: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)

            ForEach(lines, id: \.self) { line in
                Text("• \(line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }
}

private enum RowButtonStyle {
    case regular
    case prominent
}

private struct SectionCard<Content: View>: View {
    let step: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(step)
                    .font(.caption.bold())
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                    )

                Text(title)
                    .font(.headline)
                Spacer()
            }

            Divider()

            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
