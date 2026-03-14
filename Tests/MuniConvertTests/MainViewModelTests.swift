import Foundation
import Testing
@testable import MuniConvertCore

struct MainViewModelTests {
    @Test
    @MainActor
    func blockersWithoutRequiredInputs() {
        let viewModel = makeViewModel()

        #expect(viewModel.analysisBlockers.contains("Choisir un dossier source."))
        #expect(viewModel.analysisBlockers.contains("Choisir un type de conversion."))
        #expect(viewModel.conversionBlockers.contains("LibreOffice est requis pour une conversion réelle."))
        #expect(!viewModel.canAnalyze)
        #expect(!viewModel.canStartConversion)
    }

    @Test
    @MainActor
    func dryRunBypassesLibreOfficeRequirement() throws {
        let viewModel = makeViewModel()
        let temp = try TempDirectory()

        viewModel.sourceFolderURL = temp.url
        viewModel.selectedProfileID = "doc_to_pdf"
        viewModel.dryRunOnly = true

        #expect(viewModel.analysisBlockers.isEmpty)
        #expect(viewModel.conversionBlockers.isEmpty)
        #expect(viewModel.canAnalyze)
        #expect(viewModel.canStartConversion)
    }

    @Test
    @MainActor
    func missingOutputFolderBlocksWhenSeparateOutputEnabled() throws {
        let viewModel = makeViewModel()
        let temp = try TempDirectory()

        viewModel.sourceFolderURL = temp.url
        viewModel.selectedProfileID = "doc_to_pdf"
        viewModel.useSeparateOutputFolder = true

        #expect(viewModel.analysisBlockers.contains("Choisir un dossier de sortie."))
        #expect(!viewModel.canAnalyze)
    }

    @Test
    @MainActor
    func profileSearchFiltersAndClearsIncompatibleSelection() throws {
        let viewModel = makeViewModel()

        viewModel.selectedProfileID = "doc_to_pdf"
        #expect(viewModel.selectedProfileID == "doc_to_pdf")

        viewModel.profileSearchText = "odp"

        #expect(viewModel.selectedProfileID == nil)
        #expect(viewModel.filteredProfiles.contains { $0.id == "odp_to_pdf" })
        #expect(!viewModel.filteredProfiles.contains { $0.id == "doc_to_pdf" })
    }

    @Test
    @MainActor
    func profileSummaryReflectsSelectedProfile() {
        let viewModel = makeViewModel()

        viewModel.selectedProfileID = "odt_to_pdf"

        #expect(viewModel.profileSummaryLines.contains { $0.contains(".odt") })
        #expect(viewModel.profileSummaryLines.contains { $0.contains(".pdf") })
        #expect(viewModel.profileSummaryLines.contains { $0.contains("Format LibreOffice") })
    }

    @MainActor
    private func makeViewModel() -> MainViewModel {
        let suiteName = "MuniConvertTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let settingsStore = SettingsStore(defaults: defaults)
        return MainViewModel(
            settingsStore: settingsStore,
            autoDetectLibreOffice: false
        )
    }
}
