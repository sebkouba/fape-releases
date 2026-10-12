#!/usr/bin/env bash
# Download and verify one package, then delegate to the normal Fape installer.
set -euo pipefail
[[ "$EUID" -ne 0 ]] || { printf 'Run the Fape installer as your normal user, without sudo.\n' >&2; exit 1; }
base="${FAPE_DOWNLOAD_BASE:-https://tokenschmiede.com/fape-trial}"
development_http=0
case "$base" in
  https://*) ;;
  http://127.0.0.1:*|http://localhost:*|http://10.0.2.2:*)
    [[ "${FAPE_ALLOW_HTTP:-0}" == 1 ]] || { printf 'Local HTTP testing requires FAPE_ALLOW_HTTP=1.\n' >&2; exit 1; }
    development_http=1 ;;
  *) printf 'Use HTTPS for the download server.\n' >&2; exit 1;;
esac
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { printf 'Fape currently requires x86_64 Linux with Omarchy.\n' >&2; exit 1; }
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua" ]] || { printf 'Omarchy Hyprland bindings.lua was not found.\n' >&2; exit 1; }
for tool in curl python3 unzip sha256sum; do
  command -v "$tool" >/dev/null || { printf 'Required tool missing: %s\n' "$tool" >&2; exit 1; }
done
work="$(mktemp -d -t fape-install.XXXXXXXX)"
trap 'rm -rf -- "$work"' EXIT
download() {
  local protocols='=https'
  # Only explicitly enabled local development requests may start over HTTP.
  if [[ "$development_http" == 1 && "$1" == http://* ]]; then protocols='=http,https'; fi
  curl --fail --silent --show-error --location --proto "$protocols" --proto-redir '=https' \
    --connect-timeout 15 --max-time 300 --retry 3 "$1" -o "$2"
}
printf 'Downloading Fape…\n'
download "$base/release.json" "$work/release.json"
python3 - "$work" "$base" "$development_http" <<'PYMETA'
import json, re, sys
from pathlib import Path
from urllib.parse import urlparse
root, base = Path(sys.argv[1]), sys.argv[2]
release = json.loads((root / 'release.json').read_text())
filename, digest = release['filename'], release['sha256']
if not re.fullmatch(r'fape-[A-Za-z0-9._-]+\.zip', filename) or not re.fullmatch(r'[a-f0-9]{64}', digest):
    raise SystemExit('Invalid release metadata')
url = release.get('downloadUrl', base + '/download')
parsed = urlparse(url)
if parsed.scheme != 'https' and not (sys.argv[3] == '1' and parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost', '10.0.2.2')):
    raise SystemExit('Invalid package download URL')
if any(c in url for c in '\r\n'):
    raise SystemExit('Invalid package download URL')
(root / 'checksum').write_text(f'{digest}  {filename}\n')
(root / 'filename').write_text(filename)
(root / 'url').write_text(url)
PYMETA
filename="$(cat "$work/filename")"
download "$(cat "$work/url")" "$work/$filename"
(cd "$work" && sha256sum -c checksum)
# Reject unexpected paths, symlinks and layouts before writing any archive file.
python3 - "$work/$filename" "${filename%.zip}" <<'PY'
import stat, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    seen = set()
    installer = None
    for item in archive.infolist():
        path = item.filename[:-1] if item.is_dir() else item.filename
        parts = path.split('/')
        kind = stat.S_IFMT(item.external_attr >> 16)
        if parts[0] != sys.argv[2] or any(p in ('', '.', '..') for p in parts) or kind not in (0, stat.S_IFREG, stat.S_IFDIR):
            raise SystemExit('Invalid package archive path')
        if kind == stat.S_IFDIR and not item.is_dir() or kind == stat.S_IFREG and item.is_dir():
            raise SystemExit('Invalid package archive entry type')
        if path in seen:
            raise SystemExit('Duplicate package archive path')
        seen.add(path)
        if path == sys.argv[2] + '/install.sh':
            installer = item
    if installer is None or installer.is_dir():
        raise SystemExit('Package installer must be a regular file')
PY
unzip -q "$work/$filename" -d "$work"
bash "$work/${filename%.zip}/install.sh" "$@"
