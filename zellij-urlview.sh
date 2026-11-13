#!/usr/bin/env bash
# zellij-urlview.sh — a tmux-urlview equivalent for zellij.
#
# Reads a screen dump (produced by zellij's `DumpScreen` keybind action),
# extracts every URL it can find, lets you pick one (or several) with fzf, and
# opens the selection in your browser.
#
# Usage: zellij-urlview.sh <dump-file>
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
trap cleanup EXIT

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

# Launch a URL detached so it survives this floating pane closing.
open_url() {
    local url="$1"
    if command -v setsid >/dev/null 2>&1; then
        setsid --fork "$opener" "$url" >/dev/null 2>&1 </dev/null
    else
        nohup "$opener" "$url" >/dev/null 2>&1 </dev/null &
    fi
}

if [[ -z "$dump" ]]; then
    echo "zellij-urlview: no dump path given." >&2
    pause
    exit 1
fi

# DumpScreen runs just before this pane opens; give it a moment to finish
# writing so we don't read a missing or half-written file.
for _ in $(seq 1 40); do
    [[ -s "$dump" ]] && break
    sleep 0.05
done

if [[ ! -f "$dump" ]]; then
    echo "zellij-urlview: no screen dump found." >&2
    pause
    exit 1
fi

# Extract URLs:
#  - http(s)/ftp/file schemes, plus bare www.* hosts
#  - strip trailing punctuation that commonly hugs URLs in prose
#  - dedupe while preserving order, then reverse so the most recently printed
#    URLs (bottom of the screen) appear first in urlview.
mapfile -t urls < <(
    # zellij's DumpScreen already joins lines the *terminal* wrapped (it only
    # emits a newline before "canonical" rows).  What it cannot undo is a split
    # made by the program itself: full-screen apps such as nvim draw every row
    # explicitly and wrap their own messages a column or two short of the pane
    # width (e.g. `:!git push` output).  Reconstruct those by joining a line
    # with the next one when all of the following hold:
    #   - the line ends in the middle of a URL (URL chars run to end of line)
    #   - the line is nearly as wide as the widest line on screen (>= 90%;
    #     the app wraps a column or two short, and a statusline is wider still)
    #   - the next line starts with URL chars and is not a "word: " label
    #     (git hooks print "remote: ..." right after a URL line)
    # This is a heuristic, and author-wrapped prose can fool it ("...see
    # https://x.y/a" + "and then..."), so the unjoined line is kept as a
    # candidate too: the joined URL is listed first, the short one after it.
    width=$(awk '{ gsub(/\r/,""); if (length > max) max = length } END { print max+0 }' "$dump")
    awk -v w="$width" '
        BEGIN { url_chars = "[A-Za-z0-9._~:/?#@!$&\047()*+,;=%-]" }
        { gsub(/\r/, "") }
        NR > 1 {
            # row_len is the last physical row, not the accumulated line
            join = (w > 0 && row_len >= w * 0.9 \
                    && prev ~ ("((https?|ftp|file)://|www\\.)" url_chars "*$") \
                    && $0 ~ ("^" url_chars) \
                    && $0 !~ /^[A-Za-z]+:([ \t]|$)/)
            if (join) {
                if (!carried) printf "%s\n", prev   # keep the short form once
                prev = prev $0
                row_len = length($0)
                carried = 1
                next
            }
            printf "%s\n", prev
            carried = 0
        }
        { prev = $0; row_len = length($0) }
        END { if (NR > 0) printf "%s\n", prev }
    ' "$dump" \
        | grep -aoE '((https?|ftp|file)://|www\.)[A-Za-z0-9._~:/?#@!$&'"'"'()*+,;=%-]+' \
        | sed -E 's/[].,;:!?")>'"'"']+$//' \
        | awk '!seen[$0]++' \
        | tac
)

if [[ ${#urls[@]} -eq 0 ]]; then
    echo "zellij-urlview: no URLs on screen." >&2
    pause
    exit 0
fi

# Pick with fzf (Tab to multi-select). Fall back to urlview if fzf is absent.
if command -v fzf >/dev/null 2>&1; then
    mapfile -t chosen < <(printf '%s\n' "${urls[@]}" \
        | fzf --multi --no-sort --prompt='open url> ' \
              --height=100% --border --reverse \
              --header='Enter: open · Tab: multi-select · Esc: cancel')
elif command -v urlview >/dev/null 2>&1; then
    printf '%s\n' "${urls[@]}" | urlview
    exit 0
else
    echo "zellij-urlview: neither fzf nor urlview found." >&2
    pause
    exit 1
fi

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
    open_url "$url"
done
