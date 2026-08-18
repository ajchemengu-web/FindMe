#!/usr/bin/env bash
# Vercel's build image doesn't ship Flutter, so this fetches the SDK fresh each build
# (Vercel's build cache can carry ./.flutter-sdk across builds via vercel.json's cache
# config to speed this up later -- not set up yet, first correctness, then speed).
set -euo pipefail

if [ ! -d ".flutter-sdk" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable .flutter-sdk
fi
export PATH="$PWD/.flutter-sdk/bin:$PATH"

flutter config --enable-web --no-analytics
flutter pub get

# Both are Vercel Environment Variables (Project Settings -> Environment Variables):
# API_BASE_URL points at the deployed findme_backend_fastapi instance (falls back to
# ApiClient's localhost default, with a console warning, if unset). GOOGLE_CLIENT_ID is
# the Web OAuth Client ID from Google Cloud Console -> Credentials (the Google button
# renders either way, but can't complete a sign-in until this is set).
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-}" \
  --dart-define=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
