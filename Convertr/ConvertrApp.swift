//
//  ConvertrApp.swift
//  Convertr
//
//  Created by Hannes Nagel on 3/4/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("autoSplitTypes") private var autoSplitTypes = true
    @AppStorage("defaultImageFormat") private var defaultImageFormat = "PNG"
    @AppStorage("defaultDocumentFormat") private var defaultDocumentFormat = "PDF"
    @AppStorage("jpegQuality") private var jpegQuality = 0.9
    @AppStorage("showThumbnails") private var showThumbnails = true
    @AppStorage("thumbnailSize") private var thumbnailSize = 80.0
    
    var body: some View {
        TabView {
            Form {
                Section("General") {
                    Toggle("Automatically split different file types", isOn: $autoSplitTypes)
                    Toggle("Show thumbnails in grid", isOn: $showThumbnails)
                    
                    if showThumbnails {
                        HStack {
                            Slider(value: $thumbnailSize, in: 40...200) {
                                Text("Thumbnail size")
                            }
                            Text("\(Int(thumbnailSize))px")
                        }
                    }
                }
                
                Section("Default Formats") {
                    Picker("Default Image Format", selection: $defaultImageFormat) {
                        Text("PNG").tag("PNG")
                        Text("JPEG").tag("JPEG")
                        Text("TIFF").tag("TIFF")
                        Text("HEIC").tag("HEIC")
                    }
                    
                    Picker("Default Document Format", selection: $defaultDocumentFormat) {
                        Text("PDF").tag("PDF")
                        Text("RTF").tag("RTF")
                        Text("Plain Text").tag("Plain Text")
                    }
                }
                
                Section("Quality Settings") {
                    HStack {
                        Text("JPEG Quality")
                        Slider(value: $jpegQuality, in: 0...1) {
                            Text("JPEG Quality")
                        }
                        Text("\(Int(jpegQuality * 100))%")
                    }
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            Form {
                Section("About") {
                    Text("Convertr")
                        .font(.title)
                    Text("Version 1.0")
                    Text("A versatile file conversion tool")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 400, height: 300)
    }
}

import Aptabase

@main
struct ConvertrApp: App {
    @StateObject private var windowManager = ConversionWindowManager()
    @StateObject private var fileTypeState = FileTypeState.shared

    init(){
        Aptabase.shared.initialize(appKey: "A-SH-2536426356", with: .init(host: "https://analytics.hannesnagel.com"), userDefaultsGroup: nil)
    }

    var body: some Scene {
        
        // Images window
        Window("Images", id: "Images") {
            ConversionWindow(windowId: "Images")
                .environmentObject(windowManager)
                .onAppear{
                    Aptabase.shared.trackEvent("Opened Images Window")
                }
        }
        
        // PDF Documents window
        Window("PDF Documents", id: "PDF Documents") {
            ConversionWindow(windowId: "PDF Documents")
                .environmentObject(windowManager)
                .onAppear {
                    Aptabase.shared.trackEvent("Opened PDF Documents Window")
                }
        }
        
        // Text Documents window
        Window("Text Documents", id: "Text Documents") {
            ConversionWindow(windowId: "Text Documents")
                .environmentObject(windowManager)
                .onAppear {
                    Aptabase.shared.trackEvent("Opened Text Documents Window")
                }
        }
        
        // Word Documents window
        Window("Word Documents", id: "Word Documents") {
            ConversionWindow(windowId: "Word Documents")
                .environmentObject(windowManager)
                .onAppear {
                    Aptabase.shared.trackEvent("Opened Word Documents Window")
                }
        }
        
        // Spreadsheets window
        Window("Spreadsheets", id: "Spreadsheets") {
            ConversionWindow(windowId: "Spreadsheets")
                .environmentObject(windowManager)
                .onAppear {
                    Aptabase.shared.trackEvent("Opened Spreadsheets Window")
                }
        }
        
        // Presentations window
        Window("Presentations", id: "Presentations") {
            ConversionWindow(windowId: "Presentations")
                .environmentObject(windowManager)
                .onAppear {
                    Aptabase.shared.trackEvent("Opened Presentations Window")
                }
        }
        
        // Other Files window
        Window("Other Files", id: "Other Files") {
            ConversionWindow(windowId: "Other Files")
                .environmentObject(windowManager)
                .onAppear {
                    Aptabase.shared.trackEvent("Opened Other Files Window")
                }
        }
        
        Settings {
            SettingsView()
                .onAppear {
                    Aptabase.shared.trackEvent("Opened Settings")
                }
        }
    }
}
