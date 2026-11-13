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

  console.log("[WorkspaceDocsOffline] Injected open-source offline bridge for Google Workspace.");
})();
