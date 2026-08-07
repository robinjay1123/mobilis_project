#!/bin/bash
set -e
git config --global --add safe.directory '*'
if [ -d "flutter" ]; then
  rm -rf flutter
fi
git clone --depth 1 --branch 3.27.4 https://github.com/flutter/flutter.git
./flutter/bin/flutter config --enable-web
./flutter/bin/flutter pub get
