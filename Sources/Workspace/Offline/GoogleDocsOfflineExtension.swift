import Foundation
import WebKit

/// Google Docs & Workspace Offline Chrome Extension API Polyfill / Shim.
/// Simulates the official Google Docs Offline Chrome Extension (`ghbmnnjooekpmoecnnnilnnbdlolhkhi`)
/// within WebKit so that Google Docs, Sheets, Slides, and Drive detect offline capabilities,
/// enable IndexedDB local storage, and support seamless offline viewing and editing.
public struct GoogleDocsOfflineExtension {
    
    public static let extensionId = "ghbmnnjooekpmoecnnnilnnbdlolhkhi"
    
    /// JavaScript injection payload providing chrome.runtime and chrome.storage shims
    public static let shimScriptSource: String = """
    (function() {
        if (window.__workspaceOfflineShimInjected) return;
        window.__workspaceOfflineShimInjected = true;
        
        const EXT_ID = '\(extensionId)';
        
        // Ensure window.chrome namespace exists
        window.chrome = window.chrome || {};
        
        // Polyfill chrome.runtime
        window.chrome.runtime = window.chrome.runtime || {
            id: EXT_ID,
            
            getManifest: function() {
                return {
                    name: "Google Docs Offline (Workspace.mac Native Engine)",
                    version: "1.74.0",
                    manifest_version: 3,
                    description: "Native Google Docs Offline Bridge for Workspace.mac"
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
                
                // Construct standard responses expected by Google Docs Offline clients
                let response = {
                    success: true,
                    installed: true,
                    isInstalled: true,
                    offlineStatus: 'ENABLED',
                    enabled: true,
                    version: '1.74.0'
                };
                
                if (type === 'getOfflineStatus' || type === 'getStatus') {
                    response = {
                        status: 'ENABLED',
                        isOfflineAvailable: true,
                        isOfflineEnabled: true,
                        enabled: true,
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
                    setTimeout(function() { cb(response); }, 0);
                }
                return Promise.resolve(response);
            },
            
            connect: function(targetId, connectInfo) {
                const portName = connectInfo ? connectInfo.name : 'workspace_offline_port';
                const messageListeners = [];
                const disconnectListeners = [];
                
                const port = {
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
                        // Echo or acknowledge messages sent through port
                        setTimeout(function() {
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
                return port;
            },
            
            onMessage: {
                addListener: function(fn) {},
                removeListener: function(fn) {}
            },
            
            onConnect: {
                addListener: function(fn) {},
                removeListener: function(fn) {}
            }
        };
        
        // Polyfill chrome.storage
        window.chrome.storage = window.chrome.storage || {
            local: {
                get: function(keys, cb) {
                    if (cb && typeof cb === 'function') setTimeout(function() { cb({}); }, 0);
                    return Promise.resolve({});
                },
                set: function(items, cb) {
                    if (cb && typeof cb === 'function') setTimeout(function() { cb(); }, 0);
                    return Promise.resolve();
                },
                remove: function(keys, cb) {
                    if (cb && typeof cb === 'function') setTimeout(function() { cb(); }, 0);
                    return Promise.resolve();
                }
            },
            sync: {
                get: function(keys, cb) {
                    if (cb && typeof cb === 'function') setTimeout(function() { cb({}); }, 0);
                    return Promise.resolve({});
                },
                set: function(items, cb) {
                    if (cb && typeof cb === 'function') setTimeout(function() { cb(); }, 0);
                    return Promise.resolve();
                }
            }
        };
        
        // Notify host that Google Docs Offline shim is active
        try {
            window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineExtensionReady &&
            window.webkit.messageHandlers.offlineExtensionReady.postMessage({ status: 'ready', extId: EXT_ID });
        } catch(e) {}
    })();
    """
    
    /// Constructs a WKUserScript ready to be added to WKUserContentController at document start
    @MainActor
    public static func makeUserScript() -> WKUserScript {
        WKUserScript(
            source: shimScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}
