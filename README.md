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
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Key build-time config (`--dart-define`, or set as Vercel environment variables for
deploys):

- `API_BASE_URL` -- the backend's base URL. Falls back to `http://localhost:8000` with
  a console warning if unset.
- `GOOGLE_CLIENT_ID` -- Web OAuth Client ID from Google Cloud Console, needed for
  "Continue with Google" to actually complete a sign-in (the button renders without it).

## Backend (FastAPI)

Self-hosted, not yet deployed anywhere public. See
[`findme_backend_fastapi/README.md`](./findme_backend_fastapi/README.md) for local dev
via `docker compose up`, the full API surface, and known gaps (no rate limiting, ACLED
ingestion is a stub, etc).

## Deploying

- **Frontend**: this repo is connected to Vercel at its root -- push to `main` and it
  rebuilds automatically (`vercel-build.sh` bootstraps the Flutter SDK during the build
  since Vercel's image doesn't ship it).
- **Backend**: not yet deployed. It's a stateful FastAPI service (Postgres+PostGIS,
  self-hosted S3-compatible storage) that doesn't fit Vercel's serverless model as
  cleanly as the frontend does -- needs a host that runs a persistent container (e.g.
  Render, Fly.io, Railway) plus a managed Postgres with the PostGIS extension.
