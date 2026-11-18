// =====================================================================================
// OfflineSuiteBridge.js — OfflineSuite.mac Clean-Room Offline Bridge for Workspace.mac
// =====================================================================================
// MIT License — 100% original clean-room code. No proprietary Google code.
//
// This script bridges Google Docs/Sheets/Slides' internal offline subsystem
// to work within Apple's WKWebView by:
//   1. Faking Chrome extension detection flags
//   2. Polyfilling chrome.runtime, chrome.storage, chrome.alarms, chrome.offscreen
//   3. Responding to chrome.runtime.sendMessage with correct protobuf arrays
//   4. Responding to chrome.runtime.connect port-based protocol
//   5. Forcing offline-synced state via chrome.storage polyfill
//   6. Suppressing "Trying to connect..." banners
//   7. Unlocking keyboard input
//   8. Intercepting network requests for offline resilience
//   9. Piping document edits to native Swift via messageHandlers
// =====================================================================================

(function() {
  'use strict';

  // Bail out before touching globals on Google authentication origins/frames:
  // spoofing Chrome properties or wrapping DOM/XHR APIs inside WKWebView triggers
  // Chromium BotGuard challenges that fail in JavaScriptCore ("browser may not be secure").
  function isGoogleAuthContext() {
    const authHosts = ['accounts.google.', 'accounts.youtube.', 'myaccount.google.', 'gds.google.'];
    const authPaths = ['/ServiceLogin', '/AccountChooser', '/AddSession', '/CheckCookie', '/SetSID', '/SetOSID', '/v3/signin', '/signin/', '/accounts/Set'];

    function matchesAuth(host, path) {
      const h = String(host || '').toLowerCase();
      const p = String(path || '');
      if (authHosts.some(prefix => h.includes(prefix))) return true;
      return authPaths.some(seg => p.includes(seg));
    }

    try {
      if (matchesAuth(window.location.hostname, window.location.pathname)) return true;
    } catch(e) {}

    if (window.top && window.top !== window) {
      try {
        if (matchesAuth(window.top.location.hostname, window.top.location.pathname)) return true;
      } catch(e) {
        // Cross-origin child frame: fall back to document.referrer to detect auth parents.
        try {
          if (document.referrer) {
            const ref = new URL(document.referrer);
            if (matchesAuth(ref.hostname, ref.pathname)) return true;
          }
        } catch(err) {}
      }
    }
    return false;
  }

  if (isGoogleAuthContext()) return;
  if (window.__offlineSuiteLoaded) return;
  window.__offlineSuiteLoaded = true;

  const EXT_ID = 'ghbmnnjooekpmoecnnnilnnbdlolhkhi';
  const EXT_VERSION = '1.111.1';

  // Anchor ports and channels globally so JavaScriptCore GC never collects live RPC ports.
  window.__offlineSuitePorts = window.__offlineSuitePorts || [];
  window.__offlineSuiteChannels = window.__offlineSuiteChannels || [];

  // ─── DEBUG LOGGING ────────────────────────────────────────────────────
  // The real Chrome extension does NOT fake network traffic: /save, /bind and
  // netcheck.gif fail natively while offline and Docs relies on the extension
  // port for offline state. Keep mocks off unless experimenting.
  const MOCK_NETWORK = false;
  const DEBUG = false;
  function dbg(...args) { if (DEBUG) console.log('[OfflineSuite]', ...args); }
  function dbgWarn(...args) { if (DEBUG) console.warn('[OfflineSuite]', ...args); }
  dbg('Bridge loading at', window.location.href, 'isTopFrame:', window === window.top);

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1: Extension Detection Flags & Genuine Chrome Spoofing
  // Google Docs checks these window & navigator globals to determine if the
  // browser is genuine Chrome and if the offline extension is present.
  // In Google's Closure library:
  //   goog.labs.userAgent.browser.isChrome = navigator.vendor === 'Google Inc.'
  // Without this, Docs thinks it's on Safari and disables offline completely!
  // ═══════════════════════════════════════════════════════════════════════════

  function spoofNavigatorProperty(prop, value) {
    const desc = {
      get: typeof value === 'function' ? value : () => value,
      set: () => {},
      configurable: true,
      enumerable: true
    };
    try {
      if (typeof Navigator !== 'undefined' && Navigator.prototype) {
        Object.defineProperty(Navigator.prototype, prop, desc);
      }
    } catch(e) {}
    try {
      if (typeof navigator !== 'undefined') {
        Object.defineProperty(navigator, prop, desc);
      }
    } catch(e) {}
  }

  const CHROME_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  spoofNavigatorProperty('userAgent', CHROME_UA);
  spoofNavigatorProperty('appVersion', '5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36');
  spoofNavigatorProperty('vendor', 'Google Inc.');
  spoofNavigatorProperty('vendorSub', '');
  spoofNavigatorProperty('productSub', '20030107');

  try {
    if (!navigator.userAgentData) {
      const uaData = {
        brands: [
          { brand: 'Google Chrome', version: '131' },
          { brand: 'Chromium', version: '131' },
          { brand: 'Not_A Brand', version: '24' }
        ],
        mobile: false,
        platform: 'macOS',
        getHighEntropyValues: function(hints) {
          return Promise.resolve({
            architecture: 'arm',
            bitness: '64',
            brands: [
              { brand: 'Google Chrome', version: '131' },
              { brand: 'Chromium', version: '131' },
              { brand: 'Not_A Brand', version: '24' }
            ],
            fullVersionList: [
              { brand: 'Google Chrome', version: '131.0.6778.86' },
              { brand: 'Chromium', version: '131.0.6778.86' },
              { brand: 'Not_A Brand', version: '24.0.0.0' }
            ],
            mobile: false,
            model: '',
            platform: 'macOS',
            platformVersion: '15.0.0',
            uaFullVersion: '131.0.6778.86'
          });
        },
        toJSON: function() {
          return { brands: this.brands, mobile: this.mobile, platform: this.platform };
        }
      };
      Object.defineProperty(navigator, 'userAgentData', {
        get: () => uaData,
        configurable: true
      });
    }
  } catch(e) {}

  const defineImmutable = (target, prop, value) => {
    try {
      Object.defineProperty(target, prop, {
        get: () => value,
        set: () => {},
        configurable: true,
        enumerable: true
      });
    } catch(e) {
      target[prop] = value;
    }
  };

  defineImmutable(window, '_docs_chrome_extension_exists', true);
  defineImmutable(window, '_docs_chrome_extension_features_version', 2);
  defineImmutable(window, '_docs_chrome_extension_permissions', [
    'alarms', 'clipboardRead', 'clipboardWrite',
    'storage', 'unlimitedStorage', 'offscreen'
  ]);
  defineImmutable(window, '_docs_chrome_extension_manifest_version', 3);
  defineImmutable(window, '_docs_chrome_extension_version', EXT_VERSION);

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2: Offline Flag Store & GoogleDocs User Record Helper
  // Forces internal offline readiness flags while preserving real account/lsuid
  // flags from _docs_flag_initialData.
  // ═══════════════════════════════════════════════════════════════════════════

  const offlineFlags = {
    'docs-offline-eeooip': true,
    'docs-offline-optin': true,
    'docs-offline-edose': true,
    'docs-offline-ecpl': true,
    'docs-wownoi': true,
    'punch-offline-enabled': true,
    'docs-offline-enable-punch': true,
    'ritz-offline-enabled': true,
    'docs-offline-enable-ritz': true,
    'ritz-wownoi': true,
    'enable-offline': true,
    'offline': true,
    'offlineSync': true,
    'offlineEnabled': true,
    'offlineOptedIn': true,
    'offlinePolicyAllows': true,
    'offlineStorageSufficient': true
  };

  let flagStore = Object.assign({}, window._docs_flag_initialData || {}, offlineFlags);

  function getGoogleDocsUserRecord() {
    let lsuid = '';
    let email = '';
    let locale = 'en_GB';

    try {
      const flags = flagStore || window._docs_flag_initialData || {};
      if (flags['docs-offline-lsuid']) {
        lsuid = String(flags['docs-offline-lsuid']);
      }
      if (flags['docs-offline-ue']) {
        email = String(flags['docs-offline-ue']);
      }
      if (flags['docs-offline-uifeo']) {
        const rawUifeo = flags['docs-offline-uifeo'];
        const parsed = typeof rawUifeo === 'string' ? JSON.parse(rawUifeo) : rawUifeo;
        if (Array.isArray(parsed)) {
          if (!lsuid && parsed[0]) lsuid = String(parsed[0]);
          if (!email && parsed[1]) email = String(parsed[1]);
          if (parsed[2]) locale = String(parsed[2]);
        }
      }
    } catch(e) {}

    try {
      if (!lsuid) lsuid = localStorage.getItem('__offlineSuite_lsuid') || localStorage.getItem('docs-oiouid') || '';
      if (!email) email = localStorage.getItem('__offlineSuite_ue') || '';
    } catch(e) {}

    let optInTime = Date.now();
    try {
      if (lsuid) {
        localStorage.setItem('__offlineSuite_lsuid', lsuid);
        localStorage.setItem('docs-oiouid', lsuid);
      }
      if (email) {
        localStorage.setItem('__offlineSuite_ue', email);
      }
      const savedTime = Number(localStorage.getItem('__offlineSuite_optInTime'));
      if (savedTime > 0) {
        optInTime = savedTime;
      } else {
        localStorage.setItem('__offlineSuite_optInTime', String(optInTime));
      }
    } catch(e) {}

    return {
      id: lsuid,
      emailAddress: email,
      locale: locale,
      fastTrack: true,
      internal: false,
      optInReasons: [1],
      optInTime: optInTime
    };
  }

  let seedGoogleDocsIndexedDB = function() {};

  try {
    Object.defineProperty(window, '_docs_flag_initialData', {
      get: () => flagStore,
      set: (val) => {
        flagStore = Object.assign({}, val, offlineFlags);
        try { getGoogleDocsUserRecord(); } catch(e) {}
        try { seedGoogleDocsIndexedDB(); } catch(e) {}
      },
      configurable: true,
      enumerable: true
    });
  } catch(e) {}

  // Seed localStorage offline indicators
  try {
    localStorage.setItem('docs-wownoi', 'true');
    localStorage.setItem('docs-urop', 'false');
    localStorage.setItem('docsOfflineIframeApi-v', '1');
    localStorage.setItem('docsOfflineIframeApi-f', '1');
    localStorage.setItem('docsOfflineIframeApi-n', '1');
    localStorage.setItem('kx-e-v', '1');
    localStorage.setItem('punch-e-v', '1');
    localStorage.setItem('ritz-e-v', '1');
    localStorage.setItem('trix-e-v', '1');
    localStorage.setItem('emdraw-e-v', '1');
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2B: Web Locks API & StorageManager Polyfills
  // WebKit/WKWebView lacks navigator.locks and may report insufficient quota
  // or lack navigator.storage.estimate()/persist().
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    if (typeof navigator !== 'undefined' && !navigator.locks) {
      const heldLocks = new Map();

      const lockManager = {
        request: function(name, optionsOrCallback, maybeCallback) {
          let options = {};
          let callback = optionsOrCallback;
          if (typeof optionsOrCallback === 'object' && optionsOrCallback !== null) {
            options = optionsOrCallback;
            callback = maybeCallback;
          }
          if (typeof callback !== 'function') {
            return Promise.reject(new TypeError('callback must be a function'));
          }

          const mode = options.mode || 'exclusive';
          const lockName = String(name);
          if (options.ifAvailable && heldLocks.has(lockName)) {
            return Promise.resolve().then(function() {
              return callback(null);
            });
          }

          const lockObj = { name: lockName, mode: mode };
          heldLocks.set(lockName, lockObj);

          return Promise.resolve().then(function() {
            return callback(lockObj);
          }).then(
            function(val) {
              heldLocks.delete(lockName);
              return val;
            },
            function(err) {
              heldLocks.delete(lockName);
              throw err;
            }
          );
        },

        query: function() {
          const held = Array.from(heldLocks.values()).map(function(l) {
            return { name: l.name, mode: l.mode, clientId: 'offline-suite' };
          });
          return Promise.resolve({
            held: held,
            pending: []
          });
        }
      };

      try {
        Object.defineProperty(navigator, 'locks', {
          value: lockManager,
          writable: true,
          configurable: true
        });
      } catch(e) {
        navigator.locks = lockManager;
      }
    }
  } catch(e) {}

  try {
    if (typeof navigator !== 'undefined') {
      const fakeEstimate = function() {
        return Promise.resolve({
          usage: 1048576,
          quota: 10737418240
        });
      };
      const fakePersist = function() { return Promise.resolve(true); };
      const fakePersisted = function() { return Promise.resolve(true); };

      if (typeof StorageManager !== 'undefined' && StorageManager.prototype) {
        try {
          Object.defineProperty(StorageManager.prototype, 'estimate', {
            value: fakeEstimate, configurable: true, writable: true
          });
          Object.defineProperty(StorageManager.prototype, 'persist', {
            value: fakePersist, configurable: true, writable: true
          });
          Object.defineProperty(StorageManager.prototype, 'persisted', {
            value: fakePersisted, configurable: true, writable: true
          });
        } catch(e) {}
      }

      if (!navigator.storage) {
        const storagePoly = {
          estimate: fakeEstimate,
          persist: fakePersist,
          persisted: fakePersisted
        };
        try {
          Object.defineProperty(navigator, 'storage', {
            value: storagePoly,
            writable: true,
            configurable: true
          });
        } catch(e) {
          navigator.storage = storagePoly;
        }
      } else {
        try {
          Object.defineProperty(navigator.storage, 'estimate', {
            value: fakeEstimate, configurable: true, writable: true
          });
        } catch(e) {}
        try {
          Object.defineProperty(navigator.storage, 'persist', {
            value: fakePersist, configurable: true, writable: true
          });
        } catch(e) {}
        try {
          Object.defineProperty(navigator.storage, 'persisted', {
            value: fakePersisted, configurable: true, writable: true
          });
        } catch(e) {}
      }
    }
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2C: Seed "Users" in "GoogleDocs" IndexedDB Database
  // Ensures DEb/EEb/FEb find a matching opted-in user record so Docs sets
  // UDb (Bit 16 + Bit 32) and switches commands to IndexedDB offline storage.
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    const origIDBOpen = typeof IDBFactory !== 'undefined' && IDBFactory.prototype && IDBFactory.prototype.open;

    function seedUsersStoreOnDB(db, done) {
      try {
        if (!db || !db.objectStoreNames || !db.objectStoreNames.contains('Users')) {
          if (done) done();
          return;
        }
        const record = getGoogleDocsUserRecord();
        if (!record || !record.id) {
          if (done) done();
          return;
        }
        const tx = db.transaction(['Users'], 'readwrite');
        const store = tx.objectStore('Users');
        const allReq = store.getAll();
        allReq.onsuccess = function() {
          try {
            const rows = allReq.result || [];
            if (rows.length === 0) {
              store.put(record);
              dbg('Seeded GoogleDocs IndexedDB Users record:', record.id);
            } else if (rows.length === 1 && rows[0] && rows[0].id !== record.id) {
              store.clear();
              store.put(record);
              dbg('Updated GoogleDocs IndexedDB Users record:', record.id);
            }
          } catch(e) {}
        };
        let finished = false;
        const finish = function() {
          if (finished) return;
          finished = true;
          if (done) done();
        };
        tx.oncomplete = finish;
        tx.onerror = finish;
        tx.onabort = finish;
      } catch(e) {
        if (done) done();
      }
    }

    seedGoogleDocsIndexedDB = function() {
      try {
        const idb = window.indexedDB || window.webkitIndexedDB;
        if (!idb || !origIDBOpen || typeof idb.databases !== 'function') return;
        idb.databases().then(function(list) {
          if (!Array.isArray(list)) return;
          const exists = list.some(function(d) {
            return d && d.name === 'GoogleDocs' && d.version >= 6;
          });
          if (!exists) return;
          const openReq = origIDBOpen.call(idb, 'GoogleDocs');
          openReq.addEventListener('success', function() {
            const db = openReq.result;
            if (!db) return;
            db.onversionchange = function() {
              try { db.close(); } catch(e) {}
            };
            seedUsersStoreOnDB(db, function() {
              try { db.close(); } catch(e) {}
            });
          });
        }).catch(function() {});
      } catch(e) {}
    };

    if (origIDBOpen) {
      IDBFactory.prototype.open = function(name) {
        const openReq = origIDBOpen.apply(this, arguments);
        if (name === 'GoogleDocs' && openReq) {
          let userOnSuccess = null;
          let interceptInstalled = false;
          try {
            Object.defineProperty(openReq, 'onsuccess', {
              configurable: true,
              enumerable: true,
              get: function() { return userOnSuccess; },
              set: function(fn) { userOnSuccess = typeof fn === 'function' ? fn : null; }
            });
            interceptInstalled = true;
          } catch(e) {}
          if (interceptInstalled) {
            openReq.addEventListener('success', function(ev) {
              const db = openReq.result;
              seedUsersStoreOnDB(db, function() {
                if (userOnSuccess) {
                  try { userOnSuccess.call(openReq, ev); } catch(err) { dbgWarn('IDB open onsuccess err:', err); }
                }
              });
            });
          } else {
            openReq.addEventListener('success', function() {
              seedUsersStoreOnDB(openReq.result);
            });
          }
        }
        return openReq;
      };
    }

    if (typeof IDBObjectStore !== 'undefined' && IDBObjectStore.prototype && IDBObjectStore.prototype.get) {
      const origStoreGet = IDBObjectStore.prototype.get;
      IDBObjectStore.prototype.get = function() {
        const storeName = this.name;
        const storeTx = this.transaction;
        const db = storeTx && storeTx.db;
        const queryKey = arguments[0];
        const req = origStoreGet.apply(this, arguments);
        if (storeName === 'Users' && req) {
          let userOnSuccess = null;
          let interceptInstalled = false;
          try {
            Object.defineProperty(req, 'onsuccess', {
              configurable: true,
              enumerable: true,
              get: function() { return userOnSuccess; },
              set: function(fn) { userOnSuccess = typeof fn === 'function' ? fn : null; }
            });
            interceptInstalled = true;
          } catch(e) {}
          req.addEventListener('success', function(ev) {
            if (req.result == null) {
              const fallbackUser = getGoogleDocsUserRecord();
              if (!fallbackUser.id && typeof queryKey === 'string' && queryKey) {
                fallbackUser.id = queryKey;
              }
              if (fallbackUser.id) {
                try {
                  Object.defineProperty(req, 'result', {
                    get: function() { return fallbackUser; },
                    configurable: true,
                    enumerable: true
                  });
                } catch(e) {}
                if (db) {
                  setTimeout(function() { seedUsersStoreOnDB(db); }, 0);
                }
              }
            }
            if (interceptInstalled && userOnSuccess) {
              try { userOnSuccess.call(req, ev); } catch(err) { dbgWarn('Users get onsuccess err:', err); }
            }
          });
        }
        return req;
      };
    }

    seedGoogleDocsIndexedDB();
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3: navigator.onLine & Beacon Override
  // Tracks online/offline transitions without masking native offline events.
  // ═══════════════════════════════════════════════════════════════════════════

  const origOnLineDesc = typeof Navigator !== 'undefined' && Navigator.prototype
    ? Object.getOwnPropertyDescriptor(Navigator.prototype, 'onLine')
    : null;
  const getNativeOnLine = function() {
    try {
      if (origOnLineDesc && typeof origOnLineDesc.get === 'function') {
        return !!origOnLineDesc.get.call(navigator);
      }
    } catch(e) {}
    return true;
  };
  const realInitialOnLine = getNativeOnLine();
  navigator._realOnLine = realInitialOnLine;
  if (typeof window.__offlineSuiteNetworkOffline === 'undefined') {
    window.__offlineSuiteNetworkOffline = (realInitialOnLine === false);
  }

  const handleNetworkTransition = function(isOffline) {
    const prev = window.__offlineSuiteNetworkOffline;
    window.__offlineSuiteNetworkOffline = isOffline;
    if (window.__offlineSuiteFromNative || prev === isOffline) return;
    try {
      if (window === window.top && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) {
        window.webkit.messageHandlers.offlineSuite.postMessage({
          action: 'networkStateChanged',
          isOffline: isOffline
        });
      }
    } catch(e) {}
  };

  window.addEventListener('offline', function() {
    handleNetworkTransition(true);
  });
  window.addEventListener('online', function() {
    handleNetworkTransition(false);
  });

  spoofNavigatorProperty('onLine', function() {
    return window.__offlineSuiteNetworkOffline === true ? false : getNativeOnLine();
  });

  try {
    const origBeacon = navigator.sendBeacon;
    navigator.sendBeacon = function(url, data) {
      const urlStr = String(url || '');
      if (window.__offlineSuiteNetworkOffline || urlStr.includes('/log') || urlStr.includes('jserror') || urlStr.includes('analytics')) {
        return true;
      }
      try {
        if (origBeacon) return origBeacon.apply(this, arguments);
      } catch(e) {}
      return true;
    };
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4: Network Request Interceptors
  // Catches fetch/XHR calls that would fail offline:
  //   - /save: Returns synthetic 200 OK with PROTOBUF/JSON revisionRanges so Docs
  //            acknowledges mutation commands (NAb) and never freezes keyboard!
  //   - /bind: Returns synthetic 200 OK client binding session
  //   - homescreensettings: returns empty JSON {} so homescreen doesn't error
  //   - netcheck.gif, cleardot.gif: returns 1x1 transparent gif so connectivity tests pass
  //   - play.google.com/log, chooseServer, generate_204: returns 200 OK
  // ═══════════════════════════════════════════════════════════════════════════

  function extractRevAndCount(body, url) {
    let rev = null;
    let bundleCount = 1;
    try {
      const urlStr = String(url || '');
      const urlRevMatch = urlStr.match(/[?&]rev=(\d+)/);
      if (urlRevMatch) rev = parseInt(urlRevMatch[1], 10);

      if (typeof body === 'string') {
        const bodyRevMatch = body.match(/(?:^|[&?])rev=(\d+)/);
        if (bodyRevMatch) rev = parseInt(bodyRevMatch[1], 10);
        if (rev === null) {
          const jsonRevMatch = body.match(/"rev"\s*:\s*(\d+)/);
          if (jsonRevMatch) rev = parseInt(jsonRevMatch[1], 10);
        }
        const bundleMatch = body.match(/(?:^|[&?])bundles=([^&]+)/);
        if (bundleMatch) {
          try {
            const parsed = JSON.parse(decodeURIComponent(bundleMatch[1]));
            if (Array.isArray(parsed) && parsed.length > 0) {
              bundleCount = parsed.length;
            }
          } catch(e) {}
        }
      } else if (body && typeof FormData !== 'undefined' && body instanceof FormData) {
        if (body.has('rev')) {
          rev = parseInt(body.get('rev'), 10);
        }
        if (body.has('bundles')) {
          try {
            const parsed = JSON.parse(body.get('bundles'));
            if (Array.isArray(parsed) && parsed.length > 0) {
              bundleCount = parsed.length;
            }
          } catch(e) {}
        }
      }
    } catch(e) {}
    return { rev, bundleCount };
  }

  function getMockBodyForUrl(url, body) {
    const u = String(url || '');
    if (u.includes('homescreensettings')) return '{}';
    if (u.includes('chooseServer')) {
      return JSON.stringify({
        status: 'OK',
        server: window.location.origin
      });
    }
    if (u.includes('/bind')) {
      return ')]}\'\n[["c","offline_client_id","",8]]';
    }
    if (u.includes('/save')) {
      // Return minimal response: empty JSON object after prefix.
      // Google Docs' k.Wi() strips the )]}'\n prefix then JSON.parses.
      // no({}) === true (no own keys) → nce(a) fires → save complete → keyboard unlocked!
      return ")]}'\n{}";
    }
    return JSON.stringify({ status: 'ok', sid: 'offline', revision: 1 });
  }

  function isOfflineInterceptUrl(url) {
    if (!url) return false;
    const u = String(url);
    return u.includes('/save') ||
           u.includes('/bind') ||
           u.includes('/channel/test') ||
           u.includes('/channel/bind') ||
           u.includes('netcheck') ||
           u.includes('cleardot') ||
           u.includes('generate_204') ||
           u.includes('/log') ||
           u.includes('/jserror') ||
           u.includes('chooseServer') ||
           u.includes('signaler-pa');
  }

  // Intercept fetch ONLY when offline
  try {
    const origFetch = window.fetch;
    window.fetch = async function(resource, init) {
      // Fast path: if network is online, always use native fetch!
      if (!MOCK_NETWORK || !window.__offlineSuiteNetworkOffline) {
        return await origFetch.apply(this, arguments);
      }
      const url = typeof resource === 'string' ? resource : (resource && resource.url) || '';
      const body = init ? init.body : null;
      if (isOfflineInterceptUrl(url)) {
        if (url.includes('netcheck') || url.includes('cleardot')) {
          return new Response(new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x21, 0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b]), {
            status: 200,
            headers: { 'Content-Type': 'image/gif' }
          });
        }
        return new Response(getMockBodyForUrl(url, body), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      return await origFetch.apply(this, arguments);
    };
  } catch(e) {}

  // ─── Full Mock XHR Class ──────────────────────────────────────────────────
  // Object.defineProperty on native WebKit XHR properties (readyState, status,
  // responseText) silently fails — WebKit ignores the write. Google Docs'
  // k.Wi() reads xhr.responseText by closure reference on the same XHR object,
  // so we MUST replace window.XMLHttpRequest with a full mock class whose
  // properties are plain JS object properties (always writable).
  try {
    const OrigXHR = window.XMLHttpRequest;

    function OfflineXHR() {
      this._listeners   = {};
      this.readyState   = 0;
      this.status       = 0;
      this.statusText   = '';
      this.responseText = '';
      this.response     = '';
      this.responseType = '';
      this.responseURL  = '';
      this.responseXML  = null;
      this.timeout      = 0;
      this.withCredentials = false;
      this.upload = {
        addEventListener: function() {},
        removeEventListener: function() {},
        dispatchEvent: function() {}
      };
      this._url     = '';
      this._method  = 'GET';
      this._body    = null;
      this._headers = {};
      this._shouldIntercept = false;
      this._realXhr = null;
      // Backing stores for event handler properties
      this._onreadystatechange = null;
      this._onload    = null;
      this._onloadend = null;
      this._onerror   = null;
      this._onprogress = null;
      this._ontimeout  = null;
      this._onabort    = null;
    }

    OfflineXHR.prototype.open = function(method, url) {
      this._method = method || 'GET';
      this._url    = String(url || '');
      this._shouldIntercept = isOfflineInterceptUrl(this._url);
      this.readyState = 1;
    };

    OfflineXHR.prototype.setRequestHeader = function(key, val) {
      this._headers[key] = val;
    };

    OfflineXHR.prototype.getResponseHeader = function(name) {
      if (this._realXhr) { try { return this._realXhr.getResponseHeader(name); } catch(e) {} }
      return null;
    };

    OfflineXHR.prototype.getAllResponseHeaders = function() {
      if (this._realXhr) { try { return this._realXhr.getAllResponseHeaders(); } catch(e) {} }
      return '';
    };

    OfflineXHR.prototype.overrideMimeType = function(mime) {
      if (this._realXhr) { try { this._realXhr.overrideMimeType(mime); } catch(e) {} }
    };

    OfflineXHR.prototype.abort = function() {
      if (this._realXhr) { try { this._realXhr.abort(); } catch(e) {} }
    };

    OfflineXHR.prototype.addEventListener = function(type, listener) {
      if (!this._listeners[type]) this._listeners[type] = [];
      this._listeners[type].push(listener);
    };

    OfflineXHR.prototype.removeEventListener = function(type, listener) {
      if (this._listeners[type]) {
        this._listeners[type] = this._listeners[type].filter(function(l) { return l !== listener; });
      }
    };

    OfflineXHR.prototype.dispatchEvent = function(event) {
      const type = event && event.type;
      if (!type) return true;
      (this._listeners[type] || []).forEach(function(l) {
        try { l.call(this, event); } catch(e) {}
      }, this);
      return true;
    };

    // Fire all events with mock data.
    // Google Docs' k.Wi() reads xhr.responseText from a closure ref to THIS object,
    // so setting it as a plain JS property here IS visible to Docs' save handler.
    OfflineXHR.prototype._fireComplete = function(mockBody, isSave) {
      const self = this;
      self.readyState   = 4;
      self.status       = 200;
      self.statusText   = 'OK';
      self.responseText = mockBody;
      self.response     = mockBody;
      self.responseURL  = self._url;

      dbg('OfflineXHR._fireComplete:', self._url, 'body[:60]:', String(mockBody).slice(0, 60));

      const rsc = { type: 'readystatechange', target: self };
      if (typeof self._onreadystatechange === 'function') {
        try { self._onreadystatechange.call(self, rsc); } catch(e) { dbgWarn('onrsc err:', e); }
      }
      (self._listeners['readystatechange'] || []).forEach(function(l) {
        try { l.call(self, rsc); } catch(e) {}
      });

      const load = { type: 'load', target: self };
      if (typeof self._onload === 'function') {
        try { self._onload.call(self, load); } catch(e) { dbgWarn('onload err:', e); }
      }
      (self._listeners['load'] || []).forEach(function(l) {
        try { l.call(self, load); } catch(e) {}
      });

      const loadend = { type: 'loadend', target: self };
      if (typeof self._onloadend === 'function') {
        try { self._onloadend.call(self, loadend); } catch(e) {}
      }
      (self._listeners['loadend'] || []).forEach(function(l) {
        try { l.call(self, loadend); } catch(e) {}
      });

      if (isSave) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) {
            const docMatch = self._url.match(/\/d\/([a-zA-Z0-9_-]+)/);
            window.webkit.messageHandlers.offlineSuite.postMessage({
              action: 'documentSavedOffline',
              docId: docMatch ? docMatch[1] : '',
              title: document.title.replace(/ - Google.*$/, '').trim(),
              timestamp: Date.now()
            });
          }
        } catch(e) {}
      }
    };

    OfflineXHR.prototype.send = function(body) {
      const self = this;
      this._body = body;
      const url  = this._url;
      const isSave      = url.includes('/save');
      const isTelemetry = url.includes('netcheck') || url.includes('cleardot') || url.includes('generate_204');

      // ── Non-intercepted URLs: proxy through real XHR with ALL properties forwarded ──
      if (!this._shouldIntercept) {
        const realXhr = new OrigXHR();
        this._realXhr = realXhr;
        realXhr.open(this._method, url);
        // ⚡ CRITICAL: forward withCredentials, responseType, timeout
        // Missing these in a previous full-mock implementation broke online auth (cookies)
        try { realXhr.withCredentials = this.withCredentials; } catch(e) {}
        if (this.responseType) { try { realXhr.responseType = this.responseType; } catch(e) {} }
        if (this.timeout)      { try { realXhr.timeout      = this.timeout;      } catch(e) {} }
        // Forward request headers
        const hdrs = this._headers;
        Object.keys(hdrs).forEach(function(k) {
          try { realXhr.setRequestHeader(k, hdrs[k]); } catch(e) {}
        });
        // Bridge all events back through the mock object so callers see this OfflineXHR
        const bridge = function() {
          self.readyState = realXhr.readyState;
          self.status     = realXhr.status;
          self.statusText = realXhr.statusText;
          try { self.responseText = realXhr.responseText; } catch(e) {}
          try { self.response     = realXhr.response;     } catch(e) {}
          self.responseURL = realXhr.responseURL || url;
        };
        realXhr.onreadystatechange = function() {
          bridge();
          const ev = { type: 'readystatechange', target: self };
          if (typeof self._onreadystatechange === 'function') try { self._onreadystatechange.call(self, ev); } catch(e) {}
          (self._listeners['readystatechange'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        realXhr.onload = function() {
          bridge();
          const ev = { type: 'load', target: self };
          if (typeof self._onload === 'function') try { self._onload.call(self, ev); } catch(e) {}
          (self._listeners['load'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        realXhr.onloadend = function() {
          bridge();
          const ev = { type: 'loadend', target: self };
          if (typeof self._onloadend === 'function') try { self._onloadend.call(self, ev); } catch(e) {}
          (self._listeners['loadend'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        realXhr.onerror = function() {
          bridge();
          const ev = { type: 'error', target: self };
          if (typeof self._onerror === 'function') try { self._onerror.call(self, ev); } catch(e) {}
          (self._listeners['error'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        try { realXhr.send(body); } catch(e) {}
        return;
      }

      // ── Telemetry (netcheck / cleardot / generate_204): mock immediately ──
      if (isTelemetry) {
        setTimeout(function() {
          self._fireComplete(getMockBodyForUrl(url, body), false);
        }, 5);
        return;
      }

      const isKnownOffline = window.__offlineSuiteNetworkOffline === true;
      const isBind = url.includes('/bind');

      if (isKnownOffline) {
        // Already confirmed offline — answer immediately with mock
        setTimeout(function() {
          dbg('OfflineXHR: known offline, mock:', url);
          self._fireComplete(getMockBodyForUrl(url, body), isSave);
        }, 10);
        return;
      }

      // ── /bind MUST NEVER get the race timer ──────────────────────────────
      // /bind is a long-poll that intentionally stays open for 30+ seconds
      // waiting for server push events. A 800ms timer would ALWAYS fire and
      // falsely set __offlineSuiteNetworkOffline = true while WiFi is ON.
      // When not known offline, /bind passes through to native XHR directly.
      if (isBind) {
        const realXhr = new OrigXHR();
        this._realXhr = realXhr;
        realXhr.open(this._method, url);
        try { realXhr.withCredentials = this.withCredentials; } catch(e) {}
        if (this.responseType) { try { realXhr.responseType = this.responseType; } catch(e) {} }
        if (this.timeout) { try { realXhr.timeout = this.timeout; } catch(e) {} }
        const hdrsB = this._headers;
        Object.keys(hdrsB).forEach(function(k) {
          try { realXhr.setRequestHeader(k, hdrsB[k]); } catch(e) {}
        });
        const bridgeB = function() {
          self.readyState = realXhr.readyState;
          self.status     = realXhr.status;
          self.statusText = realXhr.statusText;
          try { self.responseText = realXhr.responseText; } catch(e) {}
          try { self.response     = realXhr.response;     } catch(e) {}
          self.responseURL = realXhr.responseURL || url;
        };
        realXhr.onreadystatechange = function() {
          bridgeB();
          const ev = { type: 'readystatechange', target: self };
          if (typeof self._onreadystatechange === 'function') try { self._onreadystatechange.call(self, ev); } catch(e) {}
          (self._listeners['readystatechange'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        realXhr.onload = function() {
          bridgeB();
          const ev = { type: 'load', target: self };
          if (typeof self._onload === 'function') try { self._onload.call(self, ev); } catch(e) {}
          (self._listeners['load'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        realXhr.onloadend = function() {
          bridgeB();
          const ev = { type: 'loadend', target: self };
          if (typeof self._onloadend === 'function') try { self._onloadend.call(self, ev); } catch(e) {}
          (self._listeners['loadend'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        realXhr.onerror = function() {
          bridgeB();
          // /bind error while NOT known offline → may be a real drop; set the flag
          dbg('OfflineXHR: /bind native error — setting offline flag');
          window.__offlineSuiteNetworkOffline = true;
          const ev = { type: 'error', target: self };
          if (typeof self._onerror === 'function') try { self._onerror.call(self, ev); } catch(e) {}
          (self._listeners['error'] || []).forEach(function(l) { try { l.call(self, ev); } catch(e) {} });
        };
        try { realXhr.send(body); } catch(e) {
          dbg('OfflineXHR: /bind send threw — setting offline flag');
          window.__offlineSuiteNetworkOffline = true;
        }
        return;
      }

      // ── /save (and other quick endpoints): race real network vs 800ms fallback ──
      // /save should always respond within milliseconds when online. If it
      // doesn't, WiFi has dropped before NWPathMonitor told us.
      let raceCompleted = false;
      const realXhr = new OrigXHR();
      this._realXhr = realXhr;
      realXhr.open(this._method, url);
      try { realXhr.withCredentials = this.withCredentials; } catch(e) {}
      if (this.responseType) { try { realXhr.responseType = this.responseType; } catch(e) {} }
      const hdrs2 = this._headers;
      Object.keys(hdrs2).forEach(function(k) {
        try { realXhr.setRequestHeader(k, hdrs2[k]); } catch(e) {}
      });

      const fallbackTimer = setTimeout(function() {
        if (!raceCompleted) {
          raceCompleted = true;
          window.__offlineSuiteNetworkOffline = true;
          dbg('OfflineXHR race timeout for', url, '— using mock');
          self._fireComplete(getMockBodyForUrl(url, body), isSave);
        }
      }, 800);

      realXhr.onreadystatechange = function() {
        if (realXhr.readyState === 4 && !raceCompleted) {
          raceCompleted = true;
          clearTimeout(fallbackTimer);
          if (realXhr.status >= 200 && realXhr.status < 300) {
            // Network won — proxy real response through mock object
            dbg('OfflineXHR race: network won for', url, 'status:', realXhr.status);
            self.readyState   = 4;
            self.status       = realXhr.status;
            self.statusText   = realXhr.statusText;
            try { self.responseText = realXhr.responseText; } catch(e) {}
            try { self.response     = realXhr.response;     } catch(e) {}
            self.responseURL = realXhr.responseURL || url;
            const rscEv = { type: 'readystatechange', target: self };
            if (typeof self._onreadystatechange === 'function') try { self._onreadystatechange.call(self, rscEv); } catch(e) {}
            (self._listeners['readystatechange'] || []).forEach(function(l) { try { l.call(self, rscEv); } catch(e) {} });
            const loadEv = { type: 'load', target: self };
            if (typeof self._onload === 'function') try { self._onload.call(self, loadEv); } catch(e) {}
            (self._listeners['load'] || []).forEach(function(l) { try { l.call(self, loadEv); } catch(e) {} });
            const loadendEv = { type: 'loadend', target: self };
            if (typeof self._onloadend === 'function') try { self._onloadend.call(self, loadendEv); } catch(e) {}
            (self._listeners['loadend'] || []).forEach(function(l) { try { l.call(self, loadendEv); } catch(e) {} });
          } else {
            // Network failed — use mock
            dbg('OfflineXHR race: network failed for', url, 'status:', realXhr.status);
            window.__offlineSuiteNetworkOffline = true;
            self._fireComplete(getMockBodyForUrl(url, body), isSave);
          }
        }
      };
      try {
        realXhr.send(body);
      } catch(err) {
        if (!raceCompleted) {
          raceCompleted = true;
          clearTimeout(fallbackTimer);
          window.__offlineSuiteNetworkOffline = true;
          self._fireComplete(getMockBodyForUrl(url, body), isSave);
        }
      }
    };

    // event handler properties backed by _onXxx stores
    ['onreadystatechange', 'onload', 'onloadend', 'onerror', 'onprogress', 'ontimeout', 'onabort'].forEach(function(prop) {
      Object.defineProperty(OfflineXHR.prototype, prop, {
        get: function() { return this['_' + prop]; },
        set: function(v) { this['_' + prop] = v; },
        configurable: true,
        enumerable: true
      });
    });

    // Static readyState constants
    OfflineXHR.UNSENT           = 0;
    OfflineXHR.OPENED           = 1;
    OfflineXHR.HEADERS_RECEIVED = 2;
    OfflineXHR.LOADING          = 3;
    OfflineXHR.DONE             = 4;

    if (MOCK_NETWORK) {
      window.XMLHttpRequest = OfflineXHR;
      dbg('OfflineXHR full mock class installed');
    } else {
      dbg('Network mocking disabled (native XHR/fetch/img)');
    }
  } catch(e) { dbgWarn('Failed to install OfflineXHR:', e); }

  // ─── Image connectivity probes (netcheck.gif / cleardot.gif) ───────────────
  // Docs decides "Trying to connect" by loading these as <img>/Image(), which
  // XHR/fetch mocks never see. Rewrite them to an inline GIF when offline, and
  // recover if one fails natively before the offline flag is set.
  try {
    const GIF_DATA = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
    const isProbeImg = function(u) {
      u = String(u || '');
      return u.includes('netcheck') || u.includes('cleardot') || u.includes('generate_204');
    };
    const imgDesc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
    if (MOCK_NETWORK && imgDesc && imgDesc.set && imgDesc.get) {
      Object.defineProperty(HTMLImageElement.prototype, 'src', {
        configurable: true,
        enumerable: imgDesc.enumerable,
        get: function() { return imgDesc.get.call(this); },
        set: function(v) {
          if (isProbeImg(v)) {
            const img = this;
            if (window.__offlineSuiteNetworkOffline) {
              dbg('Image probe mocked (offline):', String(v).slice(0, 80));
              return imgDesc.set.call(img, GIF_DATA);
            }
            // Online path: native load, but recover if it errors (flag may lag the drop)
            img.addEventListener('error', function onErr() {
              img.removeEventListener('error', onErr);
              window.__offlineSuiteNetworkOffline = true;
              dbg('Image probe failed natively — substituting GIF:', String(v).slice(0, 80));
              imgDesc.set.call(img, GIF_DATA);
            });
          }
          return imgDesc.set.call(this, v);
        }
      });
    }
    const origSetAttr = Element.prototype.setAttribute;
    if (MOCK_NETWORK) Element.prototype.setAttribute = function(name, value) {
      if (this instanceof HTMLImageElement && String(name).toLowerCase() === 'src' && isProbeImg(value)) {
        this.src = value; // route through patched setter
        return;
      }
      return origSetAttr.apply(this, arguments);
    };
    dbg('Image probe interceptor installed');
  } catch(e) { dbgWarn('Failed to install image interceptor:', e); }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: Keyboard Unlock
  // Google Docs blocks keydown/keypress/beforeinput via preventDefault when
  // it believes the document isn't synced offline. We override preventDefault
  // across all windows and text event target iframes to let editor keystrokes through.
  // ═══════════════════════════════════════════════════════════════════════════

  function patchWindowPreventDefault(win) {
    try {
      if (!win || !win.Event || !win.Event.prototype || win.__offlineSuitePreventDefaultPatched) return;
      win.__offlineSuitePreventDefaultPatched = true;
      const origPreventDefault = win.Event.prototype.preventDefault;
      win.Event.prototype.preventDefault = function() {
        if (this.type === 'keydown' || this.type === 'keypress' || this.type === 'beforeinput') {
          const target = this.target;
          if (target) {
            const isEditorTarget =
              (target.classList && target.classList.contains('docs-texteventtarget-iframe')) ||
              target.tagName === 'TEXTAREA' ||
              target.tagName === 'INPUT' ||
              target.isContentEditable === true ||
              (target.ownerDocument && target.ownerDocument.defaultView !== window) ||
              (target.closest && target.closest('.docs-editor, .docs-editor-container, .kix-appview-editor, .kix-page-paginated, .punch-viewer-container, .punch-filmstrip, .sketchy-text-content-wrapper, .cell-input, #waffle-rich-text-editor, #t-formula-bar-input-container, .grid-container, .waffle-grid-container, svg'));
            if (isEditorTarget && !this.metaKey && !this.ctrlKey) {
              return; // Allow the keystroke
            }
          }
        }
        return origPreventDefault.apply(this, arguments);
      };
    } catch(e) {}
  }

  patchWindowPreventDefault(window);

  if (window === window.top) {
    setInterval(function() {
      try {
        document.querySelectorAll('iframe.docs-texteventtarget-iframe').forEach(function(iframe) {
          try {
            if (iframe.contentWindow) patchWindowPreventDefault(iframe.contentWindow);
          } catch(e) {}
        });
      } catch(e) {}
    }, 2000);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6: Protobuf Response Builder
  // Google Docs communicates with the extension using protobuf-serialized
  // arrays via chrome.runtime.sendMessage. The request format is:
  //   [requestType, ...fields]
  // The response format is:
  //   [requestType, null, fmStatus, gmSync, emError]
  // This section builds correct protobuf-format responses.
  // ═══════════════════════════════════════════════════════════════════════════

  // Detect the current user's OUID from localStorage or page data
  function getOuid() {
    try {
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        const m = k && k.match(/(\d{20,22})/);
        if (m) return m[1];
      }
    } catch(e) {}
    try {
      if (window.WIZ_global_data && (window.WIZ_global_data.ouid || window.WIZ_global_data.S06Grb)) {
        return String(window.WIZ_global_data.ouid || window.WIZ_global_data.S06Grb);
      }
    } catch(e) {}
    return '0';
  }

  function getTrackedDocsList() {
    let docs = [];
    try {
      const saved = localStorage.getItem('__offlineSuite_trackedDocs');
      if (saved) docs = JSON.parse(saved);
    } catch(e) {}
    if (!Array.isArray(docs)) docs = [];
    return docs;
  }

  function buildItemProtobuf(item) {
    const docId = String(item.docId || 'doc_offline_ready');
    const title = String(item.title || 'Untitled document');
    const type = (item.type === 'ritz' || item.type === 'punch' || item.type === 'drawing') ? item.type : 'kix';
    const mod = typeof item.modifiedTime === 'number' ? item.modifiedTime : Date.now();
    const viewed = typeof item.viewedTime === 'number' ? item.viewedTime : Date.now();

    const g = [];
    g[0] = docId;       // Field 1: string ID (getId())
    g[1] = title;       // Field 2: string title (Xe(g, 2))
    g[2] = type;        // Field 3: string type ("kix", "ritz", "punch") (Xe(g, 3))
    g[3] = mod;         // Field 4: number modifiedTime (ze(g, 4))
    g[4] = viewed;      // Field 5: number viewedTime (ze(g, 5))
    g[5] = null;        // Field 6
    g[6] = true;        // Field 7: boolean (Be(g, 7))
    g[7] = true;        // Field 8: isAvailableOffline (Be(g, 8))
    g[8] = 1;           // Field 9: number (ze(g, 9)) -> NEc[1] = 2
    g[9] = true;        // Field 10: isPinned / available offline (Fe(g, 10))
    g[10] = 0;          // Field 11: number
    g[11] = 0;          // Field 12: number
    g[12] = false;      // Field 13: boolean
    g[13] = true;       // Field 14: boolean
    g[14] = null;       // Field 15: null
    return g;
  }

  /**
   * Build the exact protobuf-serialized array structure expected by Google Docs client code.
   * Matches the compiled closure classes:
   *   Type 4 (tMw): nm(f.response, mNw, 4) -> nm(f, lNw, 1) -> Um(lNw, 1) === 1 && Rm(lNw, 5) === 1
   *   Type 10 (AMw): nm(e.response, kNw, 7) -> nm(e, hOp, 1) -> truthy status object
   *   Type 2 (IMw) & Type 3 (PEc): kFc(I(e.response, jFc, 3)) -> se(jFc, iFc, 1) -> valid document items
   *   Type 5 (VMw): nm(h.response, nNw, 8) -> nm(h, qAp, 1) -> available & synced
   *   Type 6 (pMw): nm(f.response, iNw, 5) -> nm(f, hOp, 1) -> eligibility
   */
  function buildUnifiedPortResponse(type) {
    const numType = typeof type === 'number' ? type : 4;

    // Exact replies captured from the real Chrome extension (port trace):
    //   [12]  -> [12]
    //   [10]  -> [10,null,null,null,null,null,[[2]]]
    if (numType === 12) return [12];
    if (numType === 10) return [10, null, null, null, null, null, [[2]]];

    // lNw: field 1 = 1 (OFFLINE_ENABLED), field 5 = 1 (SYNC_ENABLED)
    const lNw = [];
    lNw[0] = 1;
    lNw[1] = 1;
    lNw[4] = 1;
    lNw[5] = 1;

    // mNw: field 1 = lNw
    const mNw = [];
    mNw[0] = lNw;
    mNw[1] = lNw;

    // hOp: truthy status object
    const hOp = [1, 1, 1];

    // kNw: field 1 = hOp
    const kNw = [];
    kNw[0] = hOp;
    kNw[1] = hOp;

    // Build valid jFc item list for Type 2 and Type 3, always ensuring the active
    // document or Slides presentation (punch) is present even if trackedDocs already has entries.
    let tracked = getTrackedDocsList().slice();
    let pagePath = window.location.pathname || '';
    try {
      if (window.top && window.top !== window && window.top.location && window.top.location.pathname) {
        pagePath = window.top.location.pathname;
      }
    } catch(e) {}
    const activeMatch = pagePath.match(/\/(document|spreadsheets|presentation)\/d\/([a-zA-Z0-9_-]+)/);
    if (activeMatch) {
      const activeType = activeMatch[1] === 'spreadsheets' ? 'ritz' : (activeMatch[1] === 'presentation' ? 'punch' : 'kix');
      const activeTitle = document.title.replace(/ - Google.*$/, '').trim() || 'Current Document';
      const activeItem = {
        docId: activeMatch[2],
        title: activeTitle,
        type: activeType,
        modifiedTime: Date.now(),
        viewedTime: Date.now()
      };
      const existingIdx = tracked.findIndex(function(d) { return d && d.docId === activeMatch[2]; });
      if (existingIdx >= 0) {
        tracked[existingIdx] = Object.assign({}, tracked[existingIdx], activeItem);
      } else {
        tracked.unshift(activeItem);
      }
    }
    if (tracked.length === 0) {
      tracked = [{
        docId: 'doc_offline_ready',
        title: 'Document',
        type: 'kix',
        modifiedTime: Date.now(),
        viewedTime: Date.now()
      }];
    }
    const protoItems = tracked.map(buildItemProtobuf);
    // jFc: repeated field 1 is the array of iFc items
    const jFc = [ protoItems ];

    // qAp & nNw: field 1 = qAp (Type 5 VMw DocSyncedCheck)
    const qAp = [1, 1, 1];
    const nNw = [];
    nNw[0] = qAp;
    nNw[1] = qAp;

    // iNw: field 1 = hOp (Type 6 pMw)
    const iNw = [];
    iNw[0] = hOp;
    iNw[1] = hOp;

    // Root response:
    // Field 1 (index 0) = type
    // Field 2 (index 1) = null (no error for Yna())
    // Field 3 (index 2) = jFc (Type 2 IMw & Type 3 PEc)
    // Field 4 (index 3) = mNw (Type 4 tMw)
    // Field 5 (index 4) = iNw (Type 6 pMw)
    // Field 7 (index 6) = kNw (Type 10 AMw)
    // Field 8 (index 7) = nNw (Type 5 VMw)
    const resp = [];
    resp[0] = numType;
    resp[1] = null; // No error!
    resp[2] = jFc;  // Field 3 (Type 2 & Type 3: jFc with items!)
    resp[3] = mNw;  // Field 4 (Type 4 tMw)
    resp[4] = iNw;  // Field 5 (Type 6 pMw)
    resp[5] = iNw;  // 1-based index fallback
    resp[6] = kNw;  // Field 7 (Type 10 AMw)
    resp[7] = nNw;  // Field 8 (Type 5 VMw)
    resp[8] = nNw;  // 1-based index fallback

    return resp;
  }

  function buildProtoResponse(requestType) {
    return buildUnifiedPortResponse(requestType);
  }

  /**
   * Extract request type from a protobuf-serialized message array.
   * The request type is at field 1, which maps to index 0 in the serialized array.
   */
  function extractRequestType(message) {
    if (Array.isArray(message)) {
      dbg('extractRequestType: array, length:', message.length, 'first 5 els:', JSON.stringify(message.slice(0, 5)));
      // Field 1 = index 0 in the serialized array
      const val = message[0];
      if (typeof val === 'number') return val;
      // Some messages might have null at index 0 and type at index 1
      if (val == null && typeof message[1] === 'number') return message[1];
    }
    if (message && typeof message === 'object') {
      dbg('extractRequestType: object:', JSON.stringify(message).slice(0, 200));
      return message.type || message.requestType || message[1] || 4;
    }
    dbg('extractRequestType: unknown type, defaulting to 4');
    return 4; // Default to status check
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7: Chrome API Polyfills
  // Complete chrome.runtime, chrome.storage, chrome.alarms, chrome.offscreen
  // with correct protobuf-format responses for sendMessage.
  // ═══════════════════════════════════════════════════════════════════════════

  const storageKey = (k) => '__offlineSuite_' + k;

  // Polyfill self.close for service worker context
  window.close = window.close || function() {};
  if (typeof self !== 'undefined') self.close = self.close || function() {};

  // Polyfill clients API (needed by Gm() in the extension's service worker logic)
  const clientsPoly = {
    matchAll: () => Promise.resolve([{ url: 'chrome-extension://' + EXT_ID + '/offscreendocument.html' }]),
    get: () => Promise.resolve(null),
    openWindow: () => Promise.resolve(null),
    claim: () => Promise.resolve()
  };
  window.clients = window.clients || clientsPoly;
  if (typeof self !== 'undefined') self.clients = self.clients || clientsPoly;

  window.chrome = window.chrome || {};

  window.chrome.runtime = {
    id: EXT_ID,
    lastError: null,
    getManifest: () => ({ name: 'Google Docs Offline', version: EXT_VERSION, manifest_version: 3 }),
    getURL: (p) => 'chrome-extension://' + EXT_ID + '/' + (p || ''),

    // ─── sendMessage ───────────────────────────────────────────────────
    // Google Docs calls: chrome.runtime.sendMessage(EXT_ID, protoArray, callback)
    // We respond with a protobuf-format array matching what the real SW returns.
    sendMessage: function() {
      const args = Array.from(arguments);
      let targetId = EXT_ID, message = null, callback = null, options = null;

      // Parse args: sendMessage(extensionId, message, options?, callback?)
      // or: sendMessage(message, options?, callback?)
      if (typeof args[0] === 'string') {
        targetId = args[0]; message = args[1];
        if (typeof args[2] === 'object' && args[2] !== null && !Array.isArray(args[2]) && typeof args[2] !== 'function') {
          options = args[2];
          callback = typeof args[3] === 'function' ? args[3] : null;
        } else {
          callback = typeof args[2] === 'function' ? args[2] : (typeof args[3] === 'function' ? args[3] : null);
        }
      } else {
        message = args[0];
        callback = typeof args[1] === 'function' ? args[1] : (typeof args[2] === 'function' ? args[2] : null);
      }

      dbg('sendMessage called:', {
        targetId: targetId,
        message: JSON.stringify(message),
        hasCallback: !!callback,
        argTypes: args.map(a => typeof a),
        argsCount: args.length
      });

      // Extract request type from the protobuf message
      const requestType = extractRequestType(message);
      dbg('Extracted requestType:', requestType);

      // Build protobuf-format response
      const response = buildProtoResponse(requestType);
      dbg('Built response for type', requestType, ':', JSON.stringify(response));

      // Always respond — this is critical for the Settings dialog
      if (callback) {
        setTimeout(function() {
          dbg('Calling sendMessage callback with response');
          try { callback(response); } catch(e) { dbgWarn('sendMessage callback error:', e); }
        }, 10);
      } else {
        dbgWarn('No callback for sendMessage — response will be lost!');
      }

      // Return a Promise as well (MV3 style)
      return Promise.resolve(response);
    },

    // ─── connect ───────────────────────────────────────────────────────
    // Google Docs may use chrome.runtime.connect(EXT_ID) for port-based comms.
    // We create paired ports where the server auto-responds to all messages.
    connect: function(targetId, connectInfo) {
      dbg('chrome.runtime.connect called:', { targetId, connectInfo });
      const clientListeners = [];
      const clientPort = {
        name: (connectInfo && connectInfo.name) || 'default_port',
        onMessage: { addListener: (fn) => clientListeners.push(fn), removeListener: () => {} },
        onDisconnect: { addListener: () => {}, removeListener: () => {} },
        postMessage: function(msg) {
          setTimeout(function() {
            if (msg && msg.msg === 'driveEnabled') {
              const resp = { driveEnabled: true, supportsTeamDrives: true, qo_version: EXT_VERSION };
              clientListeners.forEach(function(fn) {
                try { fn(resp); } catch(e) {}
              });
              return;
            }
            const requestType = extractRequestType(msg);
            const response = buildProtoResponse(requestType);
            clientListeners.forEach(function(fn) {
              try { fn(response); } catch(e) {}
            });
          }, 10);
        },
        disconnect: function() {}
      };
      return clientPort;
    },

    onMessage: { addListener: function() {}, removeListener: function() {} },
    onMessageExternal: { addListener: function() {}, removeListener: function() {} },
    onConnectExternal: { addListener: function() {}, removeListener: function() {} }
  };

  window.chrome.storage = {
    local: {
      get: function(keys, cb) {
        dbg('chrome.storage.local.get called with:', keys);
        const res = {};
        try {
          if (typeof keys === 'string') {
            const val = localStorage.getItem(storageKey(keys));
            if (val !== null) res[keys] = JSON.parse(val);
          } else if (Array.isArray(keys)) {
            keys.forEach(function(k) {
              const val = localStorage.getItem(storageKey(k));
              if (val !== null) res[k] = JSON.parse(val);
            });
          } else {
            for (let i = 0; i < localStorage.length; i++) {
              const k = localStorage.key(i);
              if (k && k.startsWith('__offlineSuite_')) {
                res[k.replace('__offlineSuite_', '')] = JSON.parse(localStorage.getItem(k));
              }
            }
          }
        } catch(e) {}

        // Always report offline as enabled — this is checked by tm() in the SW
        res.offlineOptedIn = true;
        res.offlineEnabled = true;
        res.offlinePolicyAllows = true;
        res.offlineStorageSufficient = true;
        res['docs-offline-eeooip'] = true;
        res.lastSuccessfulFrameConnectTime = Date.now();

        const ouid = getOuid();
        if (!res.optedInUserOuid || res.optedInUserOuid === 'default') res.optedInUserOuid = ouid;

        if (cb) setTimeout(function() { cb(res); }, 0);
        return Promise.resolve(res);
      },
      set: function(obj, cb) {
        try {
          if (obj && typeof obj === 'object') {
            // Never allow opt-out
            if (obj.offlineOptedIn === false) obj.offlineOptedIn = true;
            if (!obj.optedInUserOuid || obj.optedInUserOuid === 'default') obj.optedInUserOuid = getOuid();
            Object.keys(obj).forEach(function(k) {
              localStorage.setItem(storageKey(k), JSON.stringify(obj[k]));
            });
          }
        } catch(e) {}
        if (cb) setTimeout(cb, 0);
        return Promise.resolve();
      },
      remove: function(keys, cb) {
        try {
          (Array.isArray(keys) ? keys : [keys]).forEach(function(k) {
            localStorage.removeItem(storageKey(k));
          });
        } catch(e) {}
        if (cb) setTimeout(cb, 0);
        return Promise.resolve();
      }
    },
    managed: {
      get: function(keys, cb) {
        // Managed policy: allow offline for all domains
        const config = {
          allowedDocsOfflineDomains: ['*', 'google.com', 'docs.google.com', 'drive.google.com', 'sheets.google.com', 'slides.google.com'],
          autoEnabledDocsOfflineDomains: ['*', 'google.com', 'docs.google.com', 'drive.google.com', 'sheets.google.com', 'slides.google.com']
        };
        let res = {};
        if (typeof keys === 'string') res[keys] = config[keys];
        else if (Array.isArray(keys)) keys.forEach(function(k) { res[k] = config[k]; });
        else res = Object.assign({}, config);
        if (cb) setTimeout(function() { cb(res); }, 0);
        return Promise.resolve(res);
      }
    }
  };

  window.chrome.alarms = {
    create: function() {},
    clear: function(n, cb) { if (cb) setTimeout(cb, 0); },
    get: function(n, cb) { if (cb) setTimeout(function() { cb(null); }, 0); },
    onAlarm: { addListener: function() {} }
  };

  window.chrome.offscreen = {
    createDocument: function() { return Promise.resolve(); },
    closeDocument: function() { return Promise.resolve(); }
  };

  window.chrome.tabs = window.chrome.tabs || {};
  window.chrome.app = window.chrome.app || {
    isInstalled: true,
    InstallState: { DISABLED: 'disabled', INSTALLED: 'installed', NOT_INSTALLED: 'not_installed' },
    RunningState: { CANNOT_RUN: 'cannot_run', READY_TO_RUN: 'ready_to_run', RUNNING: 'running' },
    getDetails: function() { return { id: EXT_ID, isInstalled: true }; },
    getIsInstalled: function() { return true; },
    installState: function(cb) { if (cb) cb('installed'); }
  };
  window.chrome.csi = window.chrome.csi || function() {
    return { startE: Date.now(), onloadT: Date.now(), pageT: 0, tran: 15 };
  };
  window.chrome.loadTimes = window.chrome.loadTimes || function() {
    return {
      connectionInfo: 'h2',
      finishDocumentLoadTime: 0,
      finishLoadTime: 0,
      firstPaintAfterLoadTime: 0,
      firstPaintTime: 0,
      navigationType: 'Other',
      npnNegotiatedProtocol: 'h2',
      requestTime: 0,
      startLoadTime: 0,
      wasAlternateProtocolAvailable: false,
      wasFetchedViaSpdy: true,
      wasNpnNegotiated: true
    };
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 8: ServiceWorker Registration Stub
  // Some versions of Docs check navigator.serviceWorker for the extension's
  // service worker. We provide a stub that reports an active worker.
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    if (!navigator.serviceWorker) {
      Object.defineProperty(navigator, 'serviceWorker', {
        value: {
          ready: Promise.resolve({
            active: { scriptURL: 'chrome-extension://' + EXT_ID + '/service_worker_bin_prod.js', state: 'activated' },
            scope: 'chrome-extension://' + EXT_ID + '/'
          }),
          controller: { scriptURL: 'chrome-extension://' + EXT_ID + '/service_worker_bin_prod.js', state: 'activated' },
          register: function() { return navigator.serviceWorker.ready; },
          getRegistration: function() { return navigator.serviceWorker.ready; },
          getRegistrations: function() { return navigator.serviceWorker.ready.then(function(r) { return [r]; }); },
          addEventListener: function() {},
          removeEventListener: function() {}
        },
        configurable: true,
        writable: true
      });
    }
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 9: Banner Removal & Status Override
  // Aggressively removes "reconnect" / "Trying to connect" / "offline"
  // notification banners and bottom-left toasts via CSS + DOM removal + setInterval.
  // ═══════════════════════════════════════════════════════════════════════════

  // Inject CSS to hide banners and toasts immediately (only when MOCK_NETWORK is enabled)
  if (MOCK_NETWORK) try {
    const bannerCSS = document.createElement('style');
    bannerCSS.id = 'offlineSuite-banner-hide';
    bannerCSS.textContent = `
      #docs-full-bleed-notification-banner,
      #docs-file-level-banner,
      #docs-account-level-banner,
      .full-bleed-banner,
      .docs-butterbar-container,
      .docs-material-butterbar,
      .docs-offline-butterbar,
      .docs-toast,
      .jfk-butterBar,
      .jfk-butterBar-shown,
      .app-switcher-butterbar,
      .apps-toast-fill,
      .apps-toast-content,
      .apps-toast-top,
      .apps-toast-panel {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
      }
    `;
    (document.head || document.documentElement).appendChild(bannerCSS);
  } catch(e) {}

  // DOM removal polling (only when MOCK_NETWORK is enabled)
  if (MOCK_NETWORK) try {
    setInterval(function() {
      document.querySelectorAll(
        '#docs-full-bleed-notification-banner, #docs-file-level-banner, #docs-account-level-banner, ' +
        '.full-bleed-banner, .docs-butterbar-container, .docs-material-butterbar, ' +
        '.apps-toast-fill, .apps-toast-panel, .docs-toast, .jfk-butterBar, [role="alert"]'
      ).forEach(function(el) {
        const text = (el.textContent || '').toLowerCase();
        if (text.includes('offline') || text.includes('reconnect') || text.includes('trying to connect')) {
          el.remove();
        }
      });
    }, 200);
  } catch(e) {}

  // Override document.title to replace "Trying to connect" with "Saved to this device"
  try {
    let realTitle = document.title;
    Object.defineProperty(document, 'title', {
      get: function() {
        return realTitle;
      },
      set: function(val) {
        if (MOCK_NETWORK && typeof val === 'string' && val.includes('Trying to connect')) {
          val = val.replace('Trying to connect', 'Saved to this device');
        }
        realTitle = val;
      },
      configurable: true
    });
  } catch(e) {}

  // Active Save Indicator Reconciler
  // When Google Docs sets the status caption to "Trying to connect...",
  // immediately update it to "Saved to this device".
  if (MOCK_NETWORK) try {
    function reconcileSaveIndicator() {
      const captions = document.querySelectorAll(
        '.docs-save-indicator-caption, .docs-titlebar-badge, .docs-save-indicator'
      );
      captions.forEach(function(el) {
        const text = (el.textContent || '').trim();
        if (text.includes('Trying to connect') || text.includes('Reconnecting')) {
          el.textContent = 'Saved to this device';
        }
      });
    }

    setInterval(reconcileSaveIndicator, 250);

    const saveObserver = new MutationObserver(function() {
      reconcileSaveIndicator();
    });
    saveObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
      characterData: true
    });
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 10: MessagePort RPC Protocol Handler
  // Responds to Google Docs port RPC messages using the exact protobuf
  // structures expected by the compiled closure client code.
  // ═══════════════════════════════════════════════════════════════════════════

  function handlePortMessage(e) {
    const replyPort = e.ports && e.ports[0];
    if (replyPort) {
      window.__offlineSuitePorts.push(replyPort);
    }
    dbg('handlePortMessage called, has replyPort:', !!replyPort, 'data:', JSON.stringify(e.data));
    if (!replyPort) return;

    const req = e.data;
    let type = 4;
    if (Array.isArray(req)) {
      if (typeof req[0] === 'number') {
        type = req[0];
      } else if (typeof req[1] === 'number') {
        type = req[1];
      } else if (req[0] !== undefined) {
        type = Number(req[0]) || 4;
      }
    } else if (req && typeof req === 'object') {
      type = typeof req.type === 'number' ? req.type : (typeof req.requestType === 'number' ? req.requestType : 4);
    }
    dbg('Parsed port request type:', type);

    const resp = buildUnifiedPortResponse(type);

    if (type === 1) {
      const userChan = new MessageChannel();
      window.__offlineSuiteChannels.push(userChan);
      window.__offlineSuitePorts.push(userChan.port1, userChan.port2);
      userChan.port2.onmessage = handlePortMessage;
      try {
        replyPort.postMessage(resp, [userChan.port1]);
      } catch(err) {
        replyPort.postMessage(resp);
      }
    } else {
      try {
        replyPort.postMessage(resp);
      } catch(err) {
        replyPort.postMessage([]);
      }
    }
  }

  function configurePort(port) {
    if (!port || port.__offlineSuiteConfigured) return;
    port.__offlineSuiteConfigured = true;
    window.__offlineSuitePorts.push(port);
    port.onmessage = handlePortMessage;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 11: Iframe Interception & Handshake
  // Google Docs creates hidden iframes for the extension handshake.
  // We intercept their creation and inject a script FROM WITHIN the iframe
  // that posts a MessagePort back to the parent — creating a real
  // MessageEvent with correct event.source.
  // ═══════════════════════════════════════════════════════════════════════════

  // Build the script that runs inside the iframe
  // It creates a MessageChannel, configures port2 for RPC, and sends port1 to parent
  const IFRAME_HANDSHAKE_SCRIPT = `(function(){
    try {
      window.__offlineSuitePorts = window.__offlineSuitePorts || [];
      window.__offlineSuiteChannels = window.__offlineSuiteChannels || [];

      function makeResp(t) {
        var num = typeof t === 'number' ? t : 4;
        if (num === 12) return [12];
        if (num === 10) return [10, null, null, null, null, null, [[2]]];
        var lNw = [1, 1, null, null, 1, 1];
        var mNw = [lNw, lNw];
        var hOp = [1, 1, 1];
        var kNw = [hOp, hOp];
        var items = [];
        try {
          var saved = localStorage.getItem('__offlineSuite_trackedDocs');
          if (saved) {
            var parsed = JSON.parse(saved);
            if (Array.isArray(parsed)) {
              items = parsed;
            }
          }
        } catch(x) {}
        var refPath = '';
        try {
          if (window.parent && window.parent.location && window.parent.location.pathname) {
            refPath = window.parent.location.pathname;
          }
        } catch(x) {}
        if (!refPath && document.referrer) {
          refPath = document.referrer;
        }
        var pm = String(refPath || '').match(/\\/(document|spreadsheets|presentation)\\/d\\/([a-zA-Z0-9_-]+)/);
        if (pm) {
          var activeType = pm[1] === 'spreadsheets' ? 'ritz' : (pm[1] === 'presentation' ? 'punch' : 'kix');
          var foundIdx = items.findIndex(function(it) { return it && it.docId === pm[2]; });
          var activeEntry = { docId: pm[2], title: 'Current Document', type: activeType, modifiedTime: Date.now(), viewedTime: Date.now() };
          if (foundIdx >= 0) {
            items[foundIdx].type = activeType;
          } else {
            items.unshift(activeEntry);
          }
        }
        var protoItems = items.filter(Boolean).map(function(p) {
          var pType = (p.type === 'ritz' || p.type === 'punch' || p.type === 'drawing') ? p.type : 'kix';
          var mod = typeof p.modifiedTime === 'number' ? p.modifiedTime : Date.now();
          var viewed = typeof p.viewedTime === 'number' ? p.viewedTime : Date.now();
          return [String(p.docId || 'doc_offline_ready'), String(p.title || 'Document'), pType, mod, viewed, null, true, true, 1, true, 0, 0, false, true, null];
        });
        if (protoItems.length === 0) {
          protoItems = [['doc_offline_ready', 'Document', 'kix', Date.now(), Date.now(), null, true, true, 1, true, 0, 0, false, true, null]];
        }
        var jFc = [protoItems];
        var qAp = [1, 1, 1];
        var nNw = [qAp, qAp];
        var iNw = [hOp, hOp];
        var r = [];
        r[0] = num;
        r[1] = null;
        r[2] = jFc;
        r[3] = mNw;
        r[4] = iNw;
        r[5] = iNw;
        r[6] = kNw;
        r[7] = nNw;
        r[8] = nNw;
        return r;
      }

      function onIframeMsg(e) {
        var replyPort = e.ports && e.ports[0];
        if (replyPort) window.__offlineSuitePorts.push(replyPort);
        if (!replyPort) return;
        var req = e.data;
        var type = 4;
        if (Array.isArray(req)) {
          if (typeof req[0] === 'number') type = req[0];
          else if (typeof req[1] === 'number') type = req[1];
          else if (req[0] !== undefined) type = Number(req[0]) || 4;
        } else if (req && typeof req === 'object') {
          type = typeof req.type === 'number' ? req.type : (typeof req.requestType === 'number' ? req.requestType : 4);
        }
        var resp = makeResp(type);
        if (type === 1) {
          var uc = new MessageChannel();
          window.__offlineSuiteChannels.push(uc);
          window.__offlineSuitePorts.push(uc.port1, uc.port2);
          uc.port2.onmessage = onIframeMsg;
          try { replyPort.postMessage(resp, [uc.port1]); } catch(x) { replyPort.postMessage(resp); }
        } else {
          try { replyPort.postMessage(resp); } catch(x) { replyPort.postMessage([]); }
        }
      }

      var chan = new MessageChannel();
      window.__offlineSuiteChannels.push(chan);
      window.__offlineSuitePorts.push(chan.port1, chan.port2);
      chan.port2.onmessage = onIframeMsg;
      window.parent.postMessage('', '*', [chan.port1]);
    } catch(e) {}
  })();`;

  try {
    function injectHandshakeIntoIframe(iframe) {
      if (!iframe || iframe.__offlineSuiteHandshakeSent) return;
      iframe.__offlineSuiteHandshakeSent = true;

      function tryInject() {
        try {
          const doc = iframe.contentDocument || (iframe.contentWindow && iframe.contentWindow.document);
          if (!doc) return false;
          const script = doc.createElement('script');
          script.textContent = IFRAME_HANDSHAKE_SCRIPT;
          (doc.head || doc.documentElement || doc).appendChild(script);
          iframe.__offlineSuiteHandshakeComplete = true;
          return true;
        } catch(e) {
          // Cross-origin or not yet loaded — fall back to synthetic event
          return false;
        }
      }

      // Try immediately
      if (!tryInject()) {
        // Try on load/error
        iframe.addEventListener('load', function() { tryInject(); });
        iframe.addEventListener('error', function() { tryInject(); });
      }

      // Single fallback synthetic handshake after 250ms if script injection didn't complete
      setTimeout(function() {
        if (iframe.__offlineSuiteHandshakeComplete) return;
        try {
          const chan = new MessageChannel();
          window.__offlineSuiteChannels.push(chan);
          window.__offlineSuitePorts.push(chan.port1, chan.port2);
          configurePort(chan.port2);

          const event = new MessageEvent('message', {
            data: '',
            origin: window.location.origin,
            ports: [chan.port1]
          });
          event.__isOfflineSuiteHandshake = true;
          try {
            Object.defineProperty(event, 'source', {
              get: function() { return iframe.contentWindow; },
              configurable: true
            });
          } catch(e) {}
          try {
            Object.defineProperty(event, 'origin', {
              get: function() { return window.location.origin; },
              configurable: true
            });
          } catch(e) {}
          try {
            Object.defineProperty(event, 'ports', {
              get: function() { return [chan.port1]; },
              configurable: true
            });
          } catch(e) {}
          window.dispatchEvent(event);
          iframe.__offlineSuiteHandshakeComplete = true;
        } catch(e) {}
      }, 250);
    }

    function checkAndInject(el) {
      if (el && el.tagName === 'IFRAME') {
        const src = el.src || el.getAttribute('src') || '';
        dbg('Detected iframe:', src.slice(0, 120));
        if (src.includes('iframeapi') || src.includes('/offline') || src.includes('extensionframe')) {
          dbg('>>> Matching iframe found — injecting handshake');
          injectHandshakeIntoIframe(el);
        }
      } else if (el && el.tagName === 'SCRIPT') {
        const src = el.src || el.getAttribute('src') || '';
        if (src.includes('page_embed_script.js') || src.includes('chrome-extension://')) {
          dbg('>>> Intercepted page_embed_script.js insertion — faking load success');
          try {
            el.removeAttribute('src');
            el.textContent = '/* OfflineSuite page_embed_script bypassed */';
          } catch(e) {}
          setTimeout(function() {
            try {
              const evt = new Event('load');
              el.dispatchEvent(evt);
              if (typeof el.onload === 'function') el.onload(evt);
            } catch(e) {}
          }, 0);
        }
      }
    }

    // Hook appendChild/insertBefore to detect iframe creation
    const origAppendChild = Node.prototype.appendChild;
    Node.prototype.appendChild = function(child) {
      const res = origAppendChild.apply(this, arguments);
      try { checkAndInject(child); } catch(e) {}
      return res;
    };

    const origInsertBefore = Node.prototype.insertBefore;
    Node.prototype.insertBefore = function(newNode, ref) {
      const res = origInsertBefore.apply(this, arguments);
      try { checkAndInject(newNode); } catch(e) {}
      return res;
    };

    // Hook iframe.src setter
    const iframeSrcDesc = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'src');
    if (iframeSrcDesc && iframeSrcDesc.set) {
      const origSrcSet = iframeSrcDesc.set;
      Object.defineProperty(HTMLIFrameElement.prototype, 'src', {
        set: function(val) {
          origSrcSet.call(this, val);
          try {
            if (typeof val === 'string' && (val.includes('iframeapi') || val.includes('/offline'))) {
              injectHandshakeIntoIframe(this);
            }
          } catch(e) {}
        },
        get: iframeSrcDesc.get,
        configurable: true
      });
    }

    // Hook script.src setter to intercept page_embed_script.js before CSP blocks it
    const scriptSrcDesc = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src');
    if (scriptSrcDesc && scriptSrcDesc.set) {
      const origScriptSrcSet = scriptSrcDesc.set;
      Object.defineProperty(HTMLScriptElement.prototype, 'src', {
        set: function(val) {
          if (typeof val === 'string' && (val.includes('page_embed_script.js') || val.includes('chrome-extension://'))) {
            dbg('>>> Intercepted script.src set to page_embed_script.js — faking success');
            const self = this;
            setTimeout(function() {
              try {
                const evt = new Event('load');
                self.dispatchEvent(evt);
                if (typeof self.onload === 'function') self.onload(evt);
              } catch(e) {}
            }, 0);
            return;
          }
          return origScriptSrcSet.call(this, val);
        },
        get: scriptSrcDesc.get,
        configurable: true
      });
    }

    // MutationObserver fallback
    if (typeof MutationObserver !== 'undefined') {
      const observer = new MutationObserver(function(mutations) {
        for (const mut of mutations) {
          for (const node of mut.addedNodes) {
            checkAndInject(node);
            if (node.querySelectorAll) {
              node.querySelectorAll('iframe[src*="iframeapi"], iframe[src*="offline"]').forEach(checkAndInject);
            }
          }
        }
      });
      observer.observe(document.documentElement || document, { childList: true, subtree: true });
    }
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 12: Iframe-Context Handshake (runs when this script is injected
  // into the offline extension iframe itself via forMainFrameOnly: false)
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    if (window !== window.top) {
      const path = window.location.pathname || '';
      const href = window.location.href || '';
      dbg('Running in iframe:', href);
      if (path.includes('/offline') || path.includes('iframeapi') || href.includes('extensionframe')) {
        dbg('>>> Iframe matches extension handshake pattern — sending handshake');
        let handshakeSent = false;
        function sendIframeHandshake() {
          if (handshakeSent) return;
          try {
            const chan = new MessageChannel();
            window.__offlineSuiteChannels.push(chan);
            window.__offlineSuitePorts.push(chan.port1, chan.port2);
            chan.port2.onmessage = handlePortMessage;
            window.parent.postMessage('', '*', [chan.port1]);
            handshakeSent = true;
          } catch(e) {}
        }
        sendIframeHandshake();
        setTimeout(function() { if (!handshakeSent) sendIframeHandshake(); }, 200);
      }
    }
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 13: Window Message Handler Wrapper
  // Wraps all window 'message' event listeners to accept our handshake
  // messages and provide correct event.source when needed.
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    const origAddEvt = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, listener, options) {
      if (this === window && type === 'message' && typeof listener === 'function') {
        const wrapped = function(event) {
          // If this is our synthetic or iframe handshake with ports, guarantee source matches iframe.contentWindow
          if (event && (event.__isOfflineSuiteHandshake || (event.ports && event.ports.length && !event.origin?.includes('ogs.google.com')))) {
            const ifr = document.querySelector('iframe[src*="iframeapi"], iframe[src*="offline"]');
            if (ifr && ifr.contentWindow) {
              try {
                Object.defineProperty(event, 'source', {
                  get: function() { return ifr.contentWindow; },
                  configurable: true
                });
              } catch(e) {}
            }
            try {
              Object.defineProperty(event, 'origin', {
                get: function() { return window.location.origin; },
                configurable: true
              });
            } catch(e) {}
          }
          return listener.apply(this, arguments);
        };
        return origAddEvt.call(this, type, wrapped, options);
      }
      return origAddEvt.apply(this, arguments);
    };
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 13B: Settings Dialog DOM Reconciler & Interactive Switch
  // Reconciles the Google Docs Settings dialog offline status:
  //   1. Replaces "Checking offline sync status. Please wait." with the official
  //      enabled copy: "Not recommended on public or shared computers. Learn more"
  //   2. Flips the slide switch to ON and ensures aria-checked="true"
  //   3. Supports full interactive click toggling (OFF <-> ON)
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    const ENABLED_DESC_HTML = 'Not recommended on public or shared computers. <a class="docs-homescreen-settings-offline-learn-more" href="https://support.google.com/docs/answer/6388102" target="_blank" rel="noopener" style="color: #1a73e8; text-decoration: none;">Learn more</a>';
    const DISABLED_DESC_TEXT = 'Offline is turned off for this computer.';

    let offlineOptedIn = true;

    function reconcileSettingsDialog() {
      const dialog = document.querySelector('.docs-homescreen-settings-dialog');
      if (!dialog) return;

      const desc = dialog.querySelector('.docs-homescreen-settings-offline-description');
      const switchContainer = dialog.querySelector('.docs-homescreen-settings-offline-slideswitch');
      const switchEl = switchContainer ? (switchContainer.querySelector('[role="checkbox"], [role="switch"], .jfk-slide-switch') || switchContainer) : null;

      if (desc) {
        const text = (desc.textContent || '').trim();
        if (text.includes('Checking offline sync status') || text === '') {
          if (offlineOptedIn) {
            desc.innerHTML = ENABLED_DESC_HTML;
          }
        }
      }

      if (switchEl) {
        if (!switchContainer.__offlineSuiteWired) {
          switchContainer.__offlineSuiteWired = true;

          // Initial state: ON
          if (offlineOptedIn) {
            switchEl.setAttribute('aria-checked', 'true');
            switchEl.setAttribute('aria-disabled', 'false');
            switchEl.classList.add('jfk-slide-switch-on');
            switchEl.classList.remove('jfk-slide-switch-off', 'goog-checkbox-disabled', 'docs-material-gm-checkbox-disabled');
            if (desc) desc.innerHTML = ENABLED_DESC_HTML;
          }

          // Interactive click handler
          const handleToggle = function(e) {
            e.stopPropagation();
            e.preventDefault();

            offlineOptedIn = !offlineOptedIn;
            dbg('Settings offline switch toggled. New state:', offlineOptedIn ? 'ON' : 'OFF');

            if (offlineOptedIn) {
              switchEl.setAttribute('aria-checked', 'true');
              switchEl.classList.add('jfk-slide-switch-on');
              switchEl.classList.remove('jfk-slide-switch-off');
              if (desc) desc.innerHTML = ENABLED_DESC_HTML;
              try {
                localStorage.setItem('docs-offline-optin', 'true');
                if (window.chrome && window.chrome.storage && window.chrome.storage.local) {
                  window.chrome.storage.local.set({ offlineOptedIn: true, offlineEnabled: true });
                }
              } catch(err) {}
            } else {
              switchEl.setAttribute('aria-checked', 'false');
              switchEl.classList.add('jfk-slide-switch-off');
              switchEl.classList.remove('jfk-slide-switch-on');
              if (desc) desc.textContent = DISABLED_DESC_TEXT;
              try {
                localStorage.setItem('docs-offline-optin', 'false');
                if (window.chrome && window.chrome.storage && window.chrome.storage.local) {
                  window.chrome.storage.local.set({ offlineOptedIn: false, offlineEnabled: false });
                }
              } catch(err) {}
            }
          };

          switchContainer.addEventListener('click', handleToggle, true);
          switchContainer.addEventListener('keydown', function(e) {
            if (e.key === ' ' || e.key === 'Enter') handleToggle(e);
          }, true);
        } else {
          // Keep current state synchronized
          if (offlineOptedIn) {
            if (switchEl.getAttribute('aria-checked') !== 'true') {
              switchEl.setAttribute('aria-checked', 'true');
              switchEl.classList.add('jfk-slide-switch-on');
              switchEl.classList.remove('jfk-slide-switch-off');
            }
            if (desc && desc.textContent.includes('Checking offline sync status')) {
              desc.innerHTML = ENABLED_DESC_HTML;
            }
          }
        }
      }
    }

    if (window === window.top) {
      if (typeof MutationObserver !== 'undefined') {
        const settingsObserver = new MutationObserver(function() {
          reconcileSettingsDialog();
        });
        settingsObserver.observe(document.documentElement || document, {
          childList: true,
          subtree: true,
          characterData: true
        });
      }
      setInterval(reconcileSettingsDialog, 1000);
    }
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 14: Document Auto-Saver (Swift Bridge)
  // Debounced text extractor that pipes document content to native Swift
  // via window.webkit.messageHandlers.offlineSuite
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    let saveTimer = null;
    function scheduleAutoSave() {
      if (saveTimer) clearTimeout(saveTimer);
      saveTimer = setTimeout(function() {
        try {
          const editor = document.querySelector('.kix-appview-editor') ||
                         document.querySelector('.punch-viewer-content') ||
                         document.querySelector('#waffle-rich-text-editor') ||
                         document.querySelector('.grid-container') ||
                         document.querySelector('.docs-editor-container') ||
                         document.querySelector('.docs-editor') ||
                         document.body;
          const titleInput = document.querySelector('.docs-title-input');
          let title = titleInput ? titleInput.value : document.title;
          title = title.replace(/ - Google (Docs|Sheets|Slides|Drive)$/i, '').trim();
          if (!title) title = 'Active Document';
          const text = editor ? editor.innerText : '';
          if (text && text.length > 5 && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) {
            // Piped strictly to local sandboxed cache on disk; never transmitted externally
            window.webkit.messageHandlers.offlineSuite.postMessage({
              action: 'autoSave',
              title: title,
              content: text,
              url: window.location.href,
              timestamp: Date.now()
            });
          }
        } catch(e) {}
      }, 1500);
    }
    document.addEventListener('input', scheduleAutoSave, { passive: true });
    document.addEventListener('keyup', scheduleAutoSave, { passive: true });
  } catch(e) {}

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 15: Document Tracker (Smart Tracking for Offline)
  // Detects open documents and reports metadata to Swift.
  // ═══════════════════════════════════════════════════════════════════════════

  function trackDocument() {
    const path = window.location.pathname || '';
    let docType = null, exportFormat = 'docx', docId = null;

    const docMatch = path.match(/\/document\/d\/([a-zA-Z0-9_-]+)/);
    const sheetMatch = path.match(/\/spreadsheets\/d\/([a-zA-Z0-9_-]+)/);
    const slideMatch = path.match(/\/presentation\/d\/([a-zA-Z0-9_-]+)/);

    if (docMatch) { docType = 'docs'; docId = docMatch[1]; exportFormat = 'docx'; }
    else if (sheetMatch) { docType = 'sheets'; docId = sheetMatch[1]; exportFormat = 'xlsx'; }
    else if (slideMatch) { docType = 'slides'; docId = slideMatch[1]; exportFormat = 'pptx'; }

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
        rawTitle = document.title.replace(/ - Google (Docs|Sheets|Slides|Drive)$/i, '').trim();
      }
    }

    if (!rawTitle || rawTitle === 'Google Docs' || rawTitle === 'Google Sheets' || rawTitle === 'Google Slides') {
      rawTitle = 'Untitled ' + (docType === 'docs' ? 'Document' : docType === 'sheets' ? 'Spreadsheet' : 'Presentation');
    }

    const baseUrl = docType === 'docs' ? 'document' : docType === 'sheets' ? 'spreadsheets' : 'presentation';
    const exportUrl = 'https://docs.google.com/' + baseUrl + '/d/' + docId + '/export?format=' + exportFormat;

    // Persist to local offline list so Type 2/3 responses can provide this document
    try {
      const existingList = getTrackedDocsList();
      const existingIdx = existingList.findIndex(function(d) { return d.docId === docId; });
      const docEntry = {
        docId: docId,
        title: rawTitle,
        type: docType === 'sheets' ? 'ritz' : (docType === 'slides' ? 'punch' : 'kix'),
        appType: docType,
        url: window.location.href,
        exportUrl: exportUrl,
        modifiedTime: Date.now(),
        viewedTime: Date.now()
      };
      if (existingIdx >= 0) {
        existingList[existingIdx] = Object.assign(existingList[existingIdx], docEntry);
      } else {
        existingList.unshift(docEntry);
      }
      localStorage.setItem('__offlineSuite_trackedDocs', JSON.stringify(existingList));
    } catch(e) {}

    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) {
        window.webkit.messageHandlers.offlineSuite.postMessage({
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

  function scanHomescreenDocuments() {
    const docsMap = new Map();
    getTrackedDocsList().forEach(function(d) {
      if (d && d.docId) docsMap.set(d.docId, d);
    });

    const links = document.querySelectorAll(
      'a[href*="/document/d/"], a[href*="/spreadsheets/d/"], a[href*="/presentation/d/"], ' +
      '.docs-homescreen-grid-item, .docs-homescreen-list-item, .docs-homescreen-grid-item[data-id], .docs-homescreen-list-item[data-id]'
    );

    links.forEach(function(el) {
      let href = el.getAttribute('href') || (el.querySelector('a') && el.querySelector('a').getAttribute('href')) || '';
      let docId = el.getAttribute('data-id') || '';
      const pagePath = window.location.pathname || '';
      let docType = pagePath.includes('/spreadsheets') ? 'sheets' : (pagePath.includes('/presentation') ? 'slides' : 'docs');
      let protoType = docType === 'sheets' ? 'ritz' : (docType === 'slides' ? 'punch' : 'kix');

      if (href) {
        const m = href.match(/\/(document|spreadsheets|presentation)\/d\/([a-zA-Z0-9_-]+)/);
        if (m) {
          if (m[1] === 'spreadsheets') { docType = 'sheets'; protoType = 'ritz'; }
          else if (m[1] === 'presentation') { docType = 'slides'; protoType = 'punch'; }
          else { docType = 'docs'; protoType = 'kix'; }
          docId = m[2];
        }
      }

      if (docId) {
        let titleEl = el.querySelector('.docs-homescreen-grid-item-title, .docs-homescreen-list-item-title, .docs-homescreen-item-title') || el;
        let title = (titleEl.getAttribute('aria-label') || titleEl.textContent || 'Document').replace(/\n+/g, ' ').trim();
        title = title.replace(/(Opened|Created|Modified).*/i, '').trim();
        if (!title || title.length < 2) title = 'Document';
        if (title.length > 80) title = title.slice(0, 80);

        const baseUrl = docType === 'docs' ? 'document' : (docType === 'sheets' ? 'spreadsheets' : 'presentation');
        const exportFormat = docType === 'docs' ? 'docx' : (docType === 'sheets' ? 'xlsx' : 'pptx');
        const exportUrl = 'https://docs.google.com/' + baseUrl + '/d/' + docId + '/export?format=' + exportFormat;

        const existing = docsMap.get(docId) || {};
        const resolvedTitle = (existing.title && existing.title !== 'Document') ? existing.title : title;
        docsMap.set(docId, {
          docId: docId,
          title: resolvedTitle,
          type: protoType,
          appType: docType,
          url: 'https://docs.google.com/' + baseUrl + '/d/' + docId + '/edit',
          exportUrl: exportUrl,
          modifiedTime: existing.modifiedTime || Date.now(),
          viewedTime: existing.viewedTime || Date.now()
        });
      }
    });

    const list = Array.from(docsMap.values());
    if (list.length > 0) {
      try {
        localStorage.setItem('__offlineSuite_trackedDocs', JSON.stringify(list));
      } catch(e) {}

      try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) {
          window.webkit.messageHandlers.offlineSuite.postMessage({
            action: 'documentListScanned',
            documents: list.map(function(d) {
              return {
                docId: d.docId,
                title: d.title,
                type: d.appType || (d.type === 'ritz' ? 'sheets' : (d.type === 'punch' ? 'slides' : 'docs')),
                url: d.url,
                exportUrl: d.exportUrl
              };
            })
          });
        }
      } catch(e) {}
    }
  }

  setTimeout(scanHomescreenDocuments, 1500);
  setTimeout(scanHomescreenDocuments, 4000);
  setTimeout(scanHomescreenDocuments, 8000);
  setInterval(scanHomescreenDocuments, 10000);

  setTimeout(trackDocument, 300);
  setTimeout(trackDocument, 1500);
  setTimeout(trackDocument, 4000);
  setTimeout(trackDocument, 10000);
  window.addEventListener('load', trackDocument);

  let trackTimer = null;
  function scheduleTrack() {
    if (trackTimer) clearTimeout(trackTimer);
    trackTimer = setTimeout(trackDocument, 3000);
  }
  document.addEventListener('input', scheduleTrack, { passive: true });
  document.addEventListener('keyup', scheduleTrack, { passive: true });
  document.addEventListener('mouseup', scheduleTrack, { passive: true });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 16: Ready Signal
  // Notify Swift that OfflineSuite bridge is active
  // ═══════════════════════════════════════════════════════════════════════════

  try {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.offlineSuite) {
      window.webkit.messageHandlers.offlineSuite.postMessage({
        action: 'bridgeReady',
        version: EXT_VERSION,
        extensionId: EXT_ID
      });
    }
  } catch(e) {}

})();
