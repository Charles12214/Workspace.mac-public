# Security Policy

## Supported Releases

| Version | Supported          |
| ------- | ------------------ |
| 1.3.x   | :white_check_mark: |
| 1.2.x   | :white_check_mark: |
| 1.1.x   | :x:                |
| 1.0.x   | :x:                |

## Security & Privacy Commitment

Workspace.mac is an open-source, client-side macOS application connecting directly to Google Workspace services through Apple's native WebKit sandboxing.
- Direct-to-Google communication only (plus optional Open-Meteo API weather queries when explicitly enabled by the user, with coordinates rounded to 2 decimal places).
- Zero telemetry, zero analytics, and zero third-party proxy servers.
- Session cookies and caches are stored per-account inside isolated native `WKWebsiteDataStore` containers on your Mac.
- Saved weather coordinates are encrypted at rest with AES-256-GCM (Apple CryptoKit) in `~/Library/Application Support/Workspace.mac/SecureLocationVault/`.

## Reporting a Security Concern

If you believe you have discovered a vulnerability, please open a private GitHub Security Advisory or report it via GitHub Issues so it can be reviewed and patched promptly.
