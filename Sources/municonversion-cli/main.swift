// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import MuniConvertInterop
import OrchivisteKitContracts
import OrchivisteKitInterop

@main
struct MuniConversionCLI {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args.isEmpty || args.contains("--help") || args.contains("-h") {
                printUsage()
                return
            }

            let parsed = try CanonicalCLIArguments.parse(args)
            let requestURL = URL(fileURLWithPath: parsed.requestPath)
            let resultURL = URL(fileURLWithPath: parsed.resultPath)

            let request = try ToolInteropService.loadRequest(from: requestURL)
            let result = await CanonicalRunAdapter.execute(request: request)

            try ToolInteropService.writeResult(result, to: resultURL)
            printToolResult(result)

            if result.status == .failed {
                exit(1)
            }
        } catch let error as CanonicalCLIArgumentsError {
            switch error {
            case .usage(let message):
                fputs("Erreur: \(message)\n", stderr)
                printUsage()
                exit(2)
            }
        } catch {
            fputs("Erreur: \(error.localizedDescription)\n", stderr)
            printUsage()
            exit(1)
        }
    }

    private static func printToolResult(_ result: ToolResult) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(result), let json = String(data: data, encoding: .utf8) {
            print(json)
            return
        }
        print("{\"status\":\"failed\",\"summary\":\"Unable to encode ToolResult.\"}")
    }

    private static func printUsage() {
        let usage = """
        MuniConversion CLI (mode canonique OrchivisteKit)

        Usage:
          municonversion-cli run --request <request.json> --result <result.json>

        Notes:
          - dry_run=true par défaut dans le contrat canonique.
          - conversion réelle seulement avec dry_run=false et confirm_convert=true.
        """
        print(usage)
    }
}
