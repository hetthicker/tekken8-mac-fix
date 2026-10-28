#!/bin/bash
# Installs the TEKKEN 8 fiber fix into Whisky's (frankea fork) v4.6.4-beta.1 engine,
# and optionally the Steam black-window fix into a bottle.
#
#   bash install.sh                  # engine fix only
#   bash install.sh "<bottle path>"  # engine fix + Steam window fix for that bottle
#   bash install.sh --uninstall      # restore the original engine files
set -e
cd "$(dirname "$0")"

LIB="$HOME/Library/Application Support/com.franke.Whisky/Libraries"
W="$LIB/Wine/lib/wine"
NTDLL="$W/x86_64-unix/ntdll.so"
KB="$W/x86_64-windows/kernelbase.dll"

STOCK_NTDLL=670d760e44c8925d75bfdac409f2db8ed237d11416bdfd545fdf3953106fc23c
STOCK_KB=6f906cf5057d95b7bf7bb369646d1e24f3a3a55fd7878769099930e3c131b48a
FIX_NTDLL=3472980b5219be271634fbd4c200ea0bda0340bd46913c054d6ed61e23d40d7f
FIX_KB=a74c598c293e146a5e2450cbe3e5644bb842169f8c8cca5f94926af119b5a189

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
die() { echo "error: $*" >&2; exit 1; }

[ -f "$NTDLL" ] || die "Whisky engine not found at $LIB. Install frankea Whisky and its engine first."
pgrep -qf wineserver && die "Wine is running. Quit Steam and Whisky first."

if [ "$1" = "--uninstall" ]; then
  for f in "$NTDLL" "$KB"; do
    [ -f "$f.orig" ] && mv -f "$f.orig" "$f" && echo "restored $(basename "$f")"
  done
  exit 0
fi

install_one() { # target stock fixed newfile
  local cur; cur=$(sha "$1")
  if [ "$cur" = "$3" ]; then echo "$(basename "$1"): already patched"; return; fi
  [ "$cur" = "$2" ] || die "$(basename "$1") is not the v4.6.4-beta.1 original (sha $cur). This fix only fits engine 4.6.4-beta.1."
  cp -p "$1" "$1.orig"
  cp "$4" "$1"
  [ "$(sha "$1")" = "$3" ] || die "copy of $(basename "$1") failed verification"
  echo "$(basename "$1"): patched (original kept as $(basename "$1").orig)"
}

install_one "$NTDLL" "$STOCK_NTDLL" "$FIX_NTDLL" files/ntdll.so
install_one "$KB" "$STOCK_KB" "$FIX_KB" files/kernelbase.dll
chmod 755 "$NTDLL"

BOTTLE="$1"
[ -n "$BOTTLE" ] || { echo "Done. (Pass your bottle path to also apply the Steam window fix.)"; exit 0; }
[ -d "$BOTTLE/drive_c" ] || die "not a Whisky bottle: $BOTTLE"

CEF="$BOTTLE/drive_c/Program Files (x86)/Steam/bin/cef/cef.win64"
[ -d "$CEF" ] || die "Steam not found in bottle (expected $CEF). Install Steam and run it once first."

# Wine's own dxgi, with the "Wine builtin DLL" marker at 0x40 zeroed so Wine
# loads it as a native DLL next to steamwebhelper (instead of the GPTK dxgi shim).
[ -f "$CEF/dxgi.dll" ] && [ ! -f "$CEF/dxgi.dll.bak" ] && cp -p "$CEF/dxgi.dll" "$CEF/dxgi.dll.bak"
cp "$W/x86_64-windows/dxgi.dll" "$CEF/dxgi.dll"
printf '\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0' | dd of="$CEF/dxgi.dll" bs=1 seek=64 conv=notrunc 2>/dev/null
echo "Steam: installed native dxgi.dll in cef.win64"

K='HKCU\Software\Wine\AppDefaults\steamwebhelper.exe\DllOverrides'
for d in d3d10core d3d11 d3d9 dxgi; do
  WINEPREFIX="$BOTTLE" "$LIB/Wine/bin/wine" reg add "$K" /v $d /d n,b /f >/dev/null 2>&1
done
for d in d3d12 nvapi64; do
  WINEPREFIX="$BOTTLE" "$LIB/Wine/bin/wine" reg add "$K" /v $d /d "" /f >/dev/null 2>&1
done
WINEPREFIX="$BOTTLE" "$LIB/Wine/bin/wineserver" -k 2>/dev/null || true
echo "Steam: steamwebhelper DLL overrides set"
echo "Done."
