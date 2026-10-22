#!/bin/sh
# package.sh <plugin dir> <base> <url prefix> [repo] [commit]: builds the plugin's image FROM <base>
# (a released base image, exactly as the store's bases.json lists it), saves it as one archive and
# writes dist/plugin.json with that layer's URL, SHA-256 and size filled in. The release workflow runs
# this at a tag; locally, point <url prefix> at a test store (http://127.0.0.1:<port>/...).
# PROXY= sets a download proxy for the build.
set -e
[ "$#" -ge 3 ] && [ "$#" -le 5 ] || { echo "usage: package.sh <plugin dir> <base> <url prefix> [repo] [commit]" >&2; exit 2; }
dir=$1 base=$2 prefix=$3 repo=${4:-local} commit=${5:-local}
[ -f "$dir/plugin.json" ] && [ -n "$prefix" ] || { echo "usage: package.sh <plugin dir> <base> <url prefix> [repo] [commit]"; exit 2; }
id=$(python3 - "$dir/plugin.json" "$base" <<'PY'
import json, re, sys
m = json.load(open(sys.argv[1]))
for field in ("id", "version"):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,63}", m[field]):
        sys.exit(f"{field} must be 1–64 letters, digits, dots or hyphens, starting with a letter or digit")
if not re.fullmatch(r"(?:base(?:-cli|-gui)?|[a-z0-9./:_-]+/[a-z0-9._-]+)@sha256:[0-9a-f]{64}", sys.argv[2]):
    sys.exit("base must be a released image pinned by SHA-256; replace the placeholder in base.txt")
print(m["id"] + "-" + m["version"])
PY
)
mkdir -p dist
# A registry digest is the FROM as is; a local base (`base-cli@sha256:<image id>`, sandbox's
# Scripts/build-images.sh) is its v2mac/ tag, checked to be that very image.
case "$base" in
*/*) from=$base ;;
*) from=v2mac/${base%@*}
   [ "$(docker image inspect --format '{{.Id}}' "$from")" = "${base#*@}" ] || { echo "$from is not $base"; exit 1; } ;;
esac
image=v2mac-plugin/$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')
docker build --pull=false --platform linux/arm64 ${PROXY:+--build-arg http_proxy=$PROXY --build-arg https_proxy=$PROXY} --build-arg BASE="$from" -f "$dir/Containerfile" -t "$image" "$dir"
docker save "$image" -o "dist/$id.tar"
python3 - "$dir/plugin.json" "dist/$id.tar" "$base" "$prefix" "$repo" "$commit" <<'PY'
import hashlib, json, os, sys
src, tar, base, prefix, repo, commit = sys.argv[1:]
m = json.load(open(src))
h = hashlib.sha256()
with open(tar, "rb") as f:
    while chunk := f.read(1 << 20): h.update(chunk)
m["from"] = base
m["source"] = {"repo": repo, "commit": commit}
m["layers"] = [{"url": prefix.rstrip("/") + "/" + os.path.basename(tar), "sha256": h.hexdigest(), "size": os.path.getsize(tar)}]
json.dump(m, open("dist/plugin.json", "w"), indent=1, ensure_ascii=False)
print("dist/plugin.json:", m["id"], m["version"], m["layers"][0]["sha256"])
PY
