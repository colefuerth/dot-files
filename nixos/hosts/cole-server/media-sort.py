"""Copy finished torrents from /watch into the Jellyfin libraries, named the way
FileBot AMC named them (TMDB names, same formats) so new episodes land in the
existing folders. Unsure matches are logged and left for a human, not guessed.
Sonarr/Radarr's imports (STAGING) are sorted the same way, as hardlinks, with
the show or movie taken from the TMDB/TVDB id in their folder names.

media-sort [--dry-run | --self-test]"""

import errno
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from guessit import guessit

WATCH = Path("/watch")
OUT = Path("/HDD4TB")
TMP = OUT / ".media-sort"  # archives are unpacked here, never into the seeding dir
# Sonarr/Radarr's root folders, hardlinks of their seeding downloads: in folders
# named "<Title> (<Year>) [tmdbid-N] [tvdbid-N]", on the libraries' mounts
STAGING = {"TV/.sonarr": "episode", "Movies/.radarr": "movie"}
DRY = "--dry-run" in sys.argv
VIDEO = {".mkv", ".mp4", ".avi", ".m4v", ".ts", ".wmv"}
SUBS = {".srt", ".ass", ".ssa"}
MIN_SIZE = 50 * 2**20  # smaller videos are samples and extras


def tmdb(path, **q):
    key = Path(os.environ["CREDENTIALS_DIRECTORY"], "tmdb").read_text().strip()
    url = f"https://api.themoviedb.org/3/{path}?" + urllib.parse.urlencode({**q, "language": "en-US", "api_key": key})
    with urllib.request.urlopen(url, timeout=30) as r:  # never log url (the key); urllib's errors leave it out
        return json.load(r)


def clean(s):
    # FileBot's rules: "/" becomes a space, \:*?"<>| and control characters go
    # ("Frieren: Beyond Journey's End" -> "Frieren Beyond Journey's End"), no
    # leading/trailing dots; and stay under ext4's 255-byte name limit
    s = re.sub(r'[\\:*?"<>|\x00-\x1f\x7f]', "", re.sub(r"\s*/+\s*|\s+", " ", s))
    return re.sub(" +", " ", s).encode()[:240].decode(errors="ignore").strip(" .")


def folder(parent, name):
    # reuse a folder that differs only in case/punctuation ("JUJUTSU KAISEN",
    # "Demon Slayer - Kimetsu no Yaiba") instead of starting a second one
    key = re.sub(r"\W", "", name).lower()
    if (parent / name).is_dir() or not key:
        return name
    same = (d.name for d in sorted(parent.iterdir()) if d.is_dir() and re.sub(r"\W", "", d.name).lower() == key)
    return next(same, name)


def target(rel, suffix, kind=None):
    """Library path for the video at <root>/<rel>, or None when unsure. kind is
    set for STAGING: its "episode"/"movie", and the ids in rel pick the TMDB entry."""
    g = guessit(re.sub(r"(?i)(E\d+)v\d\b", r"\1", rel), {"type": kind} if kind else None)  # S01E13v2
    if g.get("season") is not None and g.get("season") == g.get("year"):
        del g["season"]  # "Fruits Basket (2019) - 10"
    title, year = g.get("title"), g.get("year")
    tmdb_id, tvdb_id = (g.get("tmdb_id"), g.get("tvdb_id")) if kind else (None, None)
    if not (title or tmdb_id or tvdb_id):
        return None
    if g.get("type") == "movie":
        if tmdb_id:
            hits = [tmdb(f"movie/{tmdb_id}")]
        elif year:
            hits = tmdb("search/movie", query=title, year=year)["results"]
        else:
            return None  # remakes share titles: without the year it's a guess
        if not hits or not hits[0].get("release_date"):
            return None
        name = folder(OUT / "Movies", clean(f"{hits[0]['title']} ({hits[0]['release_date'][:4]})"))
        return OUT / "Movies" / name / (name + suffix)
    s, e = g.get("season", 1), g.get("episode")
    if not isinstance(s, int) or not isinstance(e, int):
        return None  # a season or several episodes in one file
    if tmdb_id:
        hits = [tmdb(f"tv/{tmdb_id}")]
    elif tvdb_id:  # Sonarr knows no TMDB id for the show
        hits = tmdb(f"find/{tvdb_id}", external_source="tvdb_id")["tv_results"]
    else:
        hits = tmdb("search/tv", query=title, **({"first_air_date_year": year} if year else {}))["results"]
    if not hits:
        return None
    try:
        ep = tmdb(f"tv/{hits[0]['id']}/season/{s}/episode/{e}")
    except urllib.error.HTTPError as err:
        if err.code != 404:
            raise
        return None  # numbered differently on TMDB (JJK "S02E10" is TMDB 1x34)
    show = folder(OUT / "TV", clean(hits[0]["name"]))
    if not show:
        return None
    season, num = OUT / "TV" / show / f"Season {s}", f"{show} {s}x{e:02d} - "
    # already sorted under an older TMDB episode title: the same episode, not a new file
    old = next((p for p in sorted(season.glob("*")) if p.name.startswith(num) and p.suffix.lower() in VIDEO), None)
    return old or season / (clean(num + ep["name"]) + suffix)


