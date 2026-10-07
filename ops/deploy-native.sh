#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

repo=/opt/native-source
site=/var/www/native
releases="$site/releases"
current="$site/current"
host=native.mirachat.cn

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

GIT_TERMINAL_PROMPT=0 timeout 50 git -C "$repo" fetch --quiet --no-tags origin \
  '+refs/heads/main:refs/remotes/origin/main'
commit=$(git -C "$repo" rev-parse --verify 'refs/remotes/origin/main^{commit}')
release="$releases/$commit"

previous=''
if [[ -L "$current" ]]; then
  previous=$(readlink -f "$current")
  [[ "$previous" == "$releases/"* ]] || { echo 'Current release is outside release directory' >&2; exit 1; }
fi
if [[ "$previous" == "$release" ]]; then exit 0; fi

if [[ -f "$previous/version.json" ]]; then
  previous_commit=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "$previous/version.json")
  git -C "$repo" merge-base --is-ancestor "$previous_commit" "$commit" || {
    echo 'main is not a descendant of the deployed commit; refusing automatic deployment' >&2
    exit 1
  }
fi

install -d -m 755 "$releases"
if [[ ! -e "$release" ]]; then
  staging=$(mktemp -d "$releases/.staging-${commit:0:12}.XXXXXX")
  git -C "$repo" show "$commit:index.html" >"$staging/index.html"
  git -C "$repo" show "$commit:native.html" >"$staging/native.html"
  cmp -s "$staging/index.html" "$staging/native.html" || {
    echo 'HTML copies differ; refusing deployment' >&2; exit 1;
  }
  grep -qi '<!doctype html>' "$staging/index.html" || {
    echo 'HTML doctype missing; refusing deployment' >&2; exit 1;
  }
  printf '{"commit":"%s","deployed_at":"%s"}\n' "$commit" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    >"$staging/version.json"
  chmod 644 "$staging/index.html" "$staging/native.html" "$staging/version.json"
  chmod 755 "$staging"
  mv -T "$staging" "$release"
  staging=''
fi

[[ -f "$release/version.json" ]] || {
  echo 'Release version metadata is missing' >&2; exit 1;
}
chmod 755 "$release"

[[ "$(git -C "$repo" hash-object "$release/index.html")" == \
   "$(git -C "$repo" rev-parse "$commit:index.html")" ]] || {
  echo 'Release content does not match Git commit' >&2; exit 1;
}
[[ "$(git -C "$repo" hash-object "$release/native.html")" == \
   "$(git -C "$repo" rev-parse "$commit:native.html")" ]] || {
  echo 'Release mirror does not match Git commit' >&2; exit 1;
}

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
