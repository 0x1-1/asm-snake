import argparse
import os
import sys
import time
from pathlib import Path

try:
    from winpty import PtyProcess
except ImportError as exc:
    raise SystemExit("pywinpty is required: python -m pip install pywinpty") from exc

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:
    raise SystemExit("Pillow is required: python -m pip install pillow") from exc


WIDTH = 100
HEIGHT = 30


def run_game(exe: Path, timeout: float) -> tuple[int, str]:
    env = os.environ.copy()
    env["ASM_SNAKE_SMOKE"] = "1"

    proc = PtyProcess.spawn([str(exe)], cwd=str(exe.parent.parent), env=env, dimensions=(HEIGHT, WIDTH))
    output: list[str] = []
    started = time.time()

    while time.time() - started < timeout:
        try:
            chunk = proc.read(4096)
            if chunk:
                output.append(chunk)
        except Exception:
            pass

        if not proc.isalive():
            break

        time.sleep(0.05)

    if proc.isalive():
        proc.kill()
        raise SystemExit(f"Smoke test timed out after {timeout:.1f}s")

    try:
        proc.wait()
    except Exception:
        pass

    exit_code = proc.exitstatus if proc.exitstatus is not None else 0
    return exit_code, "".join(output)


def parse_terminal(stream: str) -> list[str]:
    screen = [[" " for _ in range(WIDTH)] for _ in range(HEIGHT)]
    row = 0
    col = 0
    i = 0

    while i < len(stream):
        ch = stream[i]

        if ch == "\x1b":
            if i + 1 >= len(stream):
                break

            marker = stream[i + 1]
            if marker == "[":
                end = i + 2
                while end < len(stream) and not ("@" <= stream[end] <= "~"):
                    end += 1
                if end >= len(stream):
                    break

                params = stream[i + 2 : end]
                command = stream[end]

                if command in ("H", "f"):
                    cleaned = params.replace("?", "")
                    parts = cleaned.split(";") if cleaned else []
                    try:
                        row = max(0, min(HEIGHT - 1, int(parts[0] or "1") - 1)) if len(parts) >= 1 else 0
                        col = max(0, min(WIDTH - 1, int(parts[1] or "1") - 1)) if len(parts) >= 2 else 0
                    except ValueError:
                        row = 0
                        col = 0
                elif command == "J" and params.endswith("2"):
                    screen = [[" " for _ in range(WIDTH)] for _ in range(HEIGHT)]
                    row = 0
                    col = 0
                elif command == "K":
                    for x in range(col, WIDTH):
                        screen[row][x] = " "
                elif command in ("A", "B", "C", "D"):
                    try:
                        amount = int(params or "1")
                    except ValueError:
                        amount = 1

                    if command == "A":
                        row = max(0, row - amount)
                    elif command == "B":
                        row = min(HEIGHT - 1, row + amount)
                    elif command == "C":
                        col = min(WIDTH - 1, col + amount)
                    else:
                        col = max(0, col - amount)
                elif command == "G":
                    try:
                        col = max(0, min(WIDTH - 1, int(params or "1") - 1))
                    except ValueError:
                        col = 0

                i = end + 1
                continue

            if marker == "]":
                end = stream.find("\x07", i + 2)
                i = len(stream) if end == -1 else end + 1
                continue

            i += 2
            continue

        if ch == "\r":
            col = 0
        elif ch == "\n":
            row = min(HEIGHT - 1, row + 1)
        elif ch >= " ":
            if row < HEIGHT and col < WIDTH:
                screen[row][col] = ch if ord(ch) < 127 else " "
            col += 1
            if col >= WIDTH:
                col = 0
                row = min(HEIGHT - 1, row + 1)

        i += 1

    return ["".join(line).rstrip() for line in screen]


def render_png(lines: list[str], path: Path) -> None:
    try:
        font = ImageFont.truetype("consola.ttf", 16)
    except OSError:
        font = ImageFont.load_default()

    line_height = 19
    char_width = 10
    padding = 14
    image = Image.new("RGB", (WIDTH * char_width + padding * 2, HEIGHT * line_height + padding * 2), (12, 14, 18))
    draw = ImageDraw.Draw(image)

    y = padding
    for line in lines:
        draw.text((padding, y), line, fill=(220, 230, 240), font=font)
        y += line_height

    image.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the ASM Snake smoke mode and capture its screen.")
    parser.add_argument("--exe", default="build/asm-snake.exe", help="Path to the built executable.")
    parser.add_argument("--out-dir", default="artifacts", help="Directory for smoke test artifacts.")
    parser.add_argument("--timeout", type=float, default=10.0, help="Maximum runtime in seconds.")
    parser.add_argument("--strict-screen", action="store_true", help="Fail if the parsed screen misses expected HUD content.")
    args = parser.parse_args()

    exe = Path(args.exe).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if not exe.exists():
        raise SystemExit(f"Executable not found: {exe}")

    exit_code, raw_output = run_game(exe, args.timeout)
    lines = parse_terminal(raw_output)
    screen_text = "\n".join(lines).rstrip() + "\n"

    txt_path = out_dir / "smoke-screen.txt"
    png_path = out_dir / "smoke-screen.png"
    raw_path = out_dir / "smoke-raw.log"

    raw_path.write_text(raw_output, encoding="utf-8", errors="replace")
    txt_path.write_text(screen_text, encoding="utf-8")
    render_png(lines, png_path)

    checks = ["Score:", "Controls", "@", "####"]
    missing = [text for text in checks if text not in screen_text]

    if exit_code != 0:
        raise SystemExit(f"Smoke mode exited with code {exit_code}")

    if len(raw_output) < 100:
        raise SystemExit("Smoke mode produced too little terminal output to capture a screen.")

    if missing and args.strict_screen:
        raise SystemExit(f"Smoke screen missing expected content: {', '.join(missing)}")
    if missing:
        print(f"Smoke screen warning: missing expected content: {', '.join(missing)}")

    if "GAME OVER" in screen_text and args.strict_screen:
        raise SystemExit("Smoke mode reached game-over state unexpectedly.")

    print(f"Smoke screen text: {txt_path}")
    print(f"Smoke screen image: {png_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
