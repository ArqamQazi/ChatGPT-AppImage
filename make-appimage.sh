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
cp ./AppDir/bin/resources/app.asar /tmp/app_asar_pristine

# Deploy dependencies
quick-sharun ./AppDir/bin/*

# Restore pristine binary and asar to prevent patchelf corruption and ASAR integrity failure
cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
