//
//  ContentView.swift
//  Convertr
//
//  Created by Hannes Nagel on 3/4/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing
import PDFKit
import Quartz
import Vision
import Aptabase

struct ImageItem: Identifiable {
    let id = UUID()
    let image: NSImage
    let originalURL: URL?
    var status: String = "Pending"
}

struct FormatGroup: Identifiable {
    let id = UUID()
    let name: String
    let formats: [Format]
}

struct Format: Hashable {
    let name: String
    let extensions: [String]
    let utType: UTType
    let canBeSource: Bool
    let canBeDestination: Bool
    let compatibleSourceFormats: [String]  // Names of formats that can be converted from
    let description: String  // Description of the format
}

// MARK: - Image Grid Item View
struct ImageGridItem: View {
    let item: ImageItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("thumbnailSize") private var thumbnailSize = 80.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                if showThumbnails {
                    Image(nsImage: item.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: thumbnailSize)
                } else {
                    Text(item.originalURL?.lastPathComponent ?? "Untitled")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(item.status)
                    .font(.caption)
                    .foregroundColor(item.status == "Done" ? .green : .gray)
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .onTapGesture(count: 1) {
                onSelect()
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: -4, y: 4)
        }
    }
}

// MARK: - Drop Zone View
struct DropZoneView: View {
    let dragOver: Bool
    let isEmpty: Bool
    let content: AnyView

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(dragOver ? Color.blue : Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Drag and drop images here")
                        .foregroundColor(.gray)
                }
            } else {
                content
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Control Bar View
struct ControlBarView: View {
    let itemsCount: Int
    let onSelectItems: () -> Void
    let onClear: () -> Void
    @Binding var selectedOutputFormat: Format
    let availableFormats: [Format]
    let currentInputFormat: Format?

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button(action: onSelectItems) {
                    Label("Select Files", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("o", modifiers: .command)

                Button(action: onClear) {
                    Label("Clear All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(itemsCount == 0)

                Spacer()
            }

            HStack {
                Text("Convert to:")
                Picker("Format", selection: $selectedOutputFormat) {
                    ForEach(availableFormats, id: \.self) { format in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(format.name)
                                Text(format.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let inputFormat = currentInputFormat {
                                if !format.compatibleSourceFormats.contains(inputFormat.name) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .help("Conversion from \(inputFormat.name) to \(format.name) may not preserve all content")
                                }
                            }
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - Convert Button View
struct ConvertButtonView: View {
    let isConverting: Bool
    let itemsCount: Int
    let onConvert: () -> Void
    let progress: Double
    let selectedOutputFormat: Format
    let currentInputFormat: Format?

    var body: some View {
        VStack(spacing: 8) {
            if let inputFormat = currentInputFormat {
                if !selectedOutputFormat.compatibleSourceFormats.contains(inputFormat.name) {
                    Text("Warning: Converting from \(inputFormat.name) to \(selectedOutputFormat.name) may not preserve all content")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: onConvert) {
                if isConverting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Convert \(itemsCount) File\(itemsCount == 1 ? "" : "s")")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(itemsCount == 0 || isConverting)

            if isConverting {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
            }
        }
    }
}

// MARK: - Image Grid View
struct ImageGridView: View {
    let images: [ImageItem]
    let selectedIds: Set<UUID>
    let onSelect: (ImageItem) -> Void
    let onDelete: (ImageItem) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(images) { item in
                    ImageGridItem(
                        item: item,
                        isSelected: selectedIds.contains(item.id),
                        onSelect: { onSelect(item) },
                        onDelete: { onDelete(item) }
                    )
                }
            }
            .padding(10)
        }
        .clipShape(Rectangle())
    }
}

// MARK: - Content View
struct ContentView: View {
    let windowId: String
    @StateObject private var fileTypeState = FileTypeState.shared
    @EnvironmentObject private var windowManager: ConversionWindowManager
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("thumbnailSize") private var thumbnailSize = 80.0
    @AppStorage("jpegQuality") private var jpegQuality = 0.9
    @AppStorage("defaultImageFormat") private var defaultImageFormat = "PNG"
    @AppStorage("defaultDocumentFormat") private var defaultDocumentFormat = "PDF"

    @State private var selectedImageIds: Set<UUID> = []
    @State private var dragOver = false
    @State private var isConverting = false
    @State private var errorMessage: String?
    @State var selectedOutputFormat: Format
    @State private var currentInputFormat: Format?
    @State private var conversionProgress = 0.0
    @State private var lastSelectedImageId: UUID? = nil
    @State var formatGroups = [
        FormatGroup(name: "Images", formats: [
            Format(name: "PNG", extensions: ["png"], utType: .png,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["JPEG", "TIFF", "HEIC", "GIF", "BMP", "PDF", "Base64"],
                   description: "Lossless image format with transparency support"),
            Format(name: "JPEG", extensions: ["jpg", "jpeg"], utType: .jpeg,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "TIFF", "HEIC", "GIF", "BMP", "PDF", "Base64"],
                   description: "Compressed image format, best for photos"),
            Format(name: "TIFF", extensions: ["tiff", "tif"], utType: .tiff,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "JPEG", "HEIC", "GIF", "BMP", "PDF", "Base64"],
                   description: "High-quality image format for print"),
            Format(name: "HEIC", extensions: ["heic"], utType: .heic,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "JPEG", "TIFF", "GIF", "BMP", "PDF", "Base64"],
                   description: "Modern compressed image format"),
            Format(name: "GIF", extensions: ["gif"], utType: .gif,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "JPEG", "TIFF", "HEIC", "BMP", "PDF", "Base64"],
                   description: "Animated image format"),
            Format(name: "BMP", extensions: ["bmp"], utType: .bmp,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "JPEG", "TIFF", "HEIC", "GIF", "PDF", "Base64"],
                   description: "Basic bitmap image format")
        ]),
        FormatGroup(name: "Documents", formats: [
            Format(name: "PDF", extensions: ["pdf"], utType: .pdf,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "JPEG", "TIFF", "HEIC", "GIF", "BMP", "Base64", "Plain Text", "RTF"],
                   description: "Portable Document Format"),
            Format(name: "RTF", extensions: ["rtf"], utType: .rtf,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["Plain Text", "PDF"],
                   description: "Rich Text Format with styling"),
            Format(name: "Plain Text", extensions: ["txt"], utType: .plainText,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["RTF", "PDF"],
                   description: "Simple text format")
        ]),
        FormatGroup(name: "Encoded", formats: [
            Format(name: "Base64", extensions: ["txt"], utType: .plainText,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["PNG", "JPEG", "TIFF", "HEIC", "GIF", "BMP", "PDF"],
                   description: "Text-encoded binary data")
        ])
    ]

    private var availableOutputFormats: [Format] {
        formatGroups.flatMap { $0.formats }.filter { $0.canBeDestination }
    }

    init(windowId: String) {
        self.windowId = windowId
        let defaultFormat = FormatGroup(name: "Images", formats: [
            Format(name: "PNG", extensions: ["png"], utType: .png,
                   canBeSource: true, canBeDestination: true,
                   compatibleSourceFormats: ["JPEG", "TIFF", "HEIC", "GIF", "BMP", "PDF", "Base64"],
                   description: "Lossless image format with transparency support")
        ]).formats[0]
        self._selectedOutputFormat = State(initialValue: defaultFormat)
    }

    var body: some View {
        VStack {
            Text("Convertr")
                .font(.largeTitle)
                .fontWeight(.bold)

            DropZoneView(
                dragOver: dragOver,
                isEmpty: fileTypeState.items(for: windowId).isEmpty,
                content: AnyView(
                    ImageGridView(
                        images: fileTypeState.items(for: windowId),
                        selectedIds: selectedImageIds,
                        onSelect: handleImageSelection,
                        onDelete: handleImageDeletion
                    )
                )
            )
            .frame(minHeight: 200, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL.identifier, UTType.plainText.identifier], isTargeted: $dragOver) { providers -> Bool in
                print("Drop received with \(providers.count) providers")
                Task {
                    let newItems = await withTaskGroup(of: [ImageItem].self) { group in
                        for provider in providers {
                            print("Provider types:", provider.registeredTypeIdentifiers)
                            print("Available types for provider:", provider.registeredTypeIdentifiers)
                            
                            group.addTask {
                                do {
                                    // Try to load as plain text first
                                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                                        print("Attempting to load as plain text")
                                        
                                        // Load the item and check its type
                                        let item = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
                                        print("Got item of type:", type(of: item))
                                        
                                        if let url = item as? URL ?? (item as? NSURL) as URL? {
                                            print("Got URL from text provider:", url)
                                            
                                            // Try multiple approaches to access the file
                                            var fileAccessGranted = false
                                            var fileContent: String? = nil
                                            
                                            // First try: Direct security-scoped access
                                            if url.startAccessingSecurityScopedResource() {
                                                print("Successfully accessed security-scoped resource")
                                                fileAccessGranted = true
                                                defer { url.stopAccessingSecurityScopedResource() }
                                                
                                                do {
                                                    fileContent = try String(contentsOf: url, encoding: .utf8)
                                                    print("Successfully read file content, length:", fileContent?.count ?? 0)
                                                } catch {
                                                    print("Error reading file with security-scoped access:", error)
                                                }
                                            } else {
                                                print("Failed to access security-scoped resource, trying alternative methods")
                                            }
                                            
                                            // Second try: Direct file access
                                            if fileContent == nil {
                                                do {
                                                    fileContent = try String(contentsOf: url, encoding: .utf8)
                                                    print("Successfully read file content through direct access, length:", fileContent?.count ?? 0)
                                                } catch {
                                                    print("Error reading file through direct access:", error)
                                                }
                                            }
                                            
                                            // Third try: File handle approach
                                            if fileContent == nil {
                                                do {
                                                    let fileHandle = try FileHandle(forReadingFrom: url)
                                                    defer { try? fileHandle.close() }
                                                    let data = try fileHandle.readToEnd()
                                                    if let data = data,
                                                       let content = String(data: data, encoding: .utf8) {
                                                        fileContent = content
                                                        print("Successfully read file content using file handle, length:", content.count)
                                                    }
                                                } catch {
                                                    print("Error reading file using file handle:", error)
                                                }
                                            }
                                            
                                            // If we got the content, render it
                                            if let content = fileContent {
                                                if let image = await renderTextAsImage(content) {
                                                    print("Successfully rendered text as image")
                                                    return [ImageItem(image: image, originalURL: url)]
                                                } else {
                                                    print("Failed to render text as image")
                                                }
                                            } else {
                                                print("Failed to read file content through all available methods")
                                            }
                                            
                                            return []
                                        }
                                    }
                                    
                                    // Only try file URL if we haven't handled it above
                                    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                                        print("Attempting to load as file URL")
                                        do {
                                            let urlResult = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                                            print("Got URL result of type:", type(of: urlResult))
                                            
                                            let url: URL
                                            if let directURL = urlResult as? URL {
                                                url = directURL
                                            } else if let nsurl = urlResult as? NSURL {
                                                url = nsurl as URL
                                            } else if let urlData = urlResult as? Data,
                                                      let urlString = String(data: urlData, encoding: .utf8) {
                                                // Remove "file://" prefix if present and create URL
                                                let cleanPath = urlString.replacingOccurrences(of: "file://", with: "")
                                                url = URL(fileURLWithPath: cleanPath)
                                            } else {
                                                print("Unexpected URL result type:", type(of: urlResult))
                                                return []
                                            }
                                            
                                            print("Processing URL:", url)
                                            
                                            // Try to access the file
                                            var items: [ImageItem] = []
                                            
                                            // First try: Direct security-scoped access
                                            if url.startAccessingSecurityScopedResource() {
                                                print("Successfully accessed security-scoped resource")
                                                defer { url.stopAccessingSecurityScopedResource() }
                                                items = await loadDocument(from: url)
                                            } else {
                                                print("Failed to access security-scoped resource, trying direct access")
                                            }
                                            
                                            // Second try: Direct access
                                            if items.isEmpty {
                                                print("Attempting direct file access")
                                                items = await loadDocument(from: url)
                                            }
                                            
                                            print("Loaded \(items.count) items from document")
                                            return items
                                        } catch {
                                            print("Error loading URL from provider:", error)
                                            print("Error details - Domain:", (error as NSError).domain)
                                            print("Error details - Code:", (error as NSError).code)
                                            print("Error details - Description:", error.localizedDescription)
                                        }
                                    } else {
                                        print("Provider does not support file URL")
                                    }
                                } catch {
                                    print("Error loading dropped item:", error)
                                    print("Error details - Domain:", (error as NSError).domain)
                                    print("Error details - Code:", (error as NSError).code)
                                    print("Error details - Description:", (error as NSError).localizedDescription)
                                    print("Error details - User Info:", (error as NSError).userInfo)
                                }
                                return []
                            }
                        }
                        var items: [ImageItem] = []
                        for await newItems in group {
                            items.append(contentsOf: newItems)
                        }
                        print("Total items collected:", items.count)
                        return items
                    }

                    let groupedItems = self.windowManager.splitItemsByType(newItems)
                    print("Grouped items:", groupedItems.keys)
                    print("Items per group:", groupedItems.mapValues { $0.count })

                    for (type, items) in groupedItems {
                        if type == windowId {
                            print("Adding \(items.count) items to current window")
                            fileTypeState.addItems(items, type: type)
                        } else {
                            print("Opening new window for type:", type)
                            openWindow(id: type)
                            fileTypeState.addItems(items, type: type)
                        }
                    }
                }
                return true
            }

            // Hidden buttons for keyboard shortcuts
            Group {
                Button(action: deleteSelectedImages) {
                    EmptyView()
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Button(action: selectAllImages) {
                    EmptyView()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button(action: copySelectedImages) {
                    EmptyView()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button(action: pasteImages) {
                    EmptyView()
                }
                .keyboardShortcut("v", modifiers: .command)

                Button(action: cutSelectedImages) {
                    EmptyView()
                }
                .keyboardShortcut("x", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .hidden()

            VStack {
                ControlBarView(
                    itemsCount: fileTypeState.items(for: windowId).count,
                    onSelectItems: selectImages,
                    onClear: clearImages,
                    selectedOutputFormat: $selectedOutputFormat,
                    availableFormats: availableOutputFormats,
                    currentInputFormat: currentInputFormat
                )

                ConvertButtonView(
                    isConverting: isConverting,
                    itemsCount: fileTypeState.items(for: windowId).count,
                    onConvert: convertImages,
                    progress: conversionProgress,
                    selectedOutputFormat: selectedOutputFormat,
                    currentInputFormat: currentInputFormat
                )

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding()
        .onAppear {
            windowManager.setOpenWindow { id in
                openWindow(id: id)
            }
        }
    }

    private func handleImageSelection(_ item: ImageItem) {
        let modifiers = NSEvent.modifierFlags
        let items = fileTypeState.items(for: windowId)

        if modifiers.contains(.command) {
            // Command-click: toggle individual selection
            if selectedImageIds.contains(item.id) {
                selectedImageIds.remove(item.id)
            } else {
                selectedImageIds.insert(item.id)
            }
            lastSelectedImageId = item.id
        } else if modifiers.contains(.shift), let lastId = lastSelectedImageId {
            // Shift-click: select range
            if let lastIndex = items.firstIndex(where: { $0.id == lastId }),
               let currentIndex = items.firstIndex(where: { $0.id == item.id }) {
                let range = min(lastIndex, currentIndex)...max(lastIndex, currentIndex)
                let idsInRange = items[range].map { $0.id }
                selectedImageIds.formUnion(idsInRange)
            }
        } else {
            // Normal click: single selection
            if selectedImageIds.contains(item.id) {
                selectedImageIds.removeAll()
            } else {
                selectedImageIds = [item.id]
            }
            lastSelectedImageId = item.id
        }
    }

    private func handleImageDeletion(_ item: ImageItem) {
        fileTypeState.removeItems([item], type: windowId)
        selectedImageIds.remove(item.id)
        if fileTypeState.items(for: windowId).isEmpty {
            errorMessage = nil
            conversionProgress = 0.0
        }
    }

    private func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        print("Drop received with \(providers.count) providers")

        actor ItemCollector {
            private var items: [ImageItem] = []

            func add(_ item: ImageItem) { items.append(item) }
            func addItems(_ newItems: [ImageItem]) { items.append(contentsOf: newItems) }
            func getAllItems() -> [ImageItem] { items }
        }

        let collector = ItemCollector()
        let imageTypes = [UTType.image.identifier, UTType.png.identifier, UTType.jpeg.identifier,
                          UTType.tiff.identifier, UTType.gif.identifier, UTType.bmp.identifier,
                          UTType.heic.identifier]

        Task {
            for provider in providers {
                print("Provider types:", provider.registeredTypeIdentifiers)

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let textData = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? Data,
                       let urlString = String(data: textData, encoding: .utf8) {
                        let url = URL(fileURLWithPath: urlString.replacingOccurrences(of: "file://", with: ""))
                        let items = await loadDocument(from: url)
                        await collector.addItems(items)
                    } else if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
                              let image = await renderTextAsImage(text) {
                        await collector.add(ImageItem(image: image, originalURL: nil))
                    }
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                   let urlData = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL {
                    let items = await loadDocument(from: urlData)
                    await collector.addItems(items)
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier),
                   let data = try? await provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier),
                   let pdfDoc = PDFDocument(data: data) {
                    for i in 0..<pdfDoc.pageCount {
                        if let page = pdfDoc.page(at: i),
                           let pageImage = await self.renderPDFPage(page) {
                            await collector.add(ImageItem(image: pageImage, originalURL: nil))
                        }
                    }
                    continue
                }

                for imageType in imageTypes where provider.hasItemConformingToTypeIdentifier(imageType) {
                    if let imageData = try? await provider.loadDataRepresentation(forTypeIdentifier: imageType),
                       let image = NSImage(data: imageData) {
                        await collector.add(ImageItem(image: image, originalURL: nil))
                    }
                    break
                }
            }

            let newItems = await collector.getAllItems()
            print("All items processed, new items count: \(newItems.count)")

            let groupedItems = self.windowManager.splitItemsByType(newItems)
            for (type, items) in groupedItems {
                if type == self.windowId {
                    self.fileTypeState.addItems(items, type: type)
                } else {
                    self.openWindow(id: type)
                    self.fileTypeState.addItems(items, type: type)
                }
            }
        }

        return true
    }

    private func loadDocument(from url: URL) async -> [ImageItem] {
        print("Loading document from URL:", url)
        let fileExtension = url.pathExtension.lowercased()
        print("File extension:", fileExtension)
        
        let format = formatGroups.flatMap { $0.formats }
            .first { $0.extensions.contains(fileExtension) }
        print("Detected format:", format?.name ?? "unknown")

        // Handle text files
        if format?.utType == .plainText || format?.utType == .rtf {
            print("Handling as text file")
            do {
                let text: String
                if format?.utType == .rtf {
                    // Handle RTF files
                    if let data = try? Data(contentsOf: url),
                       let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                        text = attributedString.string
                    } else {
                        print("Failed to load RTF file")
                        return []
                    }
                } else {
                    // Handle plain text files
                    text = try String(contentsOf: url, encoding: .utf8)
                }
                
                if let image = await renderTextAsImage(text) {
                    return [ImageItem(image: image, originalURL: url)]
                }
            } catch {
                print("Error loading text file:", error)
                return []
            }
        }
        
        // Handle PDF documents
        if format?.utType == .pdf {
            print("Handling as PDF file")
            var items: [ImageItem] = []
            if let pdfDoc = PDFDocument(url: url) {
                for i in 0..<pdfDoc.pageCount {
                    if let page = pdfDoc.page(at: i),
                       let pageImage = await renderPDFPage(page) {
                        items.append(ImageItem(image: pageImage, originalURL: url))
                    }
                }
            }
            return items
        }
        
        // Handle image files
        print("Attempting to load as image")
        if let image = NSImage(contentsOf: url) {
            print("Successfully loaded image")
            return [ImageItem(image: image, originalURL: url)]
        } else {
            print("Failed to load image directly, trying data method")
            // Try loading as data first
            if let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                print("Successfully loaded image from data")
                return [ImageItem(image: image, originalURL: url)]
            }
        }
        
        print("Failed to load document")
        return []
    }

    private func renderTextAsImage(_ text: String) async -> NSImage? {
        print("Attempting to render text as image")
        
        // First try to decode as base64
        print("Attempting to decode as base64")
        if let data = Data(base64Encoded: text) {
            print("Successfully decoded base64 data")
            if let image = NSImage(data: data) {
                print("Successfully created image from base64 data")
                return image
            } else {
                print("Failed to create image from base64 data")
            }
        } else {
            print("Text is not valid base64 data")
        }
        
        print("Falling back to text rendering")
        // Add padding to make the text more readable
        let padding: CGFloat = 20
        let maxWidth: CGFloat = 800 // Maximum width for better readability

        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14), // Slightly larger font
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.lineSpacing = 6 // Increased line spacing
                    style.alignment = .left
                    return style
                }()
            ]
        )

        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: maxWidth - (padding * 2), height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        // Calculate the size needed
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        // Add padding to the bounds
        bounds.size.width += padding * 2
        bounds.size.height += padding * 2

        // Create an image of the text
        let image = NSImage(size: bounds.size)
        image.lockFocus()

        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high

            // Draw background
            NSColor.textBackgroundColor.set()
            NSBezierPath(rect: NSRect(origin: .zero, size: bounds.size)).fill()

            // Draw a subtle border
            NSColor.separatorColor.set()
            NSBezierPath(rect: NSRect(origin: .zero, size: bounds.size)).stroke()

            // Draw text with padding
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: CGPoint(x: padding, y: padding))
        }

        image.unlockFocus()
        print("Successfully created text image with size:", bounds.size)
        return image
    }

    func selectImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        // Allow all supported input formats
        let supportedTypes = formatGroups.flatMap { $0.formats }
            .filter { $0.canBeSource }
            .map { $0.utType }
        panel.allowedContentTypes = supportedTypes

        panel.begin { response in
            if response == .OK {
                Task {
                    var newItems: [ImageItem] = []

                    // Load all documents
                    for url in panel.urls {
                        let items = await loadDocument(from: url)
                        newItems.append(contentsOf: items)
                    }

                    // Split items by type and create windows
                    let groupedItems = self.windowManager.splitItemsByType(newItems)

                    DispatchQueue.main.async {
                        for (type, items) in groupedItems {
                            if type == windowId {
                                // Add to current window if type matches
                                fileTypeState.addItems(items, type: type)
                            } else {
                                // Open new window for different type
                                openWindow(id: type)
                                fileTypeState.addItems(items, type: type)
                            }
                        }
                    }
                }
            }
        }
    }

    func clearImages() {
        fileTypeState.clearItems(type: windowId)
        selectedImageIds.removeAll()
        errorMessage = nil
        conversionProgress = 0.0
    }

    func convertImages() {
        Aptabase.shared.trackEvent("tapped convert", with:
                                    ["output format" : selectedOutputFormat.name]
        )
        guard !fileTypeState.items(for: windowId).isEmpty else { return }
        isConverting = true
        errorMessage = nil

        // Create save panel for output directory
        let savePanel = NSOpenPanel()
        savePanel.canChooseDirectories = true
        savePanel.canChooseFiles = false
        savePanel.allowsMultipleSelection = false
        savePanel.message = "Choose destination folder for converted images"
        savePanel.prompt = "Choose"

        savePanel.begin { response in
            guard response == .OK, let destinationURL = savePanel.url else {
                DispatchQueue.main.async {
                    self.isConverting = false
                }
                return
            }

            // Process images sequentially
            Task {
                let totalCount = fileTypeState.items(for: windowId).count

                for (index, item) in fileTypeState.items(for: windowId).enumerated() {
                    await convertSingleImage(item.image,
                                             destinationURL: destinationURL,
                                             originalURL: item.originalURL,
                                             index: index)

                    // Update UI on main thread
                    await MainActor.run {
                        conversionProgress = Double(index + 1) / Double(totalCount)
                        fileTypeState.updateItemStatus(id: item.id, status: "Done", type: windowId)

                        if index + 1 == totalCount {
                            isConverting = false
                        }
                    }
                }
            }
        }
    }

    func convertSingleImage(_ image: NSImage, destinationURL: URL, originalURL: URL?, index: Int) async {
        // For Base64 input, decode first
        if let inputFormat = currentInputFormat, inputFormat.name == "Base64",
           let originalURL = originalURL,
           let base64Data = try? String(contentsOf: originalURL).data(using: .utf8),
           let decodedData = Data(base64Encoded: base64Data),
           let decodedImage = NSImage(data: decodedData) {
            await convertSingleImage(decodedImage, destinationURL: destinationURL, originalURL: nil, index: index)
            return
        }

        guard let tiffData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData) else { return }

        let filename = originalURL?.deletingPathExtension().lastPathComponent ?? "file_\(index + 1)"
        let fileExtension = selectedOutputFormat.extensions[0]
        let outputURL = destinationURL.appendingPathComponent("\(filename).\(fileExtension)")

        if selectedOutputFormat.name == "Base64" {
            // Convert to Base64
            if let imageData = imageRep.representation(using: .png, properties: [:]) {
                let base64String = imageData.base64EncodedString()
                try? base64String.write(to: outputURL, atomically: true, encoding: .utf8)
            }
            return
        }

        if selectedOutputFormat.utType == .pdf {
            // Create a new PDF document
            let pdfDocument = PDFDocument()

            // Create a PDF page from the image
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
               let page = PDFPage(image: NSImage(cgImage: cgImage, size: image.size)) {
                pdfDocument.insert(page, at: 0)
            }

            // Write PDF to file
            pdfDocument.write(to: outputURL)
            return
        } else if selectedOutputFormat.utType == .rtf || selectedOutputFormat.utType == .plainText {
            // Convert image to text using Vision framework for OCR
            if let cgImage = imageRep.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest { request, error in
                    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

                    let recognizedText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")

                    if selectedOutputFormat.utType == .rtf {
                        // Create attributed string with basic styling
                        let attributedString = NSAttributedString(
                            string: recognizedText,
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 12),
                                .foregroundColor: NSColor.textColor
                            ]
                        )
                        try? attributedString.rtf(from: NSRange(location: 0, length: attributedString.length))?.write(to: outputURL)
                    } else {
                        try? recognizedText.write(to: outputURL, atomically: true, encoding: .utf8)
                    }
                }

                try? handler.perform([request])
            }
            return
        }

        // Handle image formats
        var data: Data?
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]

        switch selectedOutputFormat.name {
        case "PNG":
            data = imageRep.representation(using: .png, properties: properties)
        case "JPEG":
            properties[.compressionFactor] = 0.9
            data = imageRep.representation(using: .jpeg, properties: properties)
        case "TIFF":
            data = imageRep.representation(using: .tiff, properties: properties)
        case "GIF":
            data = imageRep.representation(using: .gif, properties: properties)
        case "BMP":
            data = imageRep.representation(using: .bmp, properties: properties)
        case "HEIC":
            if let cgImage = imageRep.cgImage {
                let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.heic" as CFString, 1, nil)
                if let destination = destination {
                    CGImageDestinationAddImage(destination, cgImage, nil)
                    _ = CGImageDestinationFinalize(destination)
                }
            }
            return
        default:
            return
        }

        if let data = data {
            do {
                try data.write(to: outputURL)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save file \(index + 1): \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteSelectedImages() {
        let selectedItems = fileTypeState.items(for: windowId).filter { selectedImageIds.contains($0.id) }
        fileTypeState.removeItems(selectedItems, type: windowId)
        selectedImageIds.removeAll()
        if fileTypeState.items(for: windowId).isEmpty {
            errorMessage = nil
            conversionProgress = 0.0
        }
    }

    private func selectAllImages() {
        selectedImageIds = Set(fileTypeState.items(for: windowId).map { $0.id })
        if let lastImage = fileTypeState.items(for: windowId).last {
            lastSelectedImageId = lastImage.id
        }
    }

    private func copySelectedImages() {
        let selectedItems = fileTypeState.items(for: windowId).filter { selectedImageIds.contains($0.id) }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Collect URLs of original files
        let fileURLs = selectedItems.compactMap { $0.originalURL }

        if !fileURLs.isEmpty {
            // If we have original files, copy them
            pasteboard.writeObjects(fileURLs as [NSURL])
        } else {
            // If no original files, copy the images as data
            let imageObjects = selectedItems.map { $0.image }
            pasteboard.writeObjects(imageObjects)
        }
    }

    private func pasteImages() {
        let pasteboard = NSPasteboard.general

        // Create an actor to safely collect items
        actor ItemCollector {
            private var items: [ImageItem] = []

            func add(_ item: ImageItem) {
                items.append(item)
            }

            func addItems(_ newItems: [ImageItem]) {
                items.append(contentsOf: newItems)
            }

            func getAllItems() -> [ImageItem] {
                return items
            }
        }

        let collector = ItemCollector()

        Task {
            // Try reading file URLs first
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                print("Found \(urls.count) URLs")
                for url in urls {
                    if let image = NSImage(contentsOf: url) {
                        await collector.add(ImageItem(image: image, originalURL: url))
                    }
                }
            }

            // Try reading file promises
            let items = await collector.getAllItems()
            if items.isEmpty {
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                    print("Found \(urls.count) URLs from promises")
                    for url in urls {
                        if let image = NSImage(contentsOf: url) {
                            await collector.add(ImageItem(image: image, originalURL: url))
                        }
                    }
                }
            }

            // Try reading raw image data
            let currentItems = await collector.getAllItems()
            if currentItems.isEmpty {
                // Try NSImage first
                if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
                    print("Found \(images.count) NSImage objects")
                    for image in images {
                        await collector.add(ImageItem(image: image, originalURL: nil))
                    }
                }

                // Then try various image data formats
                let latestItems = await collector.getAllItems()
                if latestItems.isEmpty {
                    let imageTypes: [NSPasteboard.PasteboardType] = [
                        .tiff,
                        .png,
                        NSPasteboard.PasteboardType(rawValue: "public.jpeg"),
                        NSPasteboard.PasteboardType(rawValue: "public.png"),
                        NSPasteboard.PasteboardType(rawValue: "public.tiff"),
                        .pdf
                    ]

                    for type in imageTypes {
                        if let data = pasteboard.data(forType: type) {
                            print("Found data for type:", type)
                            if let image = NSImage(data: data) {
                                await collector.add(ImageItem(image: image, originalURL: nil))
                                break
                            }
                        }
                    }
                }
            }

            // Get final collection of items
            let newItems = await collector.getAllItems()

            // Add all new images to the appropriate windows
            if !newItems.isEmpty {
                print("Adding \(newItems.count) new images")
                // Split items by type and create windows
                let groupedItems = self.windowManager.splitItemsByType(newItems)

                for (type, items) in groupedItems {
                    if type == self.windowId {
                        // Add to current window if type matches
                        self.fileTypeState.addItems(items, type: type)
                    } else {
                        // Open new window for different type
                        self.openWindow(id: type)
                        self.fileTypeState.addItems(items, type: type)
                    }
                }
            } else {
                print("No images found in pasteboard")
                // Debug: Try to understand what's in the pasteboard
                for type in pasteboard.types ?? [] {
                    if let data = pasteboard.data(forType: type) {
                        print("Data available for type:", type, "size:", data.count)
                    }
                }
            }
        }
    }

    private func cutSelectedImages() {
        copySelectedImages()
        deleteSelectedImages()
    }

    private func renderPDFPage(_ page: PDFPage) async -> NSImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let image = NSImage(size: pageRect.size)

        image.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        image.unlockFocus()

        return image
    }
}

#Preview {
    ContentView(windowId: "Main")
}

extension NSItemProvider {
    func loadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let data = data {
                    continuation.resume(returning: data)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NSError(domain: "NSItemProviderError", code: -1))
                }
            }
        }
    }
    func loadFileURL(forTypeIdentifier typeIdentifier: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { (urlData, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = urlData as? URL {
                    continuation.resume(returning: url)
                } else if let urlData = urlData as? Data,
                          let urlString = String(data: urlData, encoding: .utf8) {
                    let fileURL = URL(fileURLWithPath: urlString.replacingOccurrences(of: "file://", with: ""))
                    continuation.resume(returning: fileURL.resolvingSymlinksInPath())
                } else {
                    continuation.resume(throwing: NSError(domain: "NSItemProvider", code: -1, userInfo: nil))
                }
            }
        }
    }
}
