#!/bin/bash
# Builds only dlls/ntdll/ntdll.so (the macOS half of ntdll) from the patched
# winecx source at commit 7dbc5b5 (the source of Whisky's v4.6.4-beta.1 engine).
# llvm-mingw is only here so Wine's configure accepts the tree; ntdll.so itself
# is compiled by Apple's clang for x86_64.
set -e
# Run from a folder holding ./winecx (dappermint/winecx at 7dbc5b5 with the patch applied)
# and ./llvm-mingw (llvm-mingw-20261006-ucrt-macos-universal).
S="${S:-$PWD}"
L=$S/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin

export PATH="$L:$(brew --prefix)/opt/bison/bin:$(brew --prefix)/opt/flex/bin:$PATH"
export SDKROOT="$(xcrun --show-sdk-path)"
export MACOSX_DEPLOYMENT_TARGET=15.0
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export CFLAGS="-O2 -Wno-error=implicit-function-declaration"
export CROSSCFLAGS="-O2"
export ac_cv_func_pipe2=no

rm -rf "$S/build" && mkdir -p "$S/build" && cd "$S/build"

echo "== configure (log: $S/build/configure.log)"
../winecx/configure --host=x86_64-apple-darwin24 --enable-archs=x86_64 --disable-tests \
  --without-x --without-wayland --without-gstreamer --without-freetype --without-gnutls \
  --without-oss --without-alsa --without-pulse --without-sane --without-usb --without-v4l2 \
  --without-pcap --without-capi --without-opencl --without-ffmpeg --without-cups \
  --without-vulkan --without-sdl --without-krb5 --without-netapi --without-unwind \
  --prefix=/opt/whiskywine > configure.log 2>&1 || { tail -20 configure.log; exit 1; }

echo "== make ntdll.so (log: $S/build/make.log)"
make -j"$(sysctl -n hw.ncpu)" dlls/ntdll/ntdll.so > make.log 2>&1 || { tail -30 make.log; exit 1; }

ls -la dlls/ntdll/ntdll.so
file dlls/ntdll/ntdll.so
echo "== done"
