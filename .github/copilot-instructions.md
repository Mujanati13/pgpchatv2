# Project Guidelines

## Architecture
- This workspace is a multi-project repo with three active apps:
  - `pgpchat/`: Flutter mobile client (main product).
  - `backend/`: Express + MySQL API server for auth, messages, contacts, sessions, settings, uploads.
  - `pgp-delete-account/`: React + Vite static page for account deletion requests.
- Mobile and backend integrate over HTTP API routes under `/api/*`.
- PGP model is client-first: key generation, encryption, and decryption are done on-device in `pgpchat/lib/services/pgp_service.dart`.
- Backend auth is JWT + server-side session validation (session must exist in DB for authenticated requests).

## Code Style
- Follow existing file-local style and naming; avoid broad refactors in unrelated files.
- Flutter/Dart:
  - Respect `flutter_lints` and provider-based state architecture (`AuthProvider`, `ChatProvider`, `SettingsProvider`).
  - Keep API access in `ApiService` and crypto/key logic in `PgpService`.
- Backend/Node:
  - Keep route error responses JSON-shaped as `{ error: string }`.
  - Preserve `/api` route prefix and middleware ordering in `backend/app.js`.

## Build and Test
- Run commands from the relevant project directory, not workspace root.
- Flutter app (`pgpchat/`):
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter run`
- Backend (`backend/`):
  - `npm install`
  - `npm run dev` (or `npm start`)
- Delete-account app (`pgp-delete-account/`):
  - `npm install`
  - `npm run dev`
  - `npm run lint`
  - `npm run build`
- Backend health check: `GET /api/health`.

## Conventions
- Keep private keys local to device storage; never send private keys to backend APIs.
- Public-key sync endpoint is `/api/auth/public-key` (PUT primary, POST fallback for method-restricted environments).
- When changing auth flows, account for `authenticate` middleware behavior: missing/invalid token or revoked session must return 401.
- Keep large encrypted payload paths compatible with current backend body limits (`10mb`).
- Do not assume Firebase push works without setup; see `GUIDE.md` for required Firebase files and env vars.

## Pitfalls
- `pgpchat/lib/main.dart` currently forces API base URL to production IP on startup; do not assume local/staging URL persists.
- This repo may run multiple backend PM2 process names in deployment; verify logs against the active process before diagnosing.
- Emulator logs often include EGL/renderer warnings unrelated to feature correctness; prioritize app exceptions and API responses.

## References
- Product/setup and push-notification prerequisites: `GUIDE.md`
- Mobile architecture entry: `pgpchat/lib/main.dart`
- Backend API entry: `backend/app.js`
- Auth/session rules: `backend/middleware/auth.js`, `backend/routes/auth.js`
