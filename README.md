# TEKKEN 8 on Apple Silicon Macs (Whisky + D3DMetal)

A fix that lets **TEKKEN 8** (Steam app 1778820) run on Apple Silicon Macs through
[frankea's Whisky fork](https://github.com/frankea/Whisky) with its GPTK/D3DMetal engine.
It also fixes Steam's black window.

Tested on an M4 Pro, macOS 26, Whisky 3.7.0, engine **v4.6.4-beta.1**, GPTK 4.0 beta 3.
The game runs, and both online ranked matches and player matches with friends work. For matches with friends, turn off VPNs such as Cloudflare WARP (see below).

## What it fixes

| Problem | Cause | Fix |
|---|---|---|
| TEKKEN 8 crashes on launch (`EXCEPTION_ACCESS_VIOLATION` reading `0x907`) | On macOS this Wine leaves `gs` pointing at the pthread TSD while Windows code runs. `gs:0x20` is Windows' *FiberData* slot, but on macOS it's the thread's QoS slot (`0x8ff`). The game's `GetCurrentFiber()` reads `0x8ff`, then `SwitchToFiber(0x8ff)` crashes. | A patched `ntdll.so` swaps the fiber pointer and the QoS value in and out of that slot on every Windows⇄Unix transition. A patched `kernelbase.dll` writes the fiber pointer into the slot that the game actually reads. |
| Steam window is completely black | D3DMetal crashes in Steam's GPU process, and wined3d only offers feature level 9_3 on macOS | DXVK's d3d11 for `steamwebhelper.exe`, plus Wine's own dxgi loaded as a native DLL |

## Install

1. Install Whisky (frankea fork) and its engine:
   ```
   brew install --cask frankea/whisky/whisky
   ```
   Open Whisky and let it download the engine. In Whisky's settings, use engine **v4.6.4-beta.1**.
   The installer checks this and refuses any other engine version.
2. Import GPTK's D3DMetal into Whisky as usual (Apple's
   [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/), which needs a free developer account).
   It isn't included here because Apple's licence doesn't allow redistributing it.
3. Make a bottle, install Steam in it and run Steam once. Bottle settings:
   - Graphics backend: **Recommended**
   - DXR: **on**
   - GPU spoofing: **on**
   - Enhanced sync: **None**
4. Quit Steam and Whisky, then in Terminal:
   ```
   git clone <this repo> && cd tekken8-mac-fix
   bash install.sh
   ```
   To also fix Steam's black window, pass your bottle's path. In Whisky, right-click the bottle and choose "Show in Finder", then drag the folder into Terminal after `bash install.sh `:
   ```
   bash install.sh ~/Library/Containers/com.franke.Whisky/Bottles/<BOTTLE-ID>
   ```
5. Launch Steam from Whisky and start TEKKEN 8. Don't add `-dx11` to the launch options, because the game needs DX12.

To undo the engine changes, run `bash install.sh --uninstall`.

## Wrong online region (e.g. America instead of Asia)

Whisky starts programs with `LANG=en_US.UTF-8`, so the game thinks you're in the US.
In Whisky, open the bottle's **Program Settings** for `steam.exe` (and `Steam.exe` if it appears) and add these environment variables:

| Variable | Value (example for India / Asia) |
|---|---|
| `LANG` | `en_IN.UTF-8` |
| `LC_ALL` | `en_IN.UTF-8` |

Use your own locale, for example `ja_JP.UTF-8` or `en_GB.UTF-8`.

## "Failed to establish connection with the opponent" / high ping

Lobbies go through Bandai Namco's servers, but matches are a direct peer-to-peer UDP connection.
VPNs such as **Cloudflare WARP (1.1.1.1)** block incoming P2P connections and add latency, so turn them off while playing.
If the problem continues, enable UPnP on your router and check the NAT type in TEKKEN's online settings.

## Known issues

- Steam's dropdown menus are white and some store content is black. These are Wine window-management bugs, and the library and the game work normally.
- One `MallocBinned2 … canary == 0x0` crash was seen once, while creating a session. It hasn't happened again.

## What's in here

| Path | What |
|---|---|
| `install.sh` | Installer: checks hashes, backs up the originals as `*.orig`, and sets up the Steam window fix |
| `files/ntdll.so` | Built from the [winecx](https://github.com/dappermint/winecx) commit `7dbc5b5` (the source of engine v4.6.4-beta.1) with the patch below applied |
| `files/kernelbase.dll` | The engine's original `kernelbase.dll` with two small hooks (see `patches/kernelbase-cave.s`): `SwitchToFiber` and `ConvertThreadToFiberEx` also publish the fiber to `gs:0x20`, and park the QoS value in `TEB+0x348` |
| `patches/winecx-7dbc5b5-fiber-qos.patch` | Source patch for `dlls/ntdll/unix/signal_x86_64.c` and an equivalent source version of the kernelbase change in `dlls/kernelbase/thread.c` |
| `patches/build-ntdll.sh` | How `files/ntdll.so` was built: Apple clang, x86_64, `MACOSX_DEPLOYMENT_TARGET=15.0` |

The same root cause also affects other games that use fibers (for example, DOOM, see `tests/fibprobe.c` in frankea/winecx-gptk), so this fix may help those games too.

## Licence

Wine is licensed under the LGPL 2.1 or later (`files/COPYING.LIB`). The modified Wine files here are distributed under the same licence, with the full source changes in `patches/`.
This project isn't affiliated with Bandai Namco, Valve, Apple, CodeWeavers or the Whisky authors.