def subtitle(f, movie):
    """The release's English subtitle for video f: <stem>.eng.srt next to it,
    Subs/<stem>/2_English.srt (TV packs) or Subs/2_English.srt (movies)."""
    found = [s for s in f.parent.iterdir() if s.name.startswith(f.stem + ".")]
    found += (f.parent / "Subs" / f.stem).glob("*")
    found += (f.parent / "Subs").glob("*") if movie else []
    english = re.compile(r"(?i)(?<![a-z])(en|eng|english)$")
    return next((s for s in sorted(found) if s.suffix.lower() in SUBS and english.search(s.stem)), None)


def place(src, dst, link=False):
    if dst.exists():
        print(f"[EXISTS] {dst}")
        return
    print(f"[{'LINK' if link else 'COPY'}] {src} -> {dst}")
    if DRY:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if link:
        try:
            return os.link(src, dst)  # one more name for the seeding file: no space, never half a file
        except OSError as e:
            if e.errno != errno.EXDEV:
                raise
            print(f"[COPY] not on one mount, copying instead: {src}")
    # copy under a hidden name, then rename (atomic): Jellyfin never sees half a file
    part = dst.with_name(f".{dst.name}.part")
    try:
        shutil.copyfile(src, part)
    except BaseException:
        part.unlink(missing_ok=True)  # don't leave gigabytes behind on a full disk
        raise
    part.replace(dst)


def handle(f, rel, kind=None):
    """Place one video and its English subtitle; False when left for a human."""
    sample = re.search(r"(?i)\bsample", f.name) or f.parent.name.lower() in ("sample", "samples")
    if sample or f.stat().st_size < MIN_SIZE:
        print(f"[SKIP] sample or extra: {rel}")
        return True
    dst = target(rel, f.suffix.lower(), kind)
    if not dst:
        print(f"[HUMAN] no confident match, left for a human: {rel}")
        return False
    place(f, dst, bool(kind))
    sub = subtitle(f, dst.parent.parent == OUT / "Movies")
    if sub:
        place(sub, dst.with_suffix(sub.suffix.lower()), bool(kind))
    return True


def first_volume(name):
    m = re.search(r"\.part(\d+)\.rar$", name.lower())
    return name.lower().endswith(".rar") and (not m or int(m.group(1)) == 1)


