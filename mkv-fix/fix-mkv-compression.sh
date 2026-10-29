#!/usr/bin/env bash
# Sonarr/Radarr Custom Script: losslessly rewrites imported MKVs whose tracks are explicitly
# zlib/bzlib/lzo-compressed, which ExoPlayer (Wholphin) can't direct play.
set -u
f="${radarr_moviefile_path:-${sonarr_episodefile_path:-}}"
[[ $f == *.mkv && -f $f ]] || exit 0
command -v mkvmerge >/dev/null || { echo "mkvtoolnix missing, skipping $f" >&2; exit 0; }
# An omitted algorithm (implicit zlib) still plays; only an explicit non-3 one breaks ExoPlayer.
mkvinfo "$f" | sed -n '1,/Cluster/p' | grep -qE 'Algorithm: [012] ' || exit 0

if [[ ${1:-} != --now ]]; then
  nohup flock /tmp/mkv-fix.lock "$0" --now >> /config/mkv-fix.log 2>&1 < /dev/null &
  exit 0
fi

same() {
  jq -en --argjson a "$(mkvmerge -J "$1")" --argjson b "$(mkvmerge -J "$2")" '
    def t: [.tracks[] | [.type, .codec, .properties.language]];
    ($a | t) == ($b | t) and ($a.container.properties.duration - $b.container.properties.duration | fabs) < 1e9' >/dev/null
}

tmp="$f.decompress.tmp"
echo "$(date '+%F %T') fixing $f"
mkvmerge -q -o "$tmp" --compression -1:none "$f"
if (( $? > 1 )); then echo "FAIL mkvmerge"; rm -f "$tmp"; exit 1; fi
if mkvinfo "$tmp" | grep -q 'Content compression'; then echo "FAIL still compressed"; rm -f "$tmp"; exit 1; fi
if ! same "$f" "$tmp"; then echo "FAIL tracks/duration differ"; rm -f "$tmp"; exit 1; fi
chmod "$(stat -c %a "$f")" "$tmp"; touch -r "$f" "$tmp"
mv -f "$tmp" "$f" && echo "OK"
