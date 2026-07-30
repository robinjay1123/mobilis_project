#!/bin/bash
set -e

echo "=== Cleaning old Flutter cache ==="
rm -rf flutter

echo "=== Downloading Flutter 3.27.0 Linux SDK ==="
curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.0-stable.tar.xz | tar -xJ

export PATH="$PWD/flutter/bin:$PATH"

echo "=== Flutter SDK Info ==="
flutter --version

echo "=== Configuring Web ==="
flutter config --enable-web

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Building Web Application ==="
flutter build web --release --base-href /
