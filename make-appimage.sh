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

# Deploy dependencies (this bundles .so dependencies)
quick-sharun ./AppDir/bin/*

# Restore the pristine binaries to their proper locations without overwriting the sharun wrappers
# quick-sharun moves the real binary to shared/bin/ and replaces bin/ with a sharun wrapper.
if [ -f "./AppDir/shared/bin/ChatGPT" ]; then
    cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT
else
    # If it wasn't moved, only overwrite if it's not the sharun wrapper (though quick-sharun always moves it)
    cp /tmp/ChatGPT_pristine ./AppDir/bin/ChatGPT
fi

# Restore app.asar to prevent Electron ASAR integrity check failure
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar
chmod +x ./AppDir/shared/bin/ChatGPT 2>/dev/null || true

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage --no-sandbox
