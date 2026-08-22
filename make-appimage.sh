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

# We MUST set PATH_MAPPING here so quick-sharun bundles pathmap.so
# And it must contain SHARUN_DIR to pass the validation check
export PATH_MAPPING='/dummy:${SHARUN_DIR}/dummy'

# Backup the pristine Electron binary and app.asar BEFORE quick-sharun patches them
cp ./AppDir/bin/ChatGPT /tmp/ChatGPT_pristine
cp ./AppDir/bin/resources/app.asar /tmp/app_asar_pristine

# Also backup all other binaries in resources/ to prevent /usr/share patching which breaks codex
mkdir -p /tmp/pristine_bins
find ./AppDir/bin/resources -maxdepth 1 -type f -executable -not -name '*.js' -not -name '*.asar' -exec cp {} /tmp/pristine_bins/ \;

# Deploy dependencies
quick-sharun ./AppDir/bin/*

# Restore pristine binary and asar to prevent patchelf and sed corruption
cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT
cp /tmp/app_asar_pristine ./AppDir/bin/resources/app.asar

# Restore pristine binaries to shared/bin to revert harmful /usr/share patching
for f in /tmp/pristine_bins/*; do
    if [ -f "$f" ]; then
        cp "$f" ./AppDir/shared/bin/$(basename "$f")
    fi
done

# 3. Append PATH_MAPPING to .env AFTER quick-sharun to prevent it from hardcoding the build path
sed -i 's|^PATH_MAPPING=\(.*\)|PATH_MAPPING=\1,/usr/bin/ldd:${APPDIR}/bin/fake-ldd,/XXX/YYY/ZZZ:${APPDIR}/bin/fake-ldd,/etc/alpine-release:${APPDIR}/does-not-exist,/XXX/alpine-release:${APPDIR}/does-not-exist|g' ./AppDir/.env

# Additional changes can be done in between here

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds
quick-sharun --test ./dist/*.AppImage --no-sandbox
