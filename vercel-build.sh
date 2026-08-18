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

# API_BASE_URL is a Vercel Environment Variable (Project Settings -> Environment
# Variables) pointing at the deployed findme_backend_fastapi instance. Falls back to
# the ApiClient's own localhost default (with a console warning) if unset -- fine for a
# first deploy before the backend has a public URL, not fine for real use.
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL:-}"
