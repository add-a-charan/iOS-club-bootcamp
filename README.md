# Coffee Passport
### Specialty Coffee Tracker & Cupping Journal for iOS

![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue?logo=apple&logoColor=white)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple?logo=swift&logoColor=white)
![SwiftData](https://img.shields.io/badge/Persistence-SwiftData-green)
![Vision](https://img.shields.io/badge/OCR-Apple%20Vision-red)

An iOS application designed for coffee enthusiasts to log, rate, and track their favorite coffee beans. Inspired by review platforms like Beli, the app allows users to photograph a coffee bag, parse key roast details using on-device text recognition, and keep a personal visual log of their coffee tastings.

---

## Project Overview

The goal of this project is to build a focused MVP that handles coffee bag intake, text recognition, sensory rating, and local storage:

* **Text Recognition (OCR):** Uses Apple's Vision framework (`VNRecognizeTextRequest`) to read printed text from coffee bag photos directly on the device.
* **Photo Log:** Keeps 1–2 photos per entry (front and back of bag) stored alongside the record using SwiftData's external storage support.
* **Cupping & Ratings:** Captures an overall score (`0.0–5.0`), brew method selection (`Filter`, `Espresso`, `Immersion`), and four sensory scales (`Bitterness — Sweetness`, `Acidity`, `Body`, `Funkiness`).
* **Local Persistence:** Uses SwiftData to store records locally on-device.

---

## App Architecture

The app is structured into six core Swift files, separating data models, scanning services, and SwiftUI views:

```
                         CoffeePassportApp.swift
                    (App Entry Point & SwiftData Setup)
                                    │
          ┌─────────────────────────┴────────────────────────┐
          ▼                                                  ▼
   PassportView.swift                               CoffeeBag.swift
     (Home Feed)                                   (SwiftData Model)
          │                                                  ▲
          ├─── [Add Coffee] ──────> AddCoffeeView.swift ─────┤ (saves)
          │                              │                   │
          │                   (uses) ────▼                   │
          │                       CoffeeScanner.swift        │
          │                       (Apple Vision OCR)         │
          │                                                  │
          └─── [Select Row] ──────> CoffeeDetailView.swift ──┘ (reads/deletes)
```

### Components

| File | Type | Description | Documentation |
| :--- | :--- | :--- | :--- |
| **`CoffeePassportApp.swift`** | `struct` | App entry point; configures the SwiftData `modelContainer` and loads the root view. | [App Setup Notes](file:///Users/isaac/Documents/FALL%202026/iOS%20Club%20Fall%202026/CoffeePassportDocs/README_CoffeePassportApp.md) |
| **`CoffeeBag.swift`** | `class` | The SwiftData model (`@Model`) representing a saved coffee record and its cupping scores. | [Model Notes](file:///Users/isaac/Documents/FALL%202026/iOS%20Club%20Fall%202026/CoffeePassportDocs/README_CoffeeBag.md) |
| **`CoffeeScanner.swift`** | `class` | Service that runs Apple Vision OCR on selected photos and parses candidate text fields. | [Scanner Notes](file:///Users/isaac/Documents/FALL%202026/iOS%20Club%20Fall%202026/CoffeePassportDocs/README_CoffeeScanner.md) |
| **`PassportView.swift`** | `struct` | Main screen displaying the saved coffee feed using `@Query` and navigation links. | [Feed View Notes](file:///Users/isaac/Documents/FALL%202026/iOS%20Club%20Fall%202026/CoffeePassportDocs/README_PassportView.md) |
| **`AddCoffeeView.swift`** | `struct` | Modal form to select photos, run OCR, review pre-filled details, rate, and save. | [Add View Notes](file:///Users/isaac/Documents/FALL%202026/iOS%20Club%20Fall%202026/CoffeePassportDocs/README_AddCoffeeView.md) |
| **`CoffeeDetailView.swift`** | `struct` | Detail view displaying the photo gallery, coffee information, cupping scores, and delete option. | [Detail View Notes](file:///Users/isaac/Documents/FALL%202026/iOS%20Club%20Fall%202026/CoffeePassportDocs/README_CoffeeDetailView.md) |

---

## Data Flow

```
[PassportView] ─────────────────────────> Tap "+ Add Coffee"
       │
       ▼
[AddCoffeeView] ────────────────────────> Select 1–2 photos (front and back)
       │                                  Photos stored in memory for saving
       ▼
[CoffeeScanner] ────────────────────────> Runs VNRecognizeTextRequest
       │                                  Extracts candidate fields (Roaster, Name, Origin, etc.)
       ▼
[AddCoffeeView] ────────────────────────> User reviews and edits pre-filled fields:
       │                                  • Verify roaster and coffee name
       │                                  • Set overall rating (0.0–5.0)
       │                                  • Select brew method (Filter, Espresso, Immersion)
       │                                  • Adjust sensory sliders (0.0–5.0)
       │                                  • Add personal notes
       ▼
[SwiftData ModelContext] ──────────────> Insert CoffeeBag record and commit to local database
       │
       ▼
[PassportView] ─────────────────────────> Updates feed view with the new coffee
```

---

## Technical Design Notes

* **Model vs. View Types:** `CoffeeBag` is a reference type (`class`) as required by SwiftData for entity tracking and persistence. All views (`PassportView`, `AddCoffeeView`, `CoffeeDetailView`) and data transfer objects (`CoffeeDetails`) are value types (`struct`).
* **Photo Storage:** Photos are stored as binary `Data` on the `CoffeeBag` model. The `@Attribute(.externalStorage)` attribute instructs SwiftData to save large binary blobs outside the SQLite file to keep database queries responsive.
* **Vision Integration:** Image recognition is wrapped in an `async` method using `withCheckedThrowingContinuation` to bridge the closure-based Vision API with modern Swift concurrency.
* **Controlled Vocabularies:** `BrewMethod` and `OriginType` are implemented as Swift enums with raw string values to avoid typos and restrict options to valid cases.
* **View Updates:** The home feed relies on SwiftData's `@Query` macro to stay synchronized with the database without manual notification handling.

---

## Requirements

* **Platform:** iOS 17.0+
* **Language:** Swift 5.9+
* **Frameworks:** SwiftUI, SwiftData, Vision, PhotosUI
* **Tools:** Xcode 15.0+
