/**
 * Workspace Docs Offline - Content Script
 * Injected into docs.google.com, sheets.google.com, slides.google.com, drive.google.com
 * License: MIT
 */

(function() {
  if (window.__workspaceDocsOfflineContentInjected) return;
  window.__workspaceDocsOfflineContentInjected = true;

  const EXT_ID = "ghbmnnjooekpmoecnnnilnnbdlolhkhi";

  // Ensure window.chrome namespace
  window.chrome = window.chrome || {};

  // Polyfill chrome.app
  window.chrome.app = window.chrome.app || {
    isInstalled: true,
    InstallState: { DISABLED: "disabled", INSTALLED: "installed", NOT_INSTALLED: "not_installed" },
    RunningState: { CANNOT_RUN: "cannot_run", READY_TO_RUN: "ready_to_run", RUNNING: "running" },
    getDetails: function() { return { id: EXT_ID, isInstalled: true }; },
    getIsInstalled: function() { return true; },
    installState: function(cb) { if (cb) cb("installed"); }
  };

  // Polyfill chrome.runtime
  window.chrome.runtime = window.chrome.runtime || {
    id: EXT_ID,

    getManifest: function() {
      return {
        name: "Google Docs Offline (Workspace.mac Engine)",
        version: "1.74.0",
        manifest_version: 3,
        description: "Open-source offline editor bridge for Workspace.mac"
      };
    },

    getURL: function(path) {
      return "chrome-extension://" + EXT_ID + "/" + (path || "");
    },

    sendMessage: function(targetId, message, options, callback) {
      let cb = typeof options === 'function' ? options : callback;
      if (typeof targetId === 'object') {
        cb = message;
        message = targetId;
        targetId = EXT_ID;
      }

      const type = (message && message.type) || (message && message.action) || (message && message.command) || '';

      let response = {
        success: true,
        installed: true,
        isInstalled: true,
        offlineStatus: 'ENABLED',
        enabled: true,
        version: '1.74.0',
        diagnostics: {
          isIndexedDbAvailable: true,
          isFileSystemAvailable: true
        }
      };

      if (type === 'getOfflineStatus' || type === 'getStatus') {
        response = {
          status: 'ENABLED',
          isOfflineAvailable: true,
          isOfflineEnabled: true,
          enabled: true,
          version: '1.74.0',
          diagnostics: {
            isIndexedDbAvailable: true,
            isFileSystemAvailable: true
          }
        };
      } else if (type === 'ping' || type === 'isInstalled') {
        response = {
          installed: true,
          version: '1.74.0',
          status: 'OK'
        };
      } else if (type === 'setOfflineStatus') {
        response = { success: true, status: 'ENABLED' };
      }

      if (cb && typeof cb === 'function') {
        setTimeout(() => cb(response), 0);
      }
      return Promise.resolve(response);
    },

    connect: function(targetId, connectInfo) {
      const portName = connectInfo ? connectInfo.name : 'workspace_offline_port';
      const messageListeners = [];
      const disconnectListeners = [];

      return {
        name: portName,
        onMessage: {
          addListener: function(fn) { messageListeners.push(fn); },
          removeListener: function(fn) {
            const idx = messageListeners.indexOf(fn);
            if (idx >= 0) messageListeners.splice(idx, 1);
          }
        },
        onDisconnect: {
          addListener: function(fn) { disconnectListeners.push(fn); },
          removeListener: function(fn) {
            const idx = disconnectListeners.indexOf(fn);
            if (idx >= 0) disconnectListeners.splice(idx, 1);
          }
        },
        postMessage: function(msg) {
          setTimeout(() => {
            for (let i = 0; i < messageListeners.length; i++) {
              try { messageListeners[i]({ status: 'ACK', type: msg ? msg.type : '' }); } catch(e) {}
            }
          }, 0);
        },
        disconnect: function() {
          for (let i = 0; i < disconnectListeners.length; i++) {
            try { disconnectListeners[i](); } catch(e) {}
          }
        }
      };
    },

    onMessage: { addListener: function() {}, removeListener: function() {} },
    onConnect: { addListener: function() {}, removeListener: function() {} }
  };

  // Polyfill chrome.storage
  window.chrome.storage = window.chrome.storage || {
    local: {
      get: function(keys, cb) {
        if (cb && typeof cb === 'function') setTimeout(() => cb({}), 0);
        return Promise.resolve({});
      },
      set: function(items, cb) {
        if (cb && typeof cb === 'function') setTimeout(() => cb(), 0);
        return Promise.resolve();
      },
      remove: function(keys, cb) {
        if (cb && typeof cb === 'function') setTimeout(() => cb(), 0);
        return Promise.resolve();
      }
    },
    sync: {
      get: function(keys, cb) {
        if (cb && typeof cb === 'function') setTimeout(() => cb({}), 0);
        return Promise.resolve({});
      },
      set: function(items, cb) {
        if (cb && typeof cb === 'function') setTimeout(() => cb(), 0);
        return Promise.resolve();
      },
      remove: function(keys, cb) {
        if (cb && typeof cb === 'function') setTimeout(() => cb(), 0);
        return Promise.resolve();
      }
    }
  };

  // Inject Offline Engine Script into page context
  try {
    const s = document.createElement('script');
    s.src = (window.chrome && window.chrome.runtime && window.chrome.runtime.getURL) ? window.chrome.runtime.getURL('offline-engine.js') : '';
    s.onload = function() { this.remove(); };
    (document.head || document.documentElement).appendChild(s);
  } catch(e) {}

  // ==========================================
  // Smart Document Tracker & Auto-Sync Engine
  // ==========================================
  function trackCurrentDocument() {
    const path = window.location.pathname || '';
    let docType = null;
    let exportFormat = 'docx';
    let docId = null;

    const docMatch = path.match(/\/document\/d\/([a-zA-Z0-9_-]+)/);
    const sheetMatch = path.match(/\/spreadsheets\/d\/([a-zA-Z0-9_-]+)/);
    const slideMatch = path.match(/\/presentation\/d\/([a-zA-Z0-9_-]+)/);

    if (docMatch) {
      docType = 'docs';
      docId = docMatch[1];
      exportFormat = 'docx';
    } else if (sheetMatch) {
      docType = 'sheets';
      docId = sheetMatch[1];
      exportFormat = 'xlsx';
    } else if (slideMatch) {
      docType = 'slides';
      docId = slideMatch[1];
      exportFormat = 'pptx';
    }

    if (!docId || !docType) return;

    let rawTitle = '';
    const titleInput = document.querySelector('input.docs-title-input');
    if (titleInput && titleInput.value && titleInput.value.trim()) {
      rawTitle = titleInput.value.trim();
    } else {
      const titleWidget = document.querySelector('.docs-title-widget, .docs-title-inner');
      if (titleWidget && titleWidget.textContent && titleWidget.textContent.trim()) {
        rawTitle = titleWidget.textContent.trim();
      } else if (document.title) {
        rawTitle = document.title
          .replace(/ - Google (Docs|Sheets|Slides|Drive)$/i, '')
          .replace(/ - Google (Documenten|Spreadsheets|Presentaties)$/i, '')
          .trim();
      }
    }

    if (!rawTitle || rawTitle === 'Google Docs' || rawTitle === 'Google Sheets' || rawTitle === 'Google Slides') {
      rawTitle = 'Untitled ' + (docType === 'docs' ? 'Document' : docType === 'sheets' ? 'Spreadsheet' : 'Presentation');
    }

    const exportUrl = 'https://docs.google.com/' + (docType === 'docs' ? 'document' : docType === 'sheets' ? 'spreadsheets' : 'presentation') + '/d/' + docId + '/export?format=' + exportFormat;

    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.smartDocumentTracker) {
        window.webkit.messageHandlers.smartDocumentTracker.postMessage({
          action: 'documentTracked',
          docId: docId,
          type: docType,
          title: rawTitle,
          url: window.location.href,
          exportUrl: exportUrl
        });
      }
    } catch(e) {}
  }

  setTimeout(trackCurrentDocument, 1500);
  setTimeout(trackCurrentDocument, 4000);
  setTimeout(trackCurrentDocument, 10000);

  let debounceTimer = null;
  function scheduleTracking() {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(trackCurrentDocument, 3000);
  }

  document.addEventListener('input', scheduleTracking, { passive: true });
  document.addEventListener('keyup', scheduleTracking, { passive: true });

  // Home screen document scanner (Docs, Sheets, Slides recent documents)
  function scanHomeScreenDocuments() {
    const isHomeScreen = /^\/(document|spreadsheets|presentation)\/?($|\?)/.test(window.location.pathname);
    if (!isHomeScreen) return;
    
    const rows = document.querySelectorAll('.docs-homescreen-list-item, [role="row"], .view-row, .docs-homescreen-grid-item');
    const scanned = [];
    rows.forEach(row => {
      const titleEl = row.querySelector('.docs-homescreen-list-item-title-value, [aria-label], .docs-homescreen-grid-item-title');
      const linkEl = row.querySelector('a[href*="/d/"]');
      const title = (titleEl && (titleEl.innerText || titleEl.getAttribute('aria-label'))) || '';
      const href = (linkEl && linkEl.href) || '';
      const match = href.match(/\/d\/([a-zA-Z0-9_-]+)/);
      if (match && title) {
        const docId = match[1];
        const cleanTitle = title.replace(/ - Google (Docs|Sheets|Slides)$/i, '').trim();
        scanned.push({
          docId: docId,
          title: cleanTitle,
          type: window.location.pathname.includes('spreadsheets') ? 'sheets' : window.location.pathname.includes('presentation') ? 'slides' : 'docs',
          url: href,
          exportUrl: 'https://docs.google.com/document/d/' + docId + '/export?format=docx'
        });
      }
    });
    
    if (scanned.length > 0 && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.smartDocumentTracker) {
      window.webkit.messageHandlers.smartDocumentTracker.postMessage({
        action: 'documentListScanned',
        documents: scanned
      });
    }
  }

  setTimeout(scanHomeScreenDocuments, 2000);
  setTimeout(scanHomeScreenDocuments, 5000);

  console.log("[WorkspaceDocsOffline] Injected open-source offline bridge for Google Workspace.");
})();
