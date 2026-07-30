#!/bin/bash
set -e
set -x

echo "=== Cleaning old Flutter cache & Windows lockfile ==="
rm -rf flutter .pub-cache .dart_tool pubspec.lock

echo "=== Setting Environment Variables ==="
export BOT=true
export FLUTTER_ALLOW_ROOT=true
export CI=true
export PUB_CACHE="$PWD/.pub-cache"
export PATH="$PWD/flutter/bin:$PATH"

echo "=== Downloading Flutter 3.27.0 Linux SDK ==="
curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.0-stable.tar.xz | tar -xJ

echo "=== Flutter SDK Info ==="
flutter --version

echo "=== Configuring Web ==="
flutter config --enable-web

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Building Web Application ==="
flutter build web --release --base-href /
