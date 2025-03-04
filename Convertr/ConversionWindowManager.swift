import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import QuickLookThumbnailing
import AppKit

@MainActor
class ConversionWindowManager: ObservableObject {
    @Published var activeWindowId: String?
    @AppStorage("autoSplitTypes") var autoSplitTypes = true
    private var openWindow: (String) -> Void = { _ in }
    
    func setOpenWindow(_ action: @escaping (String) -> Void) {
        self.openWindow = action
    }
    
    func createNewWindow(for items: [ImageItem], title: String, sourceWindowId: String? = nil) {
        print("\n=== Window Creation ===")
        print("Source window ID:", sourceWindowId ?? "none")
        
        // Open the window for the appropriate type
        let type = title.replacingOccurrences(of: "Convertr - ", with: "")
        openWindow(type)
        
        // Add items to the FileTypeState
        FileTypeState.shared.addItems(items, type: type)
        
        // Animate the window position if we have a source window
        if let sourceWindowId = sourceWindowId,
           let sourceWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == sourceWindowId }),
           let newWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == type }) {
            
            let sourceFrame = sourceWindow.frame
            
            // Calculate new frames for animation
            let newWidth = max(400, sourceFrame.width / 2)
            let finalSourceX = max(20, sourceFrame.origin.x)
            let finalNewX = min((NSScreen.main?.frame.maxX ?? 0) - newWidth - 20, finalSourceX + newWidth)
            
            print("\n=== Animation Targets ===")
            print("Source window will move to: x:", finalSourceX, "width:", newWidth)
            print("New window will move to: x:", finalNewX, "width:", newWidth)
            
            // Animate window positions
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                sourceWindow.animator().setFrame(
                    CGRect(
                        x: finalSourceX,
                        y: sourceFrame.origin.y,
                        width: newWidth,
                        height: sourceFrame.height
                    ),
                    display: true
                )
                
                newWindow.animator().setFrame(
                    CGRect(
                        x: finalNewX,
                        y: sourceFrame.origin.y,
                        width: newWidth,
                        height: sourceFrame.height
                    ),
                    display: true
                )
            }
        }
        
        activeWindowId = type
    }
    
    func splitItemsByType(_ items: [ImageItem]) -> [String: [ImageItem]] {
        guard autoSplitTypes else {
            return ["All Files": items]
        }
        
        var groupedItems: [String: [ImageItem]] = [:]
        
        for item in items {
            let type = determineItemType(item)
            groupedItems[type, default: []].append(item)
        }
        
        return groupedItems
    }
    
    private func determineItemType(_ item: ImageItem) -> String {
        guard let url = item.originalURL else { return "Images" }
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "PDF Documents"
        case "rtf", "txt", "text":
            return "Text Documents"
        case "png", "jpg", "jpeg", "heic", "tiff", "gif", "bmp":
            return "Images"
        case "doc", "docx":
            return "Word Documents"
        case "xls", "xlsx":
            return "Spreadsheets"
        case "ppt", "pptx":
            return "Presentations"
        default:
            // Try to determine type by UTType if extension is unknown
            if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
               let uttype = UTType(uti) {
                switch uttype {
                case _ where uttype.conforms(to: .image):
                    return "Images"
                case _ where uttype.conforms(to: .text):
                    return "Text Documents"
                case _ where uttype.conforms(to: .pdf):
                    return "PDF Documents"
                default:
                    return "Other Files"
                }
            }
            return "Other Files"
        }
    }
    
    func closeWindow(with id: String) {
        if activeWindowId == id {
            activeWindowId = nil
        }
    }
}

// MARK: - Window Scene
struct ConversionWindow: View {
    let windowId: String
    @StateObject private var fileTypeState = FileTypeState.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var windowManager: ConversionWindowManager
    
    var body: some View {
        ContentView(windowId: windowId)
            .onDisappear {
                windowManager.closeWindow(with: windowId)
            }
    }
} 
