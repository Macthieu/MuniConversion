// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showRealConversionConfirmation = false

    var body: some View {
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
        .alert(item: $viewModel.alertInfo) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Confirmer la conversion",
            isPresented: $showRealConversionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Lancer", role: .destructive) {
                viewModel.startConversion()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(viewModel.conversionConfirmationMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MuniConvert")
                    .font(.title2.weight(.semibold))
                Text("Conversion documentaire en lot via LibreOffice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusPill(
                title: "LibreOffice",
                value: viewModel.libreOfficeFound ? "trouvé" : "non trouvé",
                isGood: viewModel.libreOfficeFound
            )

            if viewModel.dryRunOnly {
                statusPill(title: "Mode", value: "SIMULATION", isGood: true)
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
        SectionCard(step: "1", title: "Sélection") {
            VStack(alignment: .leading, spacing: 10) {
                folderPickerRow(
                    label: "Dossier source",
                    buttonTitle: "Choisir un dossier",
                    pathText: viewModel.sourcePathText,
                    buttonStyle: .prominent,
                    isDisabled: false,
                    action: viewModel.chooseSourceFolder
                )

                Toggle("Inclure les sous-dossiers", isOn: $viewModel.includeSubdirectories)
                Toggle("Utiliser un dossier de sortie distinct", isOn: $viewModel.useSeparateOutputFolder)
                Toggle("Préserver l'arborescence", isOn: $viewModel.preserveRelativeStructure)
                    .disabled(!viewModel.useSeparateOutputFolder)
                Toggle("Simulation seulement (aucune conversion)", isOn: $viewModel.dryRunOnly)
                Toggle("Ignorer fichiers cachés", isOn: $viewModel.ignoreHiddenFiles)

                folderPickerRow(
                    label: "Dossier de sortie",
                    buttonTitle: "Choisir dossier de sortie",
                    pathText: viewModel.outputPathText,
                    buttonStyle: .regular,
                    isDisabled: !viewModel.useSeparateOutputFolder,
                    action: viewModel.chooseOutputFolder
                )
            }
        }
    }

    private var conversionZone: some View {
        SectionCard(step: "2", title: "Conversion") {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.dryRunOnly {
                    requirementBox(
                        title: "MODE SIMULATION ACTIF",
                        lines: ["Aucune commande de conversion réelle ne sera exécutée."],
                        color: .orange
                    )
                }

                labeledRow(label: "Recherche profil") {
                    TextField("Ex: doc, pdf, odt...", text: $viewModel.profileSearchText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                labeledRow(label: "Type de conversion") {
                    Picker("Type de conversion", selection: $viewModel.selectedProfileID) {
                        if !viewModel.hasFilteredProfiles {
                            Text("Aucun profil trouvé").tag(String?.none)
                        }
                        Text("Sélectionner...").tag(String?.none)
                        ForEach(viewModel.filteredProfiles) { profile in
                            Text(profile.displayName).tag(String?.some(profile.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                labeledRow(label: "Collision") {
                    Picker("Collision", selection: $viewModel.collisionPolicy) {
                        ForEach(CollisionPolicy.allCases) { policy in
                            Text(policy.compactDisplayName).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Politique en cas de fichier cible existant.")
                }

                HStack(spacing: 8) {
                    Button("Analyser") {
                        viewModel.analyze()
                    }
                    .disabled(!viewModel.canAnalyze)

                    Button("Lancer la conversion") {
                        if viewModel.dryRunOnly {
                            viewModel.startConversion()
                        } else {
                            showRealConversionConfirmation = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStartConversion)

                    Button("Arrêter") {
                        viewModel.stopCurrentRun()
                    }
                    .disabled(!viewModel.isRunning)
                }

                requirementBox(
                    title: "Résumé du profil actif",
                    lines: viewModel.profileSummaryLines,
                    color: .blue
                )

                requirementBox(
                    title: "Paramètres sensibles",
                    lines: viewModel.sensitiveSettingsLines,
                    color: .secondary
                )

                if !viewModel.canStartConversion {
                    requirementBox(
                        title: "Conversion indisponible: préconditions manquantes",
                        lines: viewModel.conversionBlockers,
                        color: .red
                    )
                } else {
                    requirementBox(
                        title: "Conversion disponible",
                        lines: ["Toutes les préconditions sont remplies."],
                        color: .green
                    )
                }
            }
        }
    }

    private var settingsZone: some View {
        SectionCard(step: "4", title: "Paramètres") {
            VStack(alignment: .leading, spacing: 10) {
                labeledRow(label: "LibreOffice") {
                    TextField("Chemin vers soffice", text: $viewModel.libreOfficePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                HStack(spacing: 8) {
                    Button("Détecter") {
                        viewModel.refreshLibreOfficeStatus()
                    }
                    Button("Tester LibreOffice") {
                        viewModel.testLibreOfficePath()
                    }
                }

                HStack(spacing: 8) {
                    Text(viewModel.libreOfficeFound ? "État: trouvé" : "État: non trouvé")
                        .foregroundStyle(viewModel.libreOfficeFound ? .green : .red)
                        .font(.caption)

                    if !viewModel.libreOfficeVersion.isEmpty {
                        Text("Version: \(viewModel.libreOfficeVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button("Ouvrir le dossier de sortie") {
                        viewModel.openOutputFolderInFinder()
                    }
                    .disabled(viewModel.activeOutputFolder == nil)

                    Button("Exporter le journal (.txt)") {
                        viewModel.exportLogs()
                    }
                    .disabled(viewModel.logs.isEmpty)

                    Button("Effacer le journal") {
                        viewModel.clearLogs()
                    }
                }
            }
        }
    }

    private var resultsZone: some View {
        SectionCard(step: "3", title: "Résultats") {
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
                    TableColumn("Fichier source") { entry in
                        Text(entry.sourcePath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 320)

                    TableColumn("Statut") { entry in
                        Text(entry.status.displayName)
                            .font(.caption)
                    }
                    .width(min: 110, max: 140)

                    TableColumn("Fichier de sortie") { entry in
                        Text(entry.outputPath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 300)

                    TableColumn("Message") { entry in
                        Text(entry.message)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(minHeight: 420)

                Text(viewModel.stats.summaryLine)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private var runStateBanner: some View {
        HStack(spacing: 8) {
            Text("État du lot")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.runState.displayName.uppercased())
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
