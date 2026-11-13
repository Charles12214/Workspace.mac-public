# Workspace.mac — Native Google Workspace Client for macOS

A fast, lightweight, distraction-free native macOS client for **Google Workspace & Gemini AI**. Designed to eliminate browser tab clutter by bringing all 18 Google Workspace apps into a single, unified desktop experience with liquid glass materials, multi-window Groups, and modern macOS theming.

**100% Free, Fully Open-Source, and Local.** Zero paywalls, zero ads, zero telemetry.

---

## 🔒 Privacy & Open-Source Transparency

With version **V1.3.0**, Workspace.mac is **100% open-source**. When a desktop app requests system permissions, users deserve complete transparency.

- **Location Permission for Ambient Weather:**
  - Workspace.mac includes an optional ambient weather and local clock widget.
  - When enabled, it requests macOS Location permission solely to query the free, open [Open-Meteo](https://open-meteo.com) API for local temperature and conditions.
  - **Your coordinates are never stored, logged, tracked, or sent to any server.**
  - **Completely Optional:** Weather can be skipped during onboarding or toggled off anytime in Settings.
- **Zero Telemetry & Zero Trackers:**
  - No analytics SDKs, no event trackers, no user fingerprinting, and no background pings.
- **Local Sandboxed Authentication:**
  - All Google sessions, cookies, and OAuth tokens remain strictly inside Apple's native WebKit website data store on your Mac.

---

## ✨ Features at a Glance

- **18 Unified Workspace Apps**: Docs, Sheets, Slides, Drive, Gmail, Calendar, Meet, Chat, Keep, NotebookLM, Forms, Sites, Contacts, Tasks, Classroom, Cloud, Admin, and Gemini.
- **Multi-App Tiling & "Groups" (Up to 4 Apps)**:
  - Drag and drop apps from the sidebar onto split-screen drop zones (2, 3, or 4 panes).
  - Save multi-window layouts as **Groups** directly onto your Home dashboard.
  - Native macOS File menu integration (`⌘S`, `⇧⌘S`, `⇧⌘R`, `⌥⌘W`) with dynamic state handling.
  - Double-click inline group renaming on Home.
  - Persistent `WebKitPool` and `WebKitHostView` architecture ensuring zero reloads or lost edits when moving or resizing panes.
- **Ambient Weather & Local Time Dashboard**:
  - Live clock and weather readout in the top bar and Home dashboard.
  - Multi-hour forecast popover with high/low temperatures.
  - 100% private, optional, and battery-friendly.
- **Gemini AI Integration**: Dedicated Gemini assistant view, customized AI Tier badges (Plus, Pro, Ultra), and ambient avatar gradient rings.
- **3 Adaptive Layout Modes**:
  - **Everything**: Docked sidebar + top navigation bar.
  - **Essentials**: Compact top navigation bar only, with quick sidebar access.
  - **At a glance**: Edge-to-edge fullscreen immersion with top-middle hover controls and a draggable bookmark tab.
- **True macOS Appearance**: Real-time automatic Light/Dark mode detection matching your Mac's system appearance.
- **Local Workspace Profile**: Personalized First/Last/Nickname greeting engine with animated letter-by-letter blur transitions, custom avatar photos, and multi-account switcher (up to 5 accounts).
- **Authentic Google Sign-In**: Powered by Apple's sandboxed WebKit container. Passwords, 2FA, and sessions are processed directly by Google. Logging in once keeps you signed in across all apps.
- **Biometric Security**: Built-in Touch ID and Apple Secure Enclave passkey protection.
- **Collapsible Dashboard**: Quick search, customizable Pinned apps, Saved Groups, and collapsible Recently Used drawer.

---

## 📥 Installation

Download the latest release from the [Releases](https://github.com/Charles12214/Workspace.mac/releases) tab:

1. Open **`Workspace.mac.dmg`**.
2. Drag **`Workspace.mac.app`** into your **Applications** folder.
3. Launch **Workspace.mac** and enjoy!

*(Alternatively, run the **`Workspace.mac.pkg`** installer for guided 1-click installation).*

---

## 🛠 Building from Source

Requires macOS 14.0+ and Xcode Command Line Tools.

```bash
# Clone the repository
git clone https://github.com/Charles12214/Workspace.mac.git
cd Workspace.mac

# Build the release app bundle
./build_app.sh

# Or build the full DMG & PKG installers
./build_installer.sh
```

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](file:///Users/charliecserfalvi-smith/Library/CloudStorage/GoogleDrive-ccserfalvismith@gmail.com/My%20Drive/Workspace%20(APP)/LICENSE) for more information.
