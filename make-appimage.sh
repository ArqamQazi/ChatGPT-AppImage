#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')

# Deploy dependencies (this bundles .so dependencies)
./quick-sharun.sh ./AppDir/bin/*

# Turn AppDir into AppImage
./quick-sharun.sh --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
./quick-sharun.sh --test ./dist/*.AppImage --no-sandbox
