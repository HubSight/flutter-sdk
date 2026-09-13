# Changelog

All notable changes to this project will be documented in this file.

## 1.1.3 - 2026-09-13

### Changed
- Bugfix send metadata device via HTTP Headers


## 1.1.2 - 2026-09-13

### Changed
- Fix send metadata


## 1.1.1 - 2026-09-13

### Fixed
- **Incorrect HTTP API Base URL**: `HubSightSDK.initialize()` and `HubSightApiClient.updateConfig()` were using `gateway_url` (no `/api` suffix) instead of `api_base_url` to configure the Dio client's `baseUrl`, causing all REST API calls to hit the wrong path. Requests now correctly target `api_base_url` as defined in the `.hscfg` config.

## 1.1.0 - 2026-09-12

### Added
- **Geolocation Support in Session Management & Device Metadata**:
  - Added geolocation coordinates (`geoCity`, `geoCountry`, `geoRegion`, `geoLatitude`, `geoLongitude`, `geoAccuracy`) and device audit fields (`ipAddress`, `userAgent`, `deviceFingerprint`, `deviceLabel`, `clientType`, `isNewDevice`, `isActive`, `lastActiveAt`, `revokedAt`, `revokeReason`) to `SessionItem`.
  - Extended `HubSightDeviceMetadata` and `DeviceInfoCollector.collect()` to support passing GPS / OS location (`latitude`, `longitude`, `accuracy`, `geoCity`, `geoCountry`, `geoRegion`).
  - Updated `HubSightAuthManager.login()` and `HubSightAuthManager.verify2FA()` to accept optional geolocation parameters.
  - Added public getter `deviceMetadata` on `HubSightApiClient`.

## 1.0.0 - 2026-09-11

### Added
- **Zero-Config Enrollment (`.hscfg`)**: Support for decrypting multi-layered `.hscfg` secure container with 6-digit PIN using Argon2id (64MB RAM, 4 rounds) + AES-256-GCM (AAD: `HSCFG\x01`) + Ed25519 digital signature + In-Memory ZIP decompression.
- **Atomic Token Refresh (Anti Race-Condition 401)**: Interceptor with Mutex queue and token freshness check preventing duplicate refresh calls when multiple requests fail simultaneously.
- **Emergency Kill-Switch (HTTP 503)**: Automatic handling of `APP_API_DISABLED` and `Retry-After: 300` headers.
- **Client Device Metadata Contract**: Device fingerprinting (SHA-256) and dual HTTP header injection (`X-Device-Fingerprint`, `X-Device-Label`, `X-Client-Type`).
- **Real-time Camera Thumbnails**: Camera list snapshot widget `HubSightCameraThumbnail` with automatic refresh and `gaplessPlayback: true`.
- **Multi-View Batching**: Single SDP exchange request (`batch-webrtc`), unified 30s heartbeat (`batch-heartbeat`), and batch release (`batch-release`).
- **NVR Archive & Playback**: Calendar recording query, timeline segments, and direct presigned MP4 stream playback.
- **FCM Push Notification Lifecycle**: Push token registration on login, unregistration on logout, and lightweight badge unread counter.
- **Real-time Relay & Remote Session Revocation**: Socket.IO client listening for `session:revoked` to kick revoked devices immediately.
- **App Lifecycle Management**: Automatic cleanup and stream pausing when app enters background.
- **Ready-to-Use UI Widgets**: `HubSightCameraThumbnail`, `HubSightWebRTCView`, and `HubSightMultiViewGrid`.
- **Comprehensive Test Suite**: Unit tests covering crypto, interceptors, services, and models.
- **Full Demo Example App**: Interactive Flutter demo application in `example/`.
