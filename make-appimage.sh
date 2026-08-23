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

# Inject LD_PRELOAD library to trick detect-libc without modifying the ASAR files
echo "GNU C Library (GNU libc) 2.31" > ./AppDir/fake-ldd
cat << 'C_EOF' > spoof.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>

static int (*orig_openat)(int, const char *, int, ...);
static int (*orig_openat64)(int, const char *, int, ...);
static int (*orig_open)(const char *, int, ...);
static int (*orig_open64)(const char *, int, ...);

void __attribute__((constructor)) init() {
    orig_openat = dlsym(RTLD_NEXT, "openat");
    orig_openat64 = dlsym(RTLD_NEXT, "openat64");
    orig_open = dlsym(RTLD_NEXT, "open");
    orig_open64 = dlsym(RTLD_NEXT, "open64");
}

int openat(int dirfd, const char *pathname, int flags, ...) {
    if (pathname && strcmp(pathname, "/usr/bin/ldd") == 0) {
        const char *fake = getenv("FAKE_LDD_PATH");
        if (fake) pathname = fake;
    }
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    return orig_openat ? orig_openat(dirfd, pathname, flags, mode) : -1;
}

int openat64(int dirfd, const char *pathname, int flags, ...) {
    if (pathname && strcmp(pathname, "/usr/bin/ldd") == 0) {
        const char *fake = getenv("FAKE_LDD_PATH");
        if (fake) pathname = fake;
    }
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    return orig_openat64 ? orig_openat64(dirfd, pathname, flags, mode) : -1;
}

int open(const char *pathname, int flags, ...) {
    if (pathname && strcmp(pathname, "/usr/bin/ldd") == 0) {
        const char *fake = getenv("FAKE_LDD_PATH");
        if (fake) pathname = fake;
    }
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    return orig_open ? orig_open(pathname, flags, mode) : -1;
}

int open64(const char *pathname, int flags, ...) {
    if (pathname && strcmp(pathname, "/usr/bin/ldd") == 0) {
        const char *fake = getenv("FAKE_LDD_PATH");
        if (fake) pathname = fake;
    }
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode = va_arg(args, mode_t);
        va_end(args);
    }
    return orig_open64 ? orig_open64(pathname, flags, mode) : -1;
}
C_EOF
gcc -shared -fPIC spoof.c -o ./AppDir/shared/lib/spoof-ldd.so -ldl
rm spoof.c

mv ./AppDir/AppRun ./AppDir/AppRun.real
cat << 'A_EOF' > apprun.c
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    const char *appdir = getenv("APPDIR");
    if (!appdir) {
        fprintf(stderr, "APPDIR not set\n");
        return 1;
    }
    
    setenv("SHARUN_ALLOW_LD_PRELOAD", "1", 1);
    
    char fake_ldd[4096];
    snprintf(fake_ldd, sizeof(fake_ldd), "%s/fake-ldd", appdir);
    setenv("FAKE_LDD_PATH", fake_ldd, 1);
    
    char preload[8192];
    const char *old_preload = getenv("LD_PRELOAD");
    if (old_preload && old_preload[0] != '\0') {
        snprintf(preload, sizeof(preload), "%s/shared/lib/spoof-ldd.so:%s", appdir, old_preload);
    } else {
        snprintf(preload, sizeof(preload), "%s/shared/lib/spoof-ldd.so", appdir);
    }
    setenv("LD_PRELOAD", preload, 1);
    
    char real_apprun[4096];
    snprintf(real_apprun, sizeof(real_apprun), "%s/AppRun.real", appdir);
    
    execv(real_apprun, argv);
    perror("execv");
    return 1;
}
A_EOF
gcc apprun.c -o ./AppDir/AppRun
rm apprun.c

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage --no-sandbox
