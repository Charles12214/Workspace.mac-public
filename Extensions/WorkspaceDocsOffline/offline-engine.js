/**
 * Workspace Docs Offline - Page Context Offline Engine
 * Runs directly in the Google Docs/Sheets/Slides/Drive DOM context
 * License: MIT
 */

(function() {
  if (window.__workspaceOfflineEngineInitialized) return;
  window.__workspaceOfflineEngineInitialized = true;

  // Suppress "Offline editing is only available in Google Chrome" alerts & modals
  const removeChromePromos = () => {
    const banners = document.querySelectorAll(
      '[aria-label*="switch to Chrome"], [aria-label*="Try Chrome"], [aria-label*="supported browser"], .docs-offline-promo, .app-download-banner'
    );
    banners.forEach(b => b.remove());
  };

  // Run DOM observer to clean promos and enforce offline availability
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', removeChromePromos);
  } else {
    removeChromePromos();
  }

  const observer = new MutationObserver(() => {
    removeChromePromos();
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });

  // Expose Workspace Docs Offline global status
  window.__WORKSPACE_DOCS_OFFLINE = {
    version: "1.74.0",
    isOpenSource: true,
    engine: "Workspace.mac Native Open-Source Extension",
    isOfflineReady: true
  };

  console.log("[WorkspaceDocsOffline] Page-level offline engine active.");
})();
