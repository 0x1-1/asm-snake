# ASM Snake

A Windows x64 console Snake game written in assembly and built with
[flat assembler](https://flatassembler.net/).

The original Irvine32/MASM prototype has been replaced with a standalone FASM
build so the game can produce a `.exe` without Visual Studio, MASM, or Irvine32.

## Features

- Windows x64 console executable generated directly from `snake.asm`
- Difficulty selection: Easy, Normal, Hard
- WASD and arrow-key movement
- Pause, restart, menu, and quit controls
- Persistent high score saved in `asm-snake.sav`
- Self, wall, and obstacle collision
- Random obstacle placement per run
- Five food types:
  - `*` apple: score and grow
  - `$` bonus: larger score and double growth
  - `+` slow: score and slower pace
  - `!` rush: score and faster pace
  - `-` trim: small score and shorter tail
- Level-based speed scaling
- Colored board, snake, food, HUD, and game-over state
- Windows GitHub Actions build workflow

## Build

From PowerShell:

```powershell
./build.ps1
```

The script looks for `fasm.exe` on `PATH`. If it is not available, it downloads
the portable Windows FASM package into `.tools/` and builds:

```text
build/asm-snake.exe
```

To require a preinstalled assembler and skip the automatic download:

```powershell
./build.ps1 -NoBootstrap
```

## Run

```powershell
./build/asm-snake.exe
```

## Controls

| Key | Action |
| --- | --- |
| `WASD` / arrows | Move |
| `P` | Pause or resume |
| `R` | Restart |
| `M` | Return to menu |
| `Q` / `Esc` | Quit |

## Repository Layout

```text
snake.asm                  Game source
build.ps1                  Local Windows build script
.github/workflows/build.yml CI build workflow
.editorconfig              Editor defaults
.gitignore                 Build and local-tool ignores
```

## Acknowledgements

This project is dedicated to Ali Kutluözen, whose love of classic games inspired
the original version.

- [YouTube](https://www.youtube.com/c/alikutluozen)
- [LinkedIn](https://www.linkedin.com/in/alikutluozen)
- [Instagram](https://www.instagram.com/alikutluozen/?hl=en)
