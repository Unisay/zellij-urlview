#!/usr/bin/env bash
# zellij-urlview.sh — a tmux-urlview equivalent for zellij.
#
# Reads the visible screen of the pane that launched the picker,
# extracts every URL it can find, lets you pick one (or several) with fzf, and
# opens the selection in your browser.
#
# Usage: zellij-urlview.sh [dump-file]
# Intended to be launched in a floating pane from a zellij keybind. See README.
#
# Environment:
#   URLVIEW_OPENER   command used to open a URL (default: auto-detected —
#                      xdg-open, open, or $BROWSER)

set -u

dump="${1:-}"

cleanup() {
    [[ -n "${dump:-}" && -f "$dump" ]] && rm -f "$dump"
}
if [[ -n "$dump" ]]; then trap cleanup EXIT; fi

pause() {
    # Keep the floating pane visible long enough to read the message.
    printf '\n%s' "press any key to close…"
    read -r -n1 -s _ || true
}

# Pick the command used to open URLs.
detect_opener() {
    if [[ -n "${URLVIEW_OPENER:-}" ]]; then
        echo "$URLVIEW_OPENER"
    elif command -v xdg-open >/dev/null 2>&1; then
        echo "xdg-open"
    elif command -v open >/dev/null 2>&1; then  # macOS
        echo "open"
    elif [[ -n "${BROWSER:-}" ]]; then
        echo "$BROWSER"
    else
        echo ""
    fi
}

# Capture the originating pane inside the floating picker. An explicit dump
# path retains the older DumpScreen integration and its ownership convention.
if [[ -z "$dump" ]]; then
    screen=$(zellij action dump-screen --pane-id "${ZELLIJ_ORIGIN_PANE_ID:?missing origin pane}") || exit 1
else
    for ((i = 0; i < 40; ++i)); do
        [[ -s "$dump" ]] && break
        sleep 0.05
    done
    screen=$(cat -- "$dump") || exit 1
fi

# Extract URLs:
#  - http(s) schemes, plus bare www.* hosts
#  - strip trailing punctuation that commonly hugs URLs in prose
#  - dedupe while preserving order, then reverse so the most recently printed
#    URLs (bottom of the screen) appear first in urlview.
mapfile -t urls < <(
    # Zellij joins terminal soft wraps. Joining independent application rows
    # would risk appending unrelated screen text to a selected URL.
    grep -aoE '(https?://|www\.)[A-Za-z0-9._~:/?#@!$&'"'"'()*+,;=%-]+' <<< "$screen" \
        | sed -E 's/[].,;:!?")>'"'"']+$//' \
        | awk '!seen[$0]++' \
        | tac
)

if [[ ${#urls[@]} -eq 0 ]]; then
    echo "zellij-urlview: no URLs on screen." >&2
    pause
    exit 0
fi

# The screen can contain private links. Do not inherit preview commands,
# selection bindings or history settings from a general-purpose fzf config.
mapfile -t chosen < <(printf '%s\n' "${urls[@]}" \
    | FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' fzf --multi --no-sort --prompt='open url> ' \
          --height=100% --border --reverse \
          --header='Enter: open · Tab: multi-select · Esc: cancel')

[[ ${#chosen[@]} -eq 0 ]] && exit 0

opener="$(detect_opener)"
if [[ -z "$opener" ]]; then
    echo "zellij-urlview: no URL opener found (set URLVIEW_OPENER)." >&2
    pause
    exit 1
fi

for url in "${chosen[@]}"; do
    [[ -z "$url" ]] && continue
    # www.* hosts need a scheme for the opener to route them to the browser.
    [[ "$url" == www.* ]] && url="https://$url"
    case "$url" in
        http://*|https://*) "$opener" "$url" || { echo "Could not open the selected URL" >&2; pause; exit 1; } ;;
    esac
done
