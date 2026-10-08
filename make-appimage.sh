#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')

# Backup pristine codex and ripgrep binaries before quick-sharun wraps or modifies them
cp ./AppDir/bin/resources/app.asar /tmp/app_asar_pristine

# Deploy dependencies (this bundles .so dependencies)
quick-sharun ./AppDir/bin/*

rm -f ./AppDir/bin/resources/app.asar
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage --no-sandbox
