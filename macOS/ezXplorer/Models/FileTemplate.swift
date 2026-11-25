import Foundation

/// Supported file types for the Windows 11–style "New File" menu in each folder pane.
/// Each template specifies a default filename, icon, starter contents, and post-creation attributes.
enum FileTemplateCategory: String, CaseIterable, Identifiable {
    case documents = "Documents"
    case codeAndScripts = "Code & Scripts"
    case dataAndConfig = "Data & Config"
    case archives = "Archives"

    var id: String { rawValue }
}

enum FileTemplate: String, CaseIterable, Identifiable {
    // Documents
    case plainText
    case markdown
    case richText
    case csvSpreadsheet

    // Code & Scripts
    case shellScript
    case swiftSource
    case pythonScript
    case htmlDocument

    // Data & Config
    case jsonFile
    case yamlFile
    case xmlDocument
    case sqlScript

    // Archives
    case zipArchive

    var id: String { rawValue }

    var category: FileTemplateCategory {
        switch self {
        case .plainText, .markdown, .richText, .csvSpreadsheet:
            return .documents
        case .shellScript, .swiftSource, .pythonScript, .htmlDocument:
            return .codeAndScripts
        case .jsonFile, .yamlFile, .xmlDocument, .sqlScript:
            return .dataAndConfig
        case .zipArchive:
            return .archives
        }
    }

    var displayName: String {
        switch self {
        case .plainText: return "Plain Text Document (.txt)"
        case .markdown: return "Markdown Document (.md)"
        case .richText: return "Rich Text Document (.rtf)"
        case .csvSpreadsheet: return "CSV Spreadsheet (.csv)"
        case .shellScript: return "Shell Script (.sh)"
        case .swiftSource: return "Swift Source File (.swift)"
        case .pythonScript: return "Python Script (.py)"
        case .htmlDocument: return "HTML Web Page (.html)"
        case .jsonFile: return "JSON File (.json)"
        case .yamlFile: return "YAML File (.yaml)"
        case .xmlDocument: return "XML Document (.xml)"
        case .sqlScript: return "SQL Script (.sql)"
        case .zipArchive: return "Compressed Archive (.zip)"
        }
    }

    var systemImage: String {
        switch self {
        case .plainText: return "doc.plaintext"
        case .markdown: return "doc.richtext"
        case .richText: return "doc.text"
        case .csvSpreadsheet: return "tablecells"
        case .shellScript: return "terminal"
        case .swiftSource: return "swift"
        case .pythonScript: return "chevron.left.forwardslash.chevron.right"
        case .htmlDocument: return "globe"
        case .jsonFile: return "curlybraces"
        case .yamlFile: return "list.bullet.indent"
        case .xmlDocument: return "chevron.left.slash.chevron.right"
        case .sqlScript: return "cylinder"
        case .zipArchive: return "doc.zipper"
        }
    }

    var defaultBaseName: String {
        switch self {
        case .plainText: return "New Text Document"
        case .markdown: return "New Document"
        case .richText: return "New Rich Text Document"
        case .csvSpreadsheet: return "New Spreadsheet"
        case .shellScript: return "new_script"
        case .swiftSource: return "NewFile"
        case .pythonScript: return "new_script"
        case .htmlDocument: return "index"
        case .jsonFile: return "data"
        case .yamlFile: return "config"
        case .xmlDocument: return "document"
        case .sqlScript: return "query"
        case .zipArchive: return "New Archive"
        }
    }

    var fileExtension: String {
        switch self {
        case .plainText: return "txt"
        case .markdown: return "md"
        case .richText: return "rtf"
        case .csvSpreadsheet: return "csv"
        case .shellScript: return "sh"
        case .swiftSource: return "swift"
        case .pythonScript: return "py"
        case .htmlDocument: return "html"
        case .jsonFile: return "json"
        case .yamlFile: return "yaml"
        case .xmlDocument: return "xml"
        case .sqlScript: return "sql"
        case .zipArchive: return "zip"
        }
    }

    /// Whether the created file should automatically receive executable POSIX permissions (0o755).
    var isExecutable: Bool {
        self == .shellScript
    }

    /// Initial file bytes tailored to each file type so apps can immediately open and edit the file cleanly.
    var initialData: Data {
        switch self {
        case .plainText:
            return Data()

        case .markdown:
            return Data("# Untitled\n\n".utf8)

        case .richText:
            let rtf = """
            {\\rtf1\\ansi\\ansicpg1252\\cocoartf2709
            {\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}
            \\margl1440\\margr1440\\vieww11520\\viewh8400\\viewkind0
            \\pard\\tx720\\tx1440\\tx2160\\tx2880\\tx3600\\tx4320\\tx5040\\tx5760\\tx6480\\tx7200\\tx7920\\tx8640\\pardirnatural\\partightenfactor0
            \\f0\\fs24 \\cf0 }
            """
            return Data(rtf.utf8)

        case .csvSpreadsheet:
            return Data("Column1,Column2,Column3\n".utf8)

        case .shellScript:
            return Data("#!/bin/zsh\n\nset -euo pipefail\n\n".utf8)

        case .swiftSource:
            return Data("import Foundation\n\n".utf8)

        case .pythonScript:
            let py = """
            #!/usr/bin/env python3


            def main() -> None:
                pass


            if __name__ == "__main__":
                main()
            """
            return Data((py + "\n").utf8)

        case .htmlDocument:
            let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>Untitled</title>
            </head>
            <body>
              <h1>Untitled</h1>
            </body>
            </html>
            """
            return Data((html + "\n").utf8)

        case .jsonFile:
            return Data("{\n  \n}\n".utf8)

        case .yamlFile:
            return Data("# Configuration\n".utf8)

        case .xmlDocument:
            return Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n</root>\n".utf8)

        case .sqlScript:
            return Data("-- SQL Query\nSELECT 1;\n".utf8)

        case .zipArchive:
            // Standard 22-byte empty ZIP End of Central Directory (EOCD) record.
            let eocd: [UInt8] = [
                0x50, 0x4B, 0x05, 0x06,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00,
                0x00, 0x00
            ]
            return Data(eocd)
        }
    }

    static func templates(in category: FileTemplateCategory) -> [FileTemplate] {
        allCases.filter { $0.category == category }
    }
}
