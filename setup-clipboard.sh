#!/bin/sh
set -e

# Install both clipboard tools (safe even if headless)
if ! command -v apk >/dev/null 2>&1; then
  echo "This script expects Alpine (apk not found)"; exit 1
fi
apk add --no-cache xclip wl-clipboard >/dev/null || true

install -d /usr/local/bin

# pbcopy: Wayland > X11 > OSC52 (terminal clipboard)
cat > /usr/local/bin/pbcopy <<'SH'
#!/bin/sh
# Wayland
if command -v wl-copy >/dev/null 2>&1 && [ -n "$WAYLAND_DISPLAY" ]; then
  exec wl-copy
fi
# X11
if command -v xclip >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
  exec xclip -selection clipboard
fi
# OSC52 (headless/SSH): copies to your *terminal* clipboard
# Most modern terminals (and tmux with set-clipboard on) support it.
data=$(cat | base64 | tr -d '\r\n')
# Try BEL terminator first, then ST as a fallback
# BEL:
printf '\033]52;c;%s\a' "$data"
# Some terminals prefer ST:
printf '\033]52;c;%s\033\\' "$data" >/dev/null 2>&1 || true
SH
chmod +x /usr/local/bin/pbcopy

# pbpaste: Wayland > X11; no portable OSC52 "paste"
cat > /usr/local/bin/pbpaste <<'SH'
#!/bin/sh
if command -v wl-paste >/dev/null 2>&1 && [ -n "$WAYLAND_DISPLAY" ]; then
  exec wl-paste
fi
if command -v xclip >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
  exec xclip -selection clipboard -o
fi
echo "pbpaste: no GUI clipboard available (no WAYLAND_DISPLAY or DISPLAY). In headless mode, paste from your terminal/host instead." >&2
exit 1
SH
chmod +x /usr/local/bin/pbpaste

echo "Installed pbcopy/pbpaste. Copy supports OSC52 when no display is available."
