# Workspace.mac — Native Google Workspace Client for macOS

A fast, lightweight, distraction-free native macOS client for **Google Workspace & Gemini AI**. Designed to eliminate browser tab clutter by bringing all 18 Google Workspace apps into a single, unified desktop experience with liquid glass materials and modern macOS theming.

**100% Free, Private, and Local.** Zero paywalls, zero ads, zero telemetry.

---

## ✨ Features at a Glance

- **18 Unified Workspace Apps**: Docs, Sheets, Slides, Drive, Gmail, Calendar, Meet, Chat, Keep, NotebookLM, Forms, Sites, Contacts, Tasks, Classroom, Cloud, Admin, and Gemini.
- **Gemini AI Integration**: Dedicated Gemini assistant view, customized AI Tier badges (Plus, Pro, Ultra), and ambient avatar gradient rings.
- **3 Adaptive Layout Modes**:
  - **Everything**: Docked sidebar + top navigation bar.
  - **Essentials**: Compact top navigation bar only, with quick sidebar access.
  - **At a glance**: Edge-to-edge fullscreen immersion with top-middle hover controls and a draggable bookmark tab.
- **True macOS Appearance**: Real-time automatic Light/Dark mode detection matching your Mac's system appearance.
- **Local Workspace Profile**: Personalized First/Last/Nickname greeting engine with animated letter-by-letter blur transitions, custom avatar photos, and greeting widgets.
- **Authentic Google Sign-In**: Powered by a sandboxed WebKit container. Passwords, 2FA, and sessions are processed directly by Google. Logging in once keeps you signed in across all apps.
- **Biometric Security**: Built-in Touch ID and Apple Secure Enclave passkey protection.
- **Collapsible Dashboard**: Quick search, customizable Pinned apps, and collapsible Recently Used drawer.

---

## 📥 Installation

Download the latest release from the [Releases](https://github.com/Charles12214/Workspace.mac/releases) tab:

1. Open **`Workspace.mac-1.0.0.dmg`**.
2. Drag **`Workspace.mac.app`** into your **Applications** folder.
3. Launch **Workspace.mac** and enjoy!

*(Alternatively, run the **`Workspace.mac-1.0.0.pkg`** installer for guided 1-click installation).*

---

## 🛠 Building from Source

Requires macOS 13.0+ and Xcode Command Line Tools.

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

## 🗺 Roadmap

- [ ] Inbuilt Google account preference and bookmark syncing
- [ ] Offline document caching & local quick-edit integration
- [ ] Global `Cmd+K` Quick Switcher palette
- [ ] Split-View multitasking (draft Docs alongside Gemini AI)
- [ ] macOS Menu Bar quick companion for Tasks & Calendar agenda
- [ ] Continuous WebKit performance and memory optimization

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
