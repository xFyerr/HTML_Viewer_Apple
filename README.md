# HTML Viewer — Native iOS App

A polished, minimal HTML file viewer for iPhone and iPad. Open local `.html` files directly from the Files app — including Claude-generated HTML artifacts saved to your device — and view them in a true full-screen experience with no intrusive navigation chrome.

---

## Features

| Feature | Detail |
|---|---|
| Full-screen viewer | WKWebView fills every pixel — no top bar, no forced chrome |
| Floating back button | Tap anywhere to show/hide; auto-hides after 3 s |
| Recents screen | Remembers your last 20 opened files using secure bookmarks |
| Local asset loading | CSS, JS, and images in the same folder load automatically |
| Open from Files | UIDocumentPicker integration; also handles "Open With" from other apps |
| Offline / on-device | No network requests, no cloud, no backend |
| Dark theme | #1A1A1A background, amber accent, system SF Pro fonts |

---

## Project Structure

```
HTMLViewer/
├── HTMLViewerApp.swift             # @main entry — wires up the environment and handles onOpenURL
├── Info.plist                      # Document types, file-sharing entitlements
├── Assets.xcassets/                # Accent colour, app icon placeholder
│
├── Models/
│   ├── HTMLFile.swift              # Codable data model; resolves security-scoped bookmarks
│   └── RecentFilesManager.swift    # ObservableObject; persists recents to UserDefaults
│
├── Views/
│   ├── HomeView.swift              # Recents list / empty state; drives navigation
│   ├── HTMLViewerView.swift        # Full-screen viewer; floating back button overlay
│   └── Components/
│       ├── EmptyStateView.swift    # "No Recent Files" placeholder
│       └── RecentFileRow.swift     # Single row in the recents list
│
├── WebView/
│   └── WebViewWrapper.swift        # UIViewRepresentable for WKWebView; manages security scope
│
├── Pickers/
│   └── DocumentPickerView.swift    # UIViewControllerRepresentable for UIDocumentPickerViewController
│
└── Extensions/
    └── Color+Hex.swift             # Color(hex:) and UIColor(hex:) initialisers
```

---

## How it Works

### Home Screen
`HomeView` is the root view. It holds an `@EnvironmentObject` reference to `RecentFilesManager`.

- **Empty state** — shown when the recents list is empty. "Open from Files" button presents `DocumentPickerView`.
- **Recents list** — each row is tappable and navigates to `HTMLViewerView` via `.fullScreenCover`.
- **Context menu** — long-press any row for "Remove from Recents".
- **`onOpenURL`** — if another app (Files, Safari, Mail) hands off a `.html` file, `HTMLViewerApp` catches it and passes it down through the `pendingURL` binding.

### File Persistence (Bookmarks)
iOS gives us a **security-scoped URL** when the user picks a file. That URL expires when the app restarts.
`RecentFilesManager.addFile(url:)` converts it to **bookmark data** (`.minimalBookmark`) and stores it in `UserDefaults`. On next launch, `HTMLFile.resolveURL()` reconstructs the live URL from the bookmark, calling `startAccessingSecurityScopedResource()` as needed.

### HTML Viewer
`HTMLViewerView` presents `WebViewWrapper` with `.ignoresSafeArea()` so it bleeds edge-to-edge under the status bar and home indicator.

`WebViewWrapper` (a `UIViewRepresentable`):
1. Creates a `WKWebView` with `contentInsetAdjustmentBehavior = .never` so nothing shifts the content.
2. Calls `url.startAccessingSecurityScopedResource()` before loading.
3. Loads via `webView.loadFileURL(url, allowingReadAccessTo: parentDirectory)` — this lets the HTML file reference CSS/JS/images in the same folder.
4. Releases the security scope in `static func dismantleUIView` when the view is destroyed.

---

## Setting Up in Xcode

> **Requirement:** Xcode 15 or later. A free Apple ID works for sideloading (7-day certificate).

### 1. Create the Xcode Project

1. Open Xcode → **File › New › Project…**
2. Choose **iOS › App**
3. Fill in:
   - **Product Name:** `HTMLViewer`
   - **Bundle Identifier:** `com.yourname.htmlviewer` *(anything unique)*
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployments:** iOS 16.0 (or higher)
4. **Uncheck** "Include Tests"
5. Save into a folder — **not** inside this repo yet.

### 2. Replace the Generated Files