def unpack(f, rel):
    if DRY:
        print(f"[UNPACK] not in a dry run: {rel}")
        return True
    with tempfile.TemporaryDirectory(dir=TMP) as x:
        try:
            subprocess.run(["7zz", "x", "-y", f"-o{x}", str(f)], check=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            print(f"[HUMAN] 7zz failed (password? corrupt?), left for a human: {rel}")
            return False
        vids = [v for v in sorted(Path(x).rglob("*")) if v.suffix.lower() in VIDEO and v.is_file() and not v.is_symlink()]
        ok = bool(vids) and all([handle(v, str(rel.parent / v.relative_to(x))) for v in vids])
        if not ok:  # name the archive: it, not what came out of it, goes on the done list
            print(f"[HUMAN] archive not fully sorted, left for a human: {rel}")
        return ok


def main():
    """Sort every new file; True when something failed (it is retried next run)."""
    done_list = Path(os.environ["DONE_LIST"])  # FileBot's exclude list: /watch/... paths, then STAGING's
    done = set(done_list.read_text().splitlines())
    failed = False
    # never .torrents: Sonarr/Radarr decide what in there is the requested file
    files = [(f, WATCH, None) for f in sorted(WATCH.rglob("*"))]
    files += [(f, OUT / d, kind) for d, kind in STAGING.items() for f in sorted((OUT / d).rglob("*"))]
    for f, root, kind in files:
        if str(f) in done or f.is_symlink() or not f.is_file():
            continue
        rel = f.relative_to(root)
        try:
            if f.suffix.lower() in VIDEO:
                ok = handle(f, str(rel), kind)
            elif first_volume(f.name):
                ok = unpack(f, rel)
            else:
                continue
        except Exception as e:  # TMDB down or rate-limited, disk full: not marked done
            print(f"[ERROR] {rel}: {e!r}")
            failed = True
            continue
        if ok and not DRY:
            with done_list.open("a") as d:
                d.write(f"{f}\n")
    return failed


def self_test():
    """Offline check with a fake TMDB: parsing, naming, folder reuse, samples, subs."""
    global WATCH, OUT, tmdb
    answers = {
        ("search/tv", "Cyberpunk Edgerunners"): {"results": [{"id": 1, "name": "Cyberpunk: Edgerunners"}]},
        ("tv/1/season/2/episode/3", None): {"name": "0 + 2 = 1"},
        ("search/tv", "Jujutsu Kaisen"): {"results": [{"id": 2, "name": "Jujutsu Kaisen"}]},
        ("tv/2/season/1/episode/5", None): {"name": "Fearsome Womb"},
        ("search/movie", "Face Off"): {"results": [{"title": "Face/Off", "release_date": "1997-06-27"}]},
    }

    def fake(path, **q):
        if (path, q.get("query")) not in answers:
            raise urllib.error.HTTPError(path, 404, "Not Found", None, None)
        return answers[path, q.get("query")]

    tmdb = fake
    assert clean(' Face/Off: "Re"\t<cut>?. ') == "Face Off Re cut"
    assert first_volume("a.part01.rar") and first_volume("a.rar") and not first_volume("a.part2.rar")
    with tempfile.TemporaryDirectory() as t:
        WATCH, OUT = Path(t, "watch"), Path(t, "out")
        for d in ["TV/Cyberpunk - Edgerunners", "TV/Cyberpunk Edgerunners", "TV/JUJUTSU KAISEN", "Movies"]:
            (OUT / d).mkdir(parents=True)
        tv = OUT / "TV"
        # exact name beats a look-alike; case-only difference reuses the folder
        assert target("Cyberpunk.Edgerunners.S02E03.0.21.2160p.NF.WEB-DL.DDP5.1.HEVC-NTb.mkv", ".mkv") == tv / "Cyberpunk Edgerunners/Season 2/Cyberpunk Edgerunners 2x03 - 0 + 2 = 1.mkv"
        old = tv / "Cyberpunk Edgerunners/Season 2/Cyberpunk Edgerunners 2x03 - 0+2=1.mp4"  # TMDB's title since
        old.parent.mkdir()
        old.touch()
        assert target("Cyberpunk.Edgerunners.S02E03.0.21.2160p.NF.WEB-DL.DDP5.1.HEVC-NTb.mkv", ".mkv") == old
        old.unlink()
        assert target("[SubsPlease] Jujutsu Kaisen - 05 (1080p) [F02B9CEE].mkv", ".mkv") == tv / "JUJUTSU KAISEN/Season 1/JUJUTSU KAISEN 1x05 - Fearsome Womb.mkv"
        assert target("Jujutsu.Kaisen.S02E10.1080p.WEB.H264.mkv", ".mkv") is None  # not on TMDB
        assert target("Face.Off.1080p.BluRay.x264.mkv", ".mkv") is None  # no year
        rel = "Face.Off.1997.1080p.BluRay.x264-GRP"
        # (a sample that got through would fail the run: "Heat" isn't in the fake TMDB)
        files = [f"{rel}/{rel}.mkv", "Heat.1995/Sample/heat.1995.mkv", "Heat.1995/heat.1995.sample.mkv", f"{rel}/Subs/1_French.srt", f"{rel}/Subs/2_English.srt", "Mystery.mkv"]
        for p in files:
            (WATCH / p).parent.mkdir(parents=True, exist_ok=True)
            (WATCH / p).write_text(p)
            if p.endswith(".mkv"):
                os.truncate(WATCH / p, MIN_SIZE)  # sparse
        os.environ["DONE_LIST"] = str(Path(t, "done.txt"))
        Path(t, "done.txt").touch()
        assert not main()
        movie = OUT / "Movies/Face Off (1997)/Face Off (1997)"
        assert sorted(OUT.rglob("*.*")) == [movie.with_suffix(".mkv"), movie.with_suffix(".srt")]
        assert movie.with_suffix(".srt").read_text().endswith("2_English.srt")
        assert Path(t, "done.txt").read_text().splitlines() == [str(WATCH / p) for p in files[:3]]
        assert not main() and len(Path(t, "done.txt").read_text().splitlines()) == 3  # done stays done

        # STAGING: the id in Sonarr/Radarr's folder name picks the show or movie
        # (their titles are wrong here on purpose; JJK has only a TVDB id), the
        # library gets a hardlink, and .torrents is never read
        answers |= {
            ("tv/1", None): {"id": 1, "name": "Cyberpunk: Edgerunners"},
            ("find/9", None): {"tv_results": [{"id": 2, "name": "Jujutsu Kaisen"}]},
            ("movie/8", None): {"title": "Heat", "release_date": "1995-12-15"},
        }
        staged = [
            "TV/.sonarr/Wrong (2020) [tmdbid-] [tvdbid-9]/Season 1/Wrong (2020) - S01E05 - Ryomen Sukuna.mkv",
            "TV/.sonarr/Wrong (2022) [tmdbid-1] [tvdbid-5]/Season 2/Wrong (2022) - S02E03 - 0 + 2 = 1.mkv",
            "Movies/.radarr/Wrong (1995) [tmdbid-8]/Wrong (1995).mkv",
        ]
        torrent = OUT / "TV/.torrents/Cyberpunk.Edgerunners.S02E03.2160p.mkv"
        torrent.parent.mkdir()
        torrent.write_text("x")
        os.truncate(torrent, MIN_SIZE)
        for p in staged:
            (OUT / p).parent.mkdir(parents=True)
            (OUT / p).write_text(p)
            os.truncate(OUT / p, MIN_SIZE)
        (OUT / staged[1]).unlink()
        os.link(torrent, OUT / staged[1])  # how Sonarr imports
        assert not main()
        library = [
            tv / "JUJUTSU KAISEN/Season 1/JUJUTSU KAISEN 1x05 - Fearsome Womb.mkv",
            tv / "Cyberpunk Edgerunners/Season 2/Cyberpunk Edgerunners 2x03 - 0 + 2 = 1.mkv",
            OUT / "Movies/Heat (1995)/Heat (1995).mkv",
        ]
        assert [(OUT / p).stat().st_ino for p in staged] == [p.stat().st_ino for p in library]
        assert torrent.stat().st_nlink == 3  # torrent, staging, library: one file
        assert Path(t, "done.txt").read_text().splitlines()[3:] == [str(OUT / p) for p in staged]
        assert not main() and len(Path(t, "done.txt").read_text().splitlines()) == 6

        def exdev(*a):
            raise OSError(errno.EXDEV, os.strerror(errno.EXDEV))

        os.link, real_link = exdev, os.link  # a staging file on another mount is copied
        try:
            place(torrent, OUT / "Movies/copy.mkv", link=True)
        finally:
            os.link = real_link
        assert (OUT / "Movies/copy.mkv").stat().st_nlink == 1 and torrent.stat().st_nlink == 3
    print("self-test passed")


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
