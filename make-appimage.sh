#!/bin/sh
set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')

# 1. Backup pristine files before quick-sharun modifies or wraps them
cp ./AppDir/bin/ChatGPT /tmp/ChatGPT_pristine
cp ./AppDir/bin/resources/app.asar /tmp/app_asar_pristine
cp ./AppDir/bin/resources/codex /tmp/codex_pristine
cp ./AppDir/bin/resources/codex-code-mode-host /tmp/codex_host_pristine
cp ./AppDir/bin/resources/rg /tmp/rg_pristine

# 2. Deploy dependencies
quick-sharun ./AppDir/bin/*

# 3. Restore pristine ChatGPT to shared/bin/ (rm -f first to guarantee unlinking)
rm -f ./AppDir/shared/bin/ChatGPT
cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT
chmod +x ./AppDir/shared/bin/ChatGPT

# 4. Restore pristine app.asar (prevents Electron ASAR integrity check SIGILL crashes)
rm -f ./AppDir/bin/resources/app.asar
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar

# 5. Restore pristine static-PIE binaries to bin/resources/ (rm -f first to avoid clobbering sharun hardlinks)
rm -f ./AppDir/bin/resources/codex
cp /tmp/codex_pristine ./AppDir/bin/resources/codex
chmod +x ./AppDir/bin/resources/codex

rm -f ./AppDir/bin/resources/codex-code-mode-host
cp /tmp/codex_host_pristine ./AppDir/bin/resources/codex-code-mode-host
chmod +x ./AppDir/bin/resources/codex-code-mode-host

rm -f ./AppDir/bin/resources/rg
cp /tmp/rg_pristine ./AppDir/bin/resources/rg
chmod +x ./AppDir/bin/resources/rg

# Clean up redundant nested sharun wrappers created by quick-sharun
rm -f ./AppDir/shared/bin/codex ./AppDir/bin/codex
rm -f ./AppDir/shared/bin/codex-code-mode-host ./AppDir/bin/codex-code-mode-host
rm -f ./AppDir/shared/bin/rg ./AppDir/bin/rg

# 6. Build AppImage
quick-sharun --make-appimage

# 7. Test AppImage
quick-sharun --test ./dist/*.AppImage --no-sandbox
