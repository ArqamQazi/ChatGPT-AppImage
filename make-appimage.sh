#!/bin/bash
set -eu

ARCH=$(uname -m)
export ARCH
export APPDIR="$PWD/AppDir"
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-pkgforge-dev/ChatGPT-AppImage}
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export STRACE_BINARY=$(find ./AppDir/bin -maxdepth 1 -type f -executable | grep -v '\.so')
export ALWAYS_SOFTWARE=1

# 1. Create a fake ldd script to spoof libc detection
echo '#!/bin/sh' > ./AppDir/bin/fake-ldd
echo 'echo "ldd (GNU libc) 2.33"' >> ./AppDir/bin/fake-ldd
chmod +x ./AppDir/bin/fake-ldd

# 2. Create dummy file to spoof alpine-release
echo '#!/bin/sh' > ./AppDir/bin/___
echo 'echo "ldd (GNU libc) 2.33"' >> ./AppDir/bin/___
chmod +x ./AppDir/bin/___

# We MUST set PATH_MAPPING here so quick-sharun bundles pathmap.so
# And it must contain SHARUN_DIR to pass the validation check
export PATH_MAPPING='/dummy:${SHARUN_DIR}/dummy'

# Move resources OUT of AppDir/bin so quick-sharun doesn't touch it!
rm -rf /tmp/resources_pristine && mv ./AppDir/bin/resources /tmp/resources_pristine

# Backup the pristine Electron binary
cp ./AppDir/bin/ChatGPT /tmp/ChatGPT_pristine

# Deploy dependencies
quick-sharun ./AppDir/bin/*

# Restore pristine binary to prevent patchelf corruption
cp /tmp/ChatGPT_pristine ./AppDir/shared/bin/ChatGPT

# Restore resources into shared/bin/ where the real ChatGPT binary expects it
mv /tmp/resources_pristine ./AppDir/shared/bin/resources

# Symlink resources back into bin/ so argv[0]-relative checks (e.g. app.asar) succeed
ln -sf ../shared/bin/resources ./AppDir/bin/resources

# Append PATH_MAPPING to .env AFTER quick-sharun to prevent it from hardcoding the build path
sed -i 's|^PATH_MAPPING=\(.*\)|PATH_MAPPING=\1,/usr/bin/ldd:${SHARUN_DIR}/bin/fake-ldd,/XXX/YYY/ZZZ:${SHARUN_DIR}/bin/fake-ldd,/etc/alpine-release:${SHARUN_DIR}/does-not-exist,/XXX/alpine-release:${SHARUN_DIR}/does-not-exist|g' ./AppDir/.env

# Turn AppDir into AppImage
quick-sharun --make-appimage
