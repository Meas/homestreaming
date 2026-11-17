#!/usr/bin/env python3
# Lidarr Custom Script (or `--all`): puts the album's original release date in the date tag Jellyfin
# reads, where Lidarr writes the matched edition's (often a reissue's) date instead.
import os
import sqlite3
import sys

import mutagen
from mutagen.id3 import ID3, TDRC
from mutagen.mp4 import MP4

DB = 'file:/config/lidarr.db?mode=ro'
QUERY = '''SELECT t.Path, substr(a.ReleaseDate, 1, 10) FROM TrackFiles t
           JOIN Albums a ON a.Id = t.AlbumId WHERE a.ReleaseDate IS NOT NULL'''
PATH_VARS = ('lidarr_addedtrackpaths', 'lidarr_trackfile_paths', 'lidarr_trackfile_path')


def hook_paths():
    return {p for var in PATH_VARS for p in os.environ.get(var, '').split('|') if p}


def release_dates(paths):
    rows = sqlite3.connect(DB, uri=True).execute(QUERY).fetchall()
    return [(path, date) for path, date in rows if paths is None or path in paths]


def fix_id3(audio, date):
    if str(audio.tags.get('TDRC', '')) == date:
        return False
    audio.tags.setall('TDRC', [TDRC(encoding=3, text=[date])])
    v23 = audio.tags.version[1] == 3
    if v23:
        audio.tags.update_to_v23()
    audio.save(v2_version=3 if v23 else 4)
    return True


def fix(path, date):
    audio = mutagen.File(path)
    if audio is None or audio.tags is None:
        return False
    if isinstance(audio.tags, ID3):
        return fix_id3(audio, date)
    key = '©day' if isinstance(audio, MP4) else 'date'
    if audio.tags.get(key) == [date]:
        return False
    audio.tags[key] = [date]
    if 'year' in audio.tags:
        audio.tags['year'] = [date[:4]]
    audio.save()
    return True


def main():
    paths = None if sys.argv[1:] == ['--all'] else hook_paths()
    if paths == set():
        return
    for path, date in release_dates(paths):
        try:
            if fix(path, date):
                print(f'{date} {path}')
        except (mutagen.MutagenError, OSError) as e:
            print(f'FAIL {path}: {e}', file=sys.stderr)


main()
