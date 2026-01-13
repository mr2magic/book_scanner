# Build Instructions

The Xcode project file needs to be created or fixed. To build the project:

## Option 1: Create Project in Xcode (Recommended)

1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App"
4. Product Name: `BookScanner`
5. Interface: SwiftUI
6. Language: Swift
7. Storage: SwiftData
8. Save in: `/Users/Dans_iMac/Desktop/book_scanner/`
9. Replace the generated files with the existing Swift files in `BookScanner/` directory
10. Add all Swift files to the target:
    - BookScannerApp.swift
    - ContentView.swift
    - Models/Book.swift
    - Views/AuthenticationView.swift
    - Views/CameraView.swift
    - Views/BookListView.swift
    - Views/BookDetailView.swift
    - Views/ExportView.swift
    - Services/OCRService.swift
    - Services/CSVExportService.swift
    - Services/AmazonService.swift
11. Add Assets.xcassets, Info.plist, and BookScanner.entitlements
12. Build and run

## Option 2: Fix Project File Manually

The project.pbxproj file has ID conflicts. All file references need unique IDs.

## Current File Structure

```
BookScanner/
├── BookScannerApp.swift
├── ContentView.swift
├── Models/
│   └── Book.swift
├── Views/
│   ├── AuthenticationView.swift
│   ├── CameraView.swift
│   ├── BookListView.swift
│   ├── BookDetailView.swift
│   └── ExportView.swift
├── Services/
│   ├── OCRService.swift
│   ├── CSVExportService.swift
│   └── AmazonService.swift
├── Assets.xcassets/
├── Info.plist
└── BookScanner.entitlements
```

All files are ready - just need a valid Xcode project structure.
