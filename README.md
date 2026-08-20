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

### Situation Room globe (`lib/widgets/rotating_globe.dart`)

Was a small 64px decorative wireframe sphere (meridian lines only, no actual map). Now
a real world map: the same land-dot coastline sampling as the original React Native
app's globe (ported from `findme_situation_room_mockup.html`'s `DOTS` array, see
`lib/core/globe_dots.dart`/`lib/core/globe_math.dart`), drawn large and center-stage on
`situation_room_screen.dart` (was tucked in the header, tiny) via a `CustomPainter`.
Threat zones and visible devices are plotted on it as colored markers (conflict=red,
unrest=yellow, disaster=pink, devices=accent blue), tap anywhere on it to open the Map
tab. No new dependency -- `CustomPainter` is core Flutter, same role `@shopify/react-native-skia`
played in the RN version.

### Map search & directions (`lib/core/directions_service.dart`)

The Map tab now has a Google-Maps-style search bar: type a place, pick a result, get a
driving route from your current location with distance/ETA and turn-by-turn steps.
Deliberately **not** Google Places/Directions -- this map already runs on free CartoDB
tiles instead of the Google Maps SDK specifically to avoid a Cloud API key, so search
uses **Nominatim** (OpenStreetMap's geocoder) and routing uses **OSRM**'s public demo
server, both free and keyless. No setup step needed for this one, unlike most other
external integrations in this app -- but see `directions_service.dart`'s own doc
comment: OSRM's public instance is documented as light-use-only, and a wide-audience
launch would want to self-host both rather than lean on the shared public servers.

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
