# Book Scanner

A universal iOS/macOS app for cataloging books by photographing book spines. Built with SwiftUI and SwiftData.

## Features

- **Biometric Authentication**: Secure access using Face ID or Touch ID
- **Camera Integration**: Photograph book spines directly from the app
- **OCR Recognition**: Automatically extracts book title, author, and publisher from spine images
- **SwiftData Storage**: Local database for all book records
- **Full CRUD Operations**: Create, read, update, and delete book entries
- **CSV Export**: Export your entire catalog to CSV format
- **Amazon Integration**: Look up books on Amazon for pricing and links
- **Universal App**: Works on iPhone, iPad, and Mac (iOS 18+ / macOS 14+)
- **Accessibility**: Follows Apple's Human Interface Guidelines and accessibility standards

## Requirements

- Xcode 15.0 or later
- iOS 18.0+ / macOS 14.0+
- Swift 5.9+

## Setup

1. Open `BookScanner.xcodeproj` in Xcode
2. Configure your development team in project settings
3. For Amazon integration, add your Product Advertising API credentials to `AmazonService.swift`
4. Build and run on your device or simulator

## Project Structure

```
BookScanner/
├── BookScannerApp.swift      # App entry point
├── ContentView.swift          # Main tab view
├── Models/
│   └── Book.swift            # SwiftData model
├── Views/
│   ├── AuthenticationView.swift
│   ├── CameraView.swift
│   ├── BookListView.swift
│   ├── BookDetailView.swift
│   └── ExportView.swift
└── Services/
    ├── OCRService.swift      # Vision framework OCR
    ├── CSVExportService.swift
    └── AmazonService.swift   # Amazon Product API
```

## Notes

- OCR recognition uses Apple's Vision framework
- Amazon integration requires Product Advertising API credentials
- All data is stored locally using SwiftData
- Camera and photo library permissions are required
