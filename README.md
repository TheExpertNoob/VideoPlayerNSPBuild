# Nintendo Switch Video Player NSP

A minimal Nintendo Switch homebrew title that launches directly into video playback using the system's built-in offline web applet.
Build process choses the binary to use to either boot into `index.html` for tv series, or multiple videos; OR `video.mp4` for single videos.

---

## How It Works

The NSP contains three NCAs:

- **Program NCA** — a minimal NSO that calls `webOfflineCreate` and hands off immediately to the system offline web applet.
- **Manual NCA** — contains `index.html` with aditional videos or `video.mp4` inside the required `html-document/.htdocs/` romfs structure.
- **Control NCA** — title metadata, icon, and display name.

The program does nothing except configure and launch the applet:

```c
webOfflineCreate(&config, WebDocumentKind_OfflineHtmlPage, 0, ".htdocs/index.html");
webConfigSetMediaPlayerUi(&config, true);
webConfigShow(&config, &reply);
```
OR

```c
webOfflineCreate(&config, WebDocumentKind_OfflineHtmlPage, 0, ".htdocs/video.mp4");
webConfigSetBootAsMediaPlayer(&config, true);
webConfigSetMediaPlayerAutoClose(&config, true);
webConfigSetMediaPlayerUi(&config, true);
webConfigShow(&config, &reply);
```

When the video finishes, the applet exits automatically and returns to the Switch home menu.

When using `index.html`, exiting the video acts as a normal web-applet and returns to the index page.

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
├── logo/               # Nintendo logo assets
├── video/              # Place index.html with videos OR video.mp4 here
│   └── video.mp4
├── tools/
│   ├── hacpack         # hacpack binary (Linux, for CI)
│   ├── hacpack.exe     # hacpack binary (Windows, for local builds)
│   ├── npdmtool.exe    # tool for building the main.npdm
│   └── generate_control.py
├── icon.jpg            # Title icon (256x256)
├── npdm.json           # NPDM config template
├── build.bat           # Windows build script
└── keys.dat            # Required crypto keys (not included, see below)
```

---

## Building

### Configuration

All title metadata is set at the top of `build.bat` (Windows) OR in the `env:` block of `.github/workflows/build.yml` (CI):

| Field | Description |
|---|---|
| `TITLE` | Display name shown on the Switch home menu |
| `AUTHOR` | Author name shown in title info |
| `DISPLAY_VER` | Display version string |
| `TITLE_ID` | Unique title ID in hex (e.g. `0400000000400000`) |
| `KEYGEN` | NCA key generation |
| `SDK_VER` | SDK version |
| `SYS_VER` | Minimum required system version |

### Keys

`keys.dat` is required and must contain valid Nintendo Switch crypto keys. It is not included in this repository. For CI builds, add it as a GitHub Actions secret named `HACPACK_KEYS`.

### Windows (local)

1. Place `index.html` with videos OR `video.mp4` in the `video/` folder
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

- [hacpack](https://github.com/The-4n/hacPack) — included in `tools/` folder for both windows and linux
- [npdmtool](https://github.com/nicoboss/npdmtool) — included via `devkitpro/devkita64` Docker image in CI, or place `npdmtool.exe` in `tools/` for local Windows builds

---

## Notes

- Requires a hacked Nintendo Switch running custom firmware
- **Title ID ranges:**
  - `010000000000XXXX` — Nintendo system titles and applets, do not use
  - `0100XXXXXXXXXXXX0000` — Switch 1 retail games (eShop titles)
  - `0400XXXXXXXXXXXX0000` — Switch 2 retail games, avoid on Switch 1 CFW if possible
  - `05XXXXXXXXXXXXXX0000` — Community homebrew convention, safe to use
- Title IDs must end in `Y000` where Y is an **even** hex digit for a base application
  - `0x800` bitmask set = update title for the same base ID
  - Odd Y digit = DLC
- On Switch 1 CFW, using a `0400` prefix like `0400000000420000` works in practice
  since the console has no Switch 2 titles to conflict with, but `05XXXXXXXXXXXXXX0000`
  is the correct homebrew-safe range
- Other ranges (`0200`, `0300`, `0600`–`0F00`) are undocumented and likely reserved
- Title IDs within the homebrew range should still be checked against the community
  registry at https://wiki.gbatemp.net/wiki/List_of_Switch_homebrew_titleID to avoid
  conflicts with other released homebrew
- The offline web applet used for playback is a system applet present on all Switch firmware versions — no internet connection is required
