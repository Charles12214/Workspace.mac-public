import Foundation
import WebKit

/// OfflineSuite.mac — Script Injection Manager
/// Loads OfflineSuiteBridge.js from the app bundle and creates a WKUserScript
/// for injection at document start across all frames.
///
/// Provides `makeUserScript()` for clean WKWebView integration.
///
/// MIT License — 100% original clean-room code.
public struct OfflineSuiteInjector {
    
    /// Returns the bundled JavaScript source for OfflineSuiteBridge.js
    public static var bridgeScriptSource: String {
        cachedBridgeScriptSource
    }
    
    private static let cachedBridgeScriptSource: String = {
        // Priority 1: Bundle Resources subdirectory
        if let bundleUrl = Bundle.main.url(
            forResource: "OfflineSuiteBridge",
            withExtension: "js",
            subdirectory: "Extensions/OfflineSuite"
        ), let code = try? String(contentsOf: bundleUrl), !code.isEmpty {
            return code
        }
        
        // Priority 2: Direct resource URL path
        if let resUrl = Bundle.main.resourceURL?
            .appendingPathComponent("Extensions/OfflineSuite/OfflineSuiteBridge.js"),
           let code = try? String(contentsOf: resUrl), !code.isEmpty {
            return code
        }
        
        // Priority 3: Working directory (development builds)
        let localPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Extensions/OfflineSuite/OfflineSuiteBridge.js")
        if let code = try? String(contentsOf: localPath), !code.isEmpty {
            return code
        }
        
        // Priority 4: Minimal inline fallback — sets extension flags only
        return minimalFallbackScript
    }()
    
    /// Constructs a WKUserScript ready to be added to WKUserContentController.
    /// Injected at document start, for ALL frames (not just main frame),
    /// because Google Docs creates iframes for the extension handshake.
    @MainActor
    public static func makeUserScript() -> WKUserScript {
        WKUserScript(
            source: bridgeScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
    
    /// Minimal fallback script if the full bridge JS file cannot be found.
    /// Sets the 5 extension detection flags so Docs at least knows an
    /// extension is "present", even if the full RPC bridge isn't active.
    private static let minimalFallbackScript: String = """
    (function() {
        // Leave Google authentication pages untouched so native Safari BotGuard succeeds.
        var h = (window.location.hostname || '').toLowerCase();
        var p = window.location.pathname || '';
        if (h.indexOf('accounts.google.') !== -1 || h.indexOf('accounts.youtube.') !== -1 ||
            h.indexOf('myaccount.google.') !== -1 || h.indexOf('gds.google.') !== -1 ||
            p.indexOf('/ServiceLogin') !== -1 || p.indexOf('/v3/signin') !== -1 || p.indexOf('/signin/') !== -1) {
            return;
        }
        try {
            if (window.top && window.top !== window && document.referrer &&
                (document.referrer.indexOf('accounts.google.') !== -1 || document.referrer.indexOf('gds.google.') !== -1)) {
                return;
            }
        } catch(e) {}
        if (window.__offlineSuiteLoaded) return;
        window.__offlineSuiteLoaded = true;
        window._docs_chrome_extension_exists = true;
        window._docs_chrome_extension_features_version = 2;
        window._docs_chrome_extension_permissions = ['alarms','clipboardRead','clipboardWrite','storage','unlimitedStorage','offscreen'];
        window._docs_chrome_extension_manifest_version = 3;
        window._docs_chrome_extension_version = '1.111.1';
        try { Object.defineProperty(navigator, 'onLine', { get: () => true, configurable: true }); } catch(e) {}
        window.chrome = window.chrome || {};
        window.chrome.runtime = window.chrome.runtime || { id: 'ghbmnnjooekpmoecnnnilnnbdlolhkhi', getManifest: () => ({ name: 'Google Docs Offline', version: '1.111.1', manifest_version: 3 }), getURL: (p) => 'chrome-extension://ghbmnnjooekpmoecnnnilnnbdlolhkhi/' + (p||''), sendMessage: function() {}, connect: function() { return { name: '', onMessage: { addListener: function(){} }, onDisconnect: { addListener: function(){} }, postMessage: function(){}, disconnect: function(){} }; }, onMessage: { addListener: function(){} }, onMessageExternal: { addListener: function(){} }, onConnectExternal: { addListener: function(){} } };
        window.chrome.storage = { local: { get: (k,cb) => { if(cb) setTimeout(()=>cb({}),0); return Promise.resolve({}); }, set: (o,cb) => { if(cb) setTimeout(cb,0); return Promise.resolve(); }, remove: (k,cb) => { if(cb) setTimeout(cb,0); return Promise.resolve(); } }, managed: { get: (k,cb) => { if(cb) setTimeout(()=>cb({}),0); return Promise.resolve({}); } } };
        window.chrome.alarms = { create: ()=>{}, clear: (n,cb)=>cb&&setTimeout(cb,0), get: (n,cb)=>cb&&setTimeout(()=>cb(null),0), onAlarm: { addListener: ()=>{} } };
        window.chrome.offscreen = { createDocument: ()=>Promise.resolve(), closeDocument: ()=>Promise.resolve() };
        console.warn('[OfflineSuite] Running minimal fallback — full bridge JS not found in bundle.');
        try { if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) { window.webkit.messageHandlers.offlineSuite.postMessage({ action: 'bridgeReady', version: '1.111.1-fallback', extensionId: 'ghbmnnjooekpmoecnnnilnnbdlolhkhi' }); } } catch(e) {}
    })();
    """
}