Delete everything Xcode created inside the `HTMLViewer/` group (right-click → Move to Trash):
- `ContentView.swift`
- `HTMLViewerApp.swift` *(Xcode generated one — replace it)*

Then drag all the files from this repo's `HTMLViewer/` folder into the Xcode `HTMLViewer` group. When prompted:
- **Copy items if needed** ✅
- **Add to target: HTMLViewer** ✅

Keep the folder structure: create Groups in Xcode matching `Models/`, `Views/`, `Views/Components/`, `WebView/`, `Pickers/`, `Extensions/`.

### 3. Replace the Info.plist

Xcode 14+ stores Info.plist values in the project settings. Do the following:

1. Select the project root in the file navigator → **HTMLViewer target → Info tab**
2. Add these keys:

| Key | Type | Value |
|---|---|---|
| `UIFileSharingEnabled` | Boolean | YES |
| `LSSupportsOpeningDocumentsInPlace` | Boolean | YES |
| `CFBundleDocumentTypes` | Array | *(see below)* |

For `CFBundleDocumentTypes`, add one Dictionary entry:

```
CFBundleTypeExtensions     Array   → html, htm
CFBundleTypeName           String  → HTML Document
CFBundleTypeRole           String  → Viewer
LSHandlerRank              String  → Alternate
LSItemContentTypes         Array   → public.html, public.xhtml
```

Alternatively, copy `HTMLViewer/Info.plist` from this repo into your Xcode project folder and set **Info.plist File** in Build Settings to point to it.

### 4. Set the Signing Team

1. Select the project → **HTMLViewer target → Signing & Capabilities**
2. Set **Team** to your Apple ID (sign in via Xcode Preferences › Accounts if needed)
3. Xcode will auto-manage the provisioning profile

---

## Building & Running on iPhone or iPad

### Via USB (Recommended)

1. Connect your iPhone or iPad with a USB cable
2. Trust the Mac on your device if prompted
3. In Xcode, select your device in the device picker at the top
4. Press **⌘ R** (or the ▶ button)
5. Xcode builds and installs the app. The first run may ask you to trust the developer on the device:
   - Go to **Settings › General › VPN & Device Management**
   - Tap your Apple ID → **Trust**

### Free Developer Account — 7-Day Limit

A free Apple ID certificate expires every **7 days**. To renew:
- Reconnect your device, open Xcode, and run again (⌘ R). Xcode re-signs automatically.

To avoid this, sign up for the **$99/year Apple Developer Program** — certificates last a year.

---

## Sideloading Without a Mac (AltStore / Sideloadly)

If you don't have Xcode access, you can install a pre-built `.ipa`:

### Build an .ipa from Xcode
1. In Xcode: **Product › Archive**
2. After archiving: **Distribute App → Development → Export**
3. This produces an `.ipa` file

### Install with AltStore
1. Install **AltStore** on your PC/Mac and the **AltStore** app on your iPhone or iPad (altstore.io)
2. Open AltStore on your device → **My Apps** → **+** → select the `.ipa`
3. AltStore re-signs and installs it

### Install with Sideloadly
1. Download **Sideloadly** (sideloadly.io)
2. Connect your iPhone or iPad via USB
3. Drop the `.ipa` into Sideloadly, enter your Apple ID, click **Start**
4. Trust the certificate on your device (same Settings path as above)

---

## Using the App

1. **Home screen** shows your recently opened files (or the empty state on first launch)
2. Tap **"Open from Files"** (or the folder-badge icon, top right) to browse the Files app
3. Select any `.html` file — it opens immediately in full-screen
4. **Tap anywhere** on the viewer to show the floating Back button
5. The Back button auto-hides after 3 seconds for a clean immersive view
6. The HTML file can reference assets (images, CSS, JS) stored in the same folder — they load automatically
7. Long-press any recent file to remove it from the list

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Unable to open file" | The file was moved/deleted. Open it again from Files. |
| White/blank page | The HTML may reference absolute paths not present on the device. Check the HTML's asset paths. |
| "Untrusted Developer" alert | Settings › General › VPN & Device Management → trust your Apple ID |
| App crashes at launch | Make sure all source files are added to the HTMLViewer target in Xcode (File Inspector → Target Membership) |
| CSS/JS not loading | Put all assets in the same folder as the HTML file. The app grants read access to the parent folder only. |
