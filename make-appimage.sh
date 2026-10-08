#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')

# Backup pristine codex and ripgrep binaries before quick-sharun wraps or modifies them
cp ./AppDir/bin/resources/codex /tmp/codex_pristine
cp ./AppDir/bin/resources/codex-code-mode-host /tmp/codex_host_pristine
cp ./AppDir/bin/resources/rg /tmp/rg_pristine
cp ./AppDir/bin/resources/app.asar /tmp/app_asar_pristine

# Deploy dependencies (this bundles .so dependencies)
quick-sharun ./AppDir/bin/*

rm -f ./AppDir/bin/resources/codex
cp /tmp/codex_pristine ./AppDir/bin/resources/codex
chmod +x ./AppDir/bin/resources/codex

rm -f ./AppDir/bin/resources/codex-code-mode-host
cp /tmp/codex_host_pristine ./AppDir/bin/resources/codex-code-mode-host
chmod +x ./AppDir/bin/resources/codex-code-mode-host

rm -f ./AppDir/bin/resources/rg
cp /tmp/rg_pristine ./AppDir/bin/resources/rg
chmod +x ./AppDir/bin/resources/rg

rm -f ./AppDir/bin/resources/app.asar
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar

# Clean up redundant nested sharun wrappers created by quick-sharun
rm -f ./AppDir/shared/bin/codex ./AppDir/bin/codex
rm -f ./AppDir/shared/bin/codex-code-mode-host ./AppDir/bin/codex-code-mode-host
rm -f ./AppDir/shared/bin/rg ./AppDir/bin/rg
# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage --no-sandbox
