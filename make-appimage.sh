#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')

# Backup the pristine Electron binary and app.asar BEFORE quick-sharun corrupts them
cp ./AppDir/bin/ChatGPT /tmp/ChatGPT_pristine

# Deploy dependencies (this bundles .so dependencies)
quick-sharun ./AppDir/bin/*

if [ -f "./AppDir/shared/bin/ChatGPT" ]; then
  cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT
else
  cp /tmp/ChatGPT_pristine ./AppDir/bin/ChatGPT
fi

chmod +x ./AppDir/shared/bin/ChatGPT 2>/dev/null || true

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage --no-sandbox
