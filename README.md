# Nintendo Switch Video Player NSP

A minimal Nintendo Switch homebrew title that launches directly into video playback using the system's built-in offline web applet. No HTML, no redirect — the applet boots straight into `video.mp4`.

---

## How It Works

The NSP contains three NCAs:

- **Program NCA** — a minimal NSO that calls `webOfflineCreate` and hands off immediately to the system offline web applet
- **Manual NCA** — contains `video.mp4` inside the required `html-document/.htdocs/` romfs structure
- **Control NCA** — title metadata, icon, and display name

The program does nothing except configure and launch the applet:

```c
webOfflineCreate(&config, WebDocumentKind_OfflineHtmlPage, 0, ".htdocs/video.mp4");
webConfigSetBootAsMediaPlayer(&config, true);
webConfigSetMediaPlayerAutoClose(&config, true);
webConfigSetMediaPlayerUi(&config, true);
webConfigShow(&config, &reply);
```

When the video finishes, the applet exits automatically and returns to the Switch home menu.

---

## Video Requirements

| Property | Value |
|---|---|
| Container | MP4 |
| Video codec | H.264 (AVC) |
| Resolution | 1280x720 |
| Frame rate | 30fps |
| Audio codec | AAC (mp4a) |
| Audio channels | Stereo |
| Sample rate | 48000 Hz |

---

## Repository Structure

```
├── exefs/              # Compiled NSO binary (main) and main.npdm
├── logo/               # Nintendo logo assets
├── video/              # Place video.mp4 here
│   └── video.mp4
├── tools/
│   ├── hacpack         # hacpack binary (Linux, for CI)
│   ├── hacpack.exe     # hacpack binary (Windows, for local builds)
│   └── generate_control.py
├── icon.jpg            # Title icon (256x256)
├── npdm.json           # NPDM config template
├── build.bat           # Windows build script
└── keys.dat            # Required crypto keys (not included, see below)
```

---

## Building

### Configuration

All title metadata is set at the top of `build.bat` (Windows) or in the `env:` block of `.github/workflows/build.yml` (CI):

| Field | Description |
|---|---|
| `TITLE` | Display name shown on the Switch home menu |
| `AUTHOR` | Author name shown in title info |
| `DISPLAY_VER` | Display version string |
| `TITLE_ID` | Unique title ID in hex (e.g. `0400000000420000`) |
| `KEYGEN` | NCA key generation |
| `SDK_VER` | SDK version |
| `SYS_VER` | Minimum required system version |

### Keys

`keys.dat` is required and must contain valid Nintendo Switch crypto keys. It is not included in this repository. For CI builds, add it as a GitHub Actions secret named `HACPACK_KEYS`.

### Windows (local)

1. Place `video.mp4` in the `video/` folder
2. Place `keys.dat` in the repo root
3. Run `build.bat`
4. Output NSP will be in `nsp/`

### GitHub Actions (CI)

Push to `main` or trigger manually via `workflow_dispatch`. The workflow requires the following secret:

| Secret | Required | Description |
|---|---|---|
| `HACPACK_KEYS` | ✅ | Contents of `keys.dat` |
| `NCASIG2_PRIVATE_KEY` | ❌ | NCA signature key 2 |
| `ACID_PRIVATE_KEY` | ❌ | ACID signature key |
| `NCASIG1_PRIVATE_KEY` | ❌ | NCA signature key 1 |

The built NSP is uploaded as a workflow artifact.

---

## Dependencies

- [hacpack](https://github.com/The-4n/hacPack)
- [npdmtool](https://github.com/nicoboss/npdmtool) — included via `devkitpro/devkita64` Docker image in CI, or place `npdmtool.exe` in `tools/` for local Windows builds
- [libnx](https://github.com/switchbrew/libnx)
- [devkitA64](https://devkitpro.org)

---

## Notes

- Requires a hacked Nintendo Switch running custom firmware
- Title ID must be in the homebrew range (`0400000000000000`–`04000000FFFFFFFF`)
- The offline web applet used for playback is a system applet present on all Switch firmware versions — no internet connection is required
