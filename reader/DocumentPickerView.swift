//
//  DocumentPickerView.swift
//  neader
//
//  Created by Jim Li on 23/3/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let onFilePicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.text, UTType.plainText])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFilePicked: onFilePicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFilePicked: (URL) -> Void

        init(onFilePicked: @escaping (URL) -> Void) {
            self.onFilePicked = onFilePicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onFilePicked(url)
        }
    }
}
