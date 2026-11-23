# Zellij-urlview

> Press a key, fuzzy-pick any URL on your screen, and open it in your browser — without touching the mouse.

`Zellij-urlview` is a small, dependency-light recreation of the much-loved
[`tmux-urlview`](https://github.com/tmux-plugins/tmux-urlview) workflow for
[zellij](https://zellij.dev/). It grabs the text currently on your pane, finds
every URL in it, drops them into an `fzf` menu, and opens whatever you select.

```
┌─ zellij-urlview ───────────────────────────────────────────┐
│ open url> rust                                             │
│ Enter: open · Tab: multi-select · Esc: cancel              │
│ > https://www.rust-lang.org                                │
│   https://github.com/zellij-org/zellij                     │
│   https://example.com/path?q=1                             │
└────────────────────────────────────────────────────────────┘
```

---

## Background: `tmux-urlview`

This project is a direct homage to
**[tmux-plugins/tmux-urlview](https://github.com/tmux-plugins/tmux-urlview)** —
the tmux plugin that lets you "quickly open any url on your terminal window."
Its workflow is exactly the one this project recreates for zellij:

- It binds a key (default **`u`**, configurable via `@urlview-key`) that runs
  tmux's [`capture-pane`](https://man.openbsd.org/tmux#capture-pane) — with the
  `-J` flag to join wrapped lines — to grab the pane's text.
- It pipes that capture into a URL extractor —
  [`urlview`](https://github.com/sigpipe/urlview) or
  [`extract_url`](https://github.com/n1trux/extract_url) — which presents a menu
  of every link found.
- You pick one, and it opens.

That tiny "capture → extract → pick → open" pipeline became muscle memory for a
lot of terminal users. This fork reads the originating pane with the Zellij CLI.

### References & see also

- [tmux-plugins/tmux-urlview](https://github.com/tmux-plugins/tmux-urlview) — the original tmux plugin this is modelled on.
- [urlview](https://github.com/sigpipe/urlview) — the classic URL extractor (long shipped alongside mutt).
- [firecat53/urlscan](https://github.com/firecat53/urlscan) — a modern `urlview` alternative that keeps surrounding context.
- [wfxr/tmux-fzf-url](https://github.com/wfxr/tmux-fzf-url) — an `fzf`-based take on the same workflow for tmux.
- [tmux-plugins/tmux-open](https://github.com/tmux-plugins/tmux-open) — open highlighted selections (incl. URLs) from copy-mode.

---

## How it works

On Zellij 0.46 or newer, the floating picker receives the originating pane ID.
It reads that pane’s visible text with `zellij action dump-screen`, extracts web
links, and passes each selection to the opener as a single argument. The default
binding needs no shared dump file. Only the selected links go to the opener.

## Installation with Nix

Install the package with `nix profile add github:Unisay/zellij-urlview`, or add
the flake as an input and include `inputs.zellij-urlview.packages.${pkgs.stdenv.hostPlatform.system}.default`
in your packages. The package supplies Bash, fzf and the text utilities. The
Zellij CLI and a browser opener must be available at runtime.

Add this to your Zellij configuration:

```kdl
keybinds {
    shared_except "locked" {
        bind "Alt u" {
            Run "zellij-urlview" {
                floating true
                close_on_exit true
                name "zellij-urlview"
            };
        }
    }
}
```

For installation without Nix, put `zellij-urlview.sh` on PATH as
`zellij-urlview`. Use Bash 4+, fzf and GNU coreutils (including `tac`).
The optional legacy argument is a dump file that the picker deletes on exit.
Supply only a private file created for this invocation.

## Usage

- **`Alt u`** (or whatever you bound) — open urlview.
- **Type** to fuzzy-filter.
- **Enter** — open the highlighted URL.
- **Tab** — multi-select; Enter then opens all selected URLs.
- **Esc** — cancel.

URLs are de-duplicated and listed most-recent-first (bottom of the screen
first), since the link you just saw is usually the one you want.

### Configuration

Set `URLVIEW_OPENER` if you want a specific opener instead of the
auto-detected one (`xdg-open` → `open` → `$BROWSER`):

```sh
export URLVIEW_OPENER=firefox
```

---

## Limitations

- `DumpScreen` captures the **visible viewport**, not the full scrollback —
  same as a default `tmux capture-pane`. Scroll up before opening urlview to
  reach older links.
- URL detection is regex-based and pragmatic; it favours the common cases
  (http/https and `www.` hosts) over RFC-perfect completeness.

---

## Contributing

Contributions are very welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Bug reports, regex improvements, and portability fixes for other shells/OSes
are all appreciated.

---

## License

[MIT](LICENSE) — do whatever you like, just keep the notice.

## Acknowledgements

Standing entirely on the shoulders of
[`tmux-urlview`](https://github.com/tmux-plugins/tmux-urlview) and the broader
[`urlview`](https://github.com/sigpipe/urlview) /
