import SwiftUI

@MainActor
class FileTypeState: ObservableObject {
    static let shared = FileTypeState()
    
    @Published var imageItems: [ImageItem] = []
    @Published var pdfItems: [ImageItem] = []
    @Published var textItems: [ImageItem] = []
    @Published var wordItems: [ImageItem] = []
    @Published var spreadsheetItems: [ImageItem] = []
    @Published var presentationItems: [ImageItem] = []
    @Published var otherItems: [ImageItem] = []
    
    private init() {}
    
    func items(for type: String) -> [ImageItem] {
        switch type {
        case "Images":
            return imageItems
        case "PDF Documents":
            return pdfItems
        case "Text Documents":
            return textItems
        case "Word Documents":
            return wordItems
        case "Spreadsheets":
            return spreadsheetItems
        case "Presentations":
            return presentationItems
        case "Other Files":
            return otherItems
        default:
            return []
        }
    }
    
    func addItems(_ items: [ImageItem], type: String) {
        switch type {
        case "Images":
            imageItems.append(contentsOf: items)
        case "PDF Documents":
            pdfItems.append(contentsOf: items)
        case "Text Documents":
            textItems.append(contentsOf: items)
        case "Word Documents":
            wordItems.append(contentsOf: items)
        case "Spreadsheets":
            spreadsheetItems.append(contentsOf: items)
        case "Presentations":
            presentationItems.append(contentsOf: items)
        case "Other Files":
            otherItems.append(contentsOf: items)
        default:
            break
        }
    }
    
    func removeItems(_ items: [ImageItem], type: String) {
        let itemIds = Set(items.map { $0.id })
        switch type {
        case "Images":
            imageItems.removeAll { itemIds.contains($0.id) }
        case "PDF Documents":
            pdfItems.removeAll { itemIds.contains($0.id) }
        case "Text Documents":
            textItems.removeAll { itemIds.contains($0.id) }
        case "Word Documents":
            wordItems.removeAll { itemIds.contains($0.id) }
        case "Spreadsheets":
            spreadsheetItems.removeAll { itemIds.contains($0.id) }
        case "Presentations":
            presentationItems.removeAll { itemIds.contains($0.id) }
        case "Other Files":
            otherItems.removeAll { itemIds.contains($0.id) }
        default:
            break
        }
    }
    
    func clearItems(type: String) {
        switch type {
        case "Images":
            imageItems.removeAll()
        case "PDF Documents":
            pdfItems.removeAll()
        case "Text Documents":
            textItems.removeAll()
        case "Word Documents":
            wordItems.removeAll()
        case "Spreadsheets":
            spreadsheetItems.removeAll()
        case "Presentations":
            presentationItems.removeAll()
        case "Other Files":
            otherItems.removeAll()
        default:
            break
        }
    }
    
    func updateItemStatus(id: UUID, status: String, type: String) {
        switch type {
        case "Images":
            if let index = imageItems.firstIndex(where: { $0.id == id }) {
                imageItems[index].status = status
            }
        case "PDF Documents":
            if let index = pdfItems.firstIndex(where: { $0.id == id }) {
                pdfItems[index].status = status
            }
        case "Text Documents":
            if let index = textItems.firstIndex(where: { $0.id == id }) {
                textItems[index].status = status
            }
        case "Word Documents":
            if let index = wordItems.firstIndex(where: { $0.id == id }) {
                wordItems[index].status = status
            }
        case "Spreadsheets":
            if let index = spreadsheetItems.firstIndex(where: { $0.id == id }) {
                spreadsheetItems[index].status = status
            }
        case "Presentations":
            if let index = presentationItems.firstIndex(where: { $0.id == id }) {
                presentationItems[index].status = status
            }
        case "Other Files":
            if let index = otherItems.firstIndex(where: { $0.id == id }) {
                otherItems[index].status = status
            }
        default:
            break
        }
    }
} 