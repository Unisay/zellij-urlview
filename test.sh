#!/usr/bin/env bash
set -eu
picker=$1
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cd "$tmp"
export PATH="$tmp:$PATH" URLVIEW_OPENER="$tmp/opener" ZELLIJ_ORIGIN_PANE_ID=terminal_4
cat > zellij <<'SH'
#!/usr/bin/env bash
[[ "$*" == 'action dump-screen --pane-id terminal_4' ]] || exit 1
cat sample
SH
cat > fzf <<'SH'
#!/usr/bin/env bash
[[ -z "$FZF_DEFAULT_OPTS" && -z "$FZF_DEFAULT_OPTS_FILE" ]] || exit 1
cat > candidates
[[ -z "${CANCEL:-}" ]] && cat candidates
SH
cat > opener <<'SH'
#!/usr/bin/env bash
[[ $# == 1 ]] || exit 1
printf '%s\n' "$1" >> opened
SH
sed -i "1c#!$(command -v bash)" zellij fzf opener
chmod +x zellij fzf opener
cat > sample <<'DATA'
A Markdown link: `https://example.org/doc`
Another link: www.example.org
file:///x
ftp://example.net
A literal escape: https://example.org/%60
independent-row
DATA
export FZF_DEFAULT_OPTS=ignored FZF_DEFAULT_OPTS_FILE=ignored
bash "$picker"
cat > expected <<'DATA'
https://example.org/%60
https://www.example.org
https://example.org/doc
DATA
diff -u expected opened
CANCEL=yes bash "$picker"
diff -u expected opened

cat > read-url <<'SH'
#!/usr/bin/env bash
[[ $# == 0 ]] || exit 1
IFS= read -r url || exit 1
printf '%s\n' "$url" >> from-stdin
SH
sed -i "1c#!$(command -v bash)" read-url
chmod +x read-url
URLVIEW_OPENER=false bash "$picker" --stdin-opener "$tmp/read-url"
diff -u expected from-stdin
