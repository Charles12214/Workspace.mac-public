# Workspace Docs Offline (Open-Source Web Extension)

**Workspace Docs Offline** is a fully open-source WebExtension (Manifest V3) created for [Workspace.mac](https://github.com/workspace-mac/workspace). It provides native offline editing and caching support for **Google Docs, Google Sheets, Google Slides, and Google Drive** without requiring Google Chrome or proprietary closed-source extensions.

---

## 🌟 Features

* **100% Open-Source & Transparent:** Free of proprietary telemetry, tracking, or remote analytics.
* **Manifest V3 Compliant:** Complete extension manifest with background service worker, content scripts, and page-level engine.
* **Native Offline Capabilities:**
  * Shims `chrome.runtime` and `chrome.storage` APIs expected by Google Docs clients.
  * Responds to Google Docs offline health checks (`getOfflineStatus`, `setOfflineStatus`, `ping`).
  * Enables IndexedDB offline document caching inside WebKit / Safari and Chromium browsers.
  * Allows offline document viewing, creation, and editing in Google Docs, Sheets, and Slides.
  * Suppresses "Switch to Google Chrome" artificial barrier banners.

---

## 📁 Architecture

```
Extensions/WorkspaceDocsOffline/
├── manifest.json       # Manifest V3 extension configuration
├── background.js       # Background service worker & IndexedDB document cache manager
├── content.js          # Content script injected at document_start into *.google.com
├── offline-engine.js   # In-page DOM engine & offline banner suppression
├── README.md           # Documentation
└── icons/              # Extension icons (16px, 48px, 128px)
```

---

## 🔧 How It Works

1. **Bootstrap Handshake:** When Google Docs, Sheets, or Slides load, their client scripts probe for extension ID `ghbmnnjooekpmoecnnnilnnbdlolhkhi`.
2. **API Polyfill:** `content.js` satisfies the Google Docs API probe at `document_start` before any Google scripts run.
3. **Local Storage Engine:** `background.js` manages an IndexedDB database (`WorkspaceDocsOfflineDB`) storing document snapshots and pending mutation logs.
4. **Seamless Offline Editing:** When the Mac is offline, Google Docs continues running seamlessly without network timeouts or blocking modals. Edits sync back to Google Drive automatically once reconnected.

---

## 📜 License

MIT License • 100% Free and Open-Source.
