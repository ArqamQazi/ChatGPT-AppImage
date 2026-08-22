#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')

# 1. Create a fake ldd script to spoof libc detection
echo '#!/bin/sh' > ./AppDir/bin/fake-ldd
echo 'echo "ldd (GNU libc) 2.33"' >> ./AppDir/bin/fake-ldd
chmod +x ./AppDir/bin/fake-ldd

# 2. quick-sharun unconditionally patches ldd strings in all .js files (like detect-libc.js).
# We must provide a fake `___` binary to intercept `___ --version`, which is the patched version of `ldd --version`
echo '#!/bin/sh' > ./AppDir/bin/___
echo 'echo "ldd (GNU libc) 2.33"' >> ./AppDir/bin/___
chmod +x ./AppDir/bin/___

# 3. Configure PATH_MAPPING for both the pristine AND the patched string paths
export PATH_MAPPING='
  /usr/bin/ldd:${SHARUN_DIR}/bin/fake-ldd
  /XXX/YYY/ZZZ:${SHARUN_DIR}/bin/fake-ldd
  /etc/alpine-release:${SHARUN_DIR}/does-not-exist
  /XXX/alpine-release:${SHARUN_DIR}/does-not-exist
'

# Backup the pristine Electron binary and app.asar BEFORE quick-sharun patches them
cp ./AppDir/bin/ChatGPT /tmp/ChatGPT_pristine
cp ./AppDir/bin/resources/app.asar /tmp/app_asar_pristine

# Deploy dependencies
quick-sharun ./AppDir/bin/*

# Restore pristine binary and asar to prevent patchelf and sed corruption
cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds
quick-sharun --test ./dist/*.AppImage --no-sandbox
