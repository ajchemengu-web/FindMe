# FindMe

A cross-platform (iOS/Android/Web) mobile app for tracking devices you own or have
permission to, viewing global conflict zones on a live map, and following global
politics/business news. Rebuilt in Flutter from an earlier Expo/React Native version.

## Repo layout

```
lib/                        Flutter app (this repo's root -- Vercel deploys this
                             directly via vercel.json + vercel-build.sh)
findme_backend_fastapi/      FastAPI + PostgreSQL/PostGIS backend the app talks to
```

- Frontend setup/screens: see this file and the code under `lib/`.
- Backend setup, API surface, and known gaps: [`findme_backend_fastapi/README.md`](./findme_backend_fastapi/README.md).

## Frontend (Flutter)

```
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://findme-backend-fzex.onrender.com
```

**The `--dart-define=API_BASE_URL=...` is required on every build/run command, web or
native.** Without it, the app silently falls back to `http://localhost:8000` (with a
console warning) -- on a web build that only ever works if you're also running the
backend locally; on an Android/iOS device or emulator "localhost" means *that device*,
not your computer or the deployed backend, so every request (sign-up included) just
fails to connect. This bit us once already building a local debug APK -- see git log
around "Sign up fails on physical device" for the exact symptom.

Building a debug APK to sideload on a physical Android device:

```
flutter build apk --debug --dart-define=API_BASE_URL=https://findme-backend-fzex.onrender.com
# adb not on PATH? call it directly:
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-debug.apk
```

Key build-time config (`--dart-define`, or set as Vercel environment variables for
web deploys):

- `API_BASE_URL` -- the backend's base URL (see above -- effectively required).
- `GOOGLE_CLIENT_ID` -- Web OAuth Client ID from Google Cloud Console, needed for
  "Continue with Google" to actually complete a sign-in (the button renders without it).

## Backend (FastAPI)

Deployed on Render at `https://findme-backend-fzex.onrender.com` (Blueprint defined in
`render.yaml`, auto-deploys from `main`; migrations run automatically on every boot via
`entrypoint.sh`). See [`findme_backend_fastapi/README.md`](./findme_backend_fastapi/README.md)
for local dev via `docker compose up`, the full API surface, and known gaps (no rate
limiting, ACLED ingestion needs its own API key, etc).

## Deploying

- **Frontend**: this repo is connected to Vercel at its root -- push to `main` and it
  rebuilds automatically (`vercel-build.sh` bootstraps the Flutter SDK during the build
  since Vercel's image doesn't ship it, and bakes in `API_BASE_URL`/`GOOGLE_CLIENT_ID`
  from Vercel's own project environment variables).
- **Backend**: Render, via `render.yaml` -- push to `main` and it redeploys
  automatically (`docker compose up` also still works for local dev; see the backend
  README). An equivalent `fly.toml` exists for Fly.io as an alternative, not currently
  used.
