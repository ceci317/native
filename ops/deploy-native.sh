#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

site=/var/www/native
releases="$site/releases"
current="$site/current"
host=native.mirachat.cn
api=https://api.github.com/repos/ceci317/native

exec 9>/run/native-deploy/lock
flock -n 9 || exit 0

staging=''
next_link=''
cleanup() {
  if [[ -n "$next_link" ]]; then rm -f -- "$next_link"; fi
  if [[ -n "$staging" && -d "$staging" ]]; then
    rm -f -- "$staging/index.html" "$staging/native.html" "$staging/version.json"
    rmdir -- "$staging"
  fi
}
trap cleanup EXIT

fetch_api() {
  curl -4 -fsS --connect-timeout 5 --max-time 12 --retry 1 --retry-delay 1 \
    -H 'Accept: application/vnd.github+json' -H 'User-Agent: native-deploy' \
    "$1" -o "$2"
}

fetch_api "$api/commits/main" /run/native-deploy/commit.json
commit=$(python3 - /run/native-deploy/commit.json <<'PY'
import json, re, sys
sha = json.load(open(sys.argv[1], encoding='utf-8'))['sha']
if not re.fullmatch(r'[0-9a-f]{40}', sha):
    raise SystemExit('Invalid GitHub commit SHA')
print(sha)
PY
)
release="$releases/$commit"

previous=''
if [[ -L "$current" ]]; then
  previous=$(readlink -f "$current")
  [[ "$previous" == "$releases/"* ]] || { echo 'Current release is outside release directory' >&2; exit 1; }
fi
if [[ "$previous" == "$release" ]]; then exit 0; fi

install -d -m 755 "$releases"
staging=$(mktemp -d "$releases/.staging-${commit:0:12}.XXXXXX")
for name in index.html native.html; do
  fetch_api "$api/contents/$name?ref=$commit" "/run/native-deploy/$name.json"
  python3 - "/run/native-deploy/$name.json" "$staging/$name" <<'PY'
import base64, hashlib, json, sys
item = json.load(open(sys.argv[1], encoding='utf-8'))
if item.get('type') != 'file' or item.get('encoding') != 'base64':
    raise SystemExit('GitHub response is not a file')
data = base64.b64decode(item['content'])
if not data or len(data) > 2_000_000:
    raise SystemExit('Site file is empty or too large')
blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
if blob != item['sha']:
    raise SystemExit('GitHub file hash mismatch')
with open(sys.argv[2], 'wb') as output:
    output.write(data)
PY
done
cmp -s "$staging/index.html" "$staging/native.html" || {
  echo 'HTML copies differ; refusing deployment' >&2; exit 1;
}
grep -qi '<!doctype html>' "$staging/index.html" || {
  echo 'HTML doctype missing; refusing deployment' >&2; exit 1;
}
if [[ ! -e "$release" ]]; then
  printf '{"commit":"%s","deployed_at":"%s"}\n' "$commit" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >"$staging/version.json"
  chmod 644 "$staging/index.html" "$staging/native.html" "$staging/version.json"
  chmod 755 "$staging"
  mv -T "$staging" "$release"
  staging=''
else
  cmp -s "$staging/index.html" "$release/index.html" || {
    echo 'Existing release content differs from GitHub' >&2; exit 1;
  }
  cmp -s "$staging/native.html" "$release/native.html" || {
    echo 'Existing release mirror differs from GitHub' >&2; exit 1;
  }
fi

[[ -f "$release/version.json" ]] || {
  echo 'Release version metadata is missing' >&2; exit 1;
}
chmod 755 "$release"

next_link="$site/.current-next-$$"
ln -s "$release" "$next_link"
mv -Tf "$next_link" "$current"
next_link=''

if ! curl -fsS --max-time 8 --resolve "$host:443:127.0.0.1" \
    "https://$host/version.json" | grep -Fq "\"commit\":\"$commit\"" || \
   ! curl -fsS --max-time 8 --resolve "$host:443:127.0.0.1" \
    "https://$host/" -o /dev/null; then
  echo 'Health check failed; restoring previous release' >&2
  if [[ -n "$previous" ]]; then
    next_link="$site/.current-rollback-$$"
    ln -s "$previous" "$next_link"
    mv -Tf "$next_link" "$current"
    next_link=''
  fi
  exit 1
fi

echo "Deployed $commit"
