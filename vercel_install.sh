#!/bin/bash
git config --global --add safe.directory '*'
if [ ! -d "flutter" ]; then
  curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.0-stable.tar.xz | tar -xJ
fi
./flutter/bin/flutter config --enable-web
./flutter/bin/flutter pub get
