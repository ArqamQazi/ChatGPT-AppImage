#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm libnss_nis nss-mdns nss

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here

echo "Getting binary..."
echo "---------------------------------------------------------------"
case "$ARCH" in
	x86_64)  farch=amd64;;
	aarch64) farch=arm64;;
esac
DEB_LINK=https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_$farch.deb

wget --retry-connrefused --tries=30 "$DEB_LINK" -O /tmp/temp.deb
ar xvf /tmp/temp.deb
tar -xvf ./data.tar.xz

mkdir -p ./AppDir/bin
mv -v ./usr/lib/chatgpt/* ./AppDir/bin

tar -xvf ./control.tar.xz
awk -F':| ' '/Version:/{print $NF; exit}' ./control > ~/version
rm -f ./*.xz

# desktop entry checks for a chatgpt symlink to ChatGPT in /usr/bin
ln -sv ChatGPT ./AppDir/bin/chatgpt || :

cp -v ./usr/share/applications/chatgpt.desktop ./AppDir
cp -v ./usr/share/pixmaps/chatgpt.png          ./AppDir
cp -v ./usr/share/pixmaps/chatgpt.png          ./AppDir/.DirIcon

# The app ships the Qt compat shims, which is odd
# normally this is only used by Chromium browsers to follow the system theme
# I have never seen them being used by electron apps before
# TODO: Test this in Plasma and see if it uses the plasma decorations
rm -f ./AppDir/bin/libqt*_shim.so

# if you also have to make nightly releases check for DEVEL_RELEASE = 1
#
# if [ "${DEVEL_RELEASE-}" = 1 ]; then
# 	nightly build steps
# else
# 	regular build steps
# fi
