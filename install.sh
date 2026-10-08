#!/usr/bin/env bash
# Download and verify one package, then delegate to the normal Fape installer.
set -euo pipefail
base="${FAPE_DOWNLOAD_BASE:-https://tokenschmiede.com/fape-trial}"
case "$base" in https://*) ;; http://127.0.0.1:*|http://localhost:*|http://10.0.2.2:*) ;; *) printf 'Use HTTPS for the download server.\n' >&2; exit 1;; esac
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { printf 'Fape currently requires x86_64 Linux with Omarchy.\n' >&2; exit 1; }
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua" ]] || { printf 'Omarchy Hyprland bindings.lua was not found.\n' >&2; exit 1; }
for tool in curl python3 unzip sha256sum; do
  command -v "$tool" >/dev/null || { printf 'Required tool missing: %s\n' "$tool" >&2; exit 1; }
done
work="$(mktemp -d -t fape-install.XXXXXXXX)"
trap 'rm -rf -- "$work"' EXIT
printf 'Downloading Fape…\n'
curl --fail --silent --show-error --location "$base/release.json" -o "$work/release.json"
python3 - "$work" "$base" <<'PYMETA'
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
if parsed.scheme != 'https' and not (parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost', '10.0.2.2')):
    raise SystemExit('Invalid package download URL')
if any(c in url for c in '\r\n'):
    raise SystemExit('Invalid package download URL')
(root / 'checksum').write_text(f'{digest}  {filename}\n')
(root / 'filename').write_text(filename)
(root / 'url').write_text(url)
PYMETA
filename="$(cat "$work/filename")"
curl --fail --silent --show-error --location "$(cat "$work/url")" -o "$work/$filename"
(cd "$work" && sha256sum -c checksum)
# Reject unexpected paths, symlinks and layouts before writing any archive file.
python3 - "$work/$filename" "${filename%.zip}" <<'PY'
import stat, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    for item in archive.infolist():
        parts = item.filename.split('/')
        if parts[0] != sys.argv[2] or any(p in ('', '.', '..') for p in parts) or stat.S_ISLNK(item.external_attr >> 16):
            raise SystemExit('Invalid package archive path')
    if sys.argv[2] + '/install.sh' not in archive.namelist():
        raise SystemExit('Package installer missing')
PY
unzip -q "$work/$filename" -d "$work"
bash "$work/${filename%.zip}/install.sh" "$@"
