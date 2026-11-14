"""Copy finished torrents from /watch into the Jellyfin libraries, named the way
FileBot AMC named them (TMDB names, same formats) so new episodes land in the
existing folders. Unsure matches are logged and left for a human, not guessed.
Sonarr/Radarr's imports (STAGING) are sorted the same way, as hardlinks, with
the show or movie taken from the TMDB/TVDB id in their folder names.
What is left for a human is listed in Unsorted/needs-sorting.txt; lines in
Unsorted/overrides.txt name the TMDB entry (or "skip") for such a file.

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
HELP = """# Files media-sort couldn't sort on its last run. To sort one, add a line to
# overrides.txt: uncomment a candidate below, or write your own (the id is the
# number in the themoviedb.org URL):
#   <path> = tv <id>    <path> = tv <id> S01E02    <path> = movie <id>    <path> = skip
# A <path> ending in / covers every file under it. media-sort reruns within minutes.

"""


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
    # never .torrents/.sonarr/.radarr (a show named "Torrents" isn't one of them)
    same = (d.name for d in sorted(parent.iterdir()) if d.is_dir() and not d.name.startswith(".") and re.sub(r"\W", "", d.name).lower() == key)
    return next(same, name)


def guess(rel, kind=None, staging=False):
    g = guessit(re.sub(r"(?i)(E\d+)v\d\b", r"\1", rel), {"type": kind} if kind else None)  # S01E13v2
    if not staging and g.get("season") is not None and g.get("season") == g.get("year"):
        del g["season"]  # "Fruits Basket (2019) - 10"; STAGING always says SxxEyy (daily shows: S2019E10)
    return g


def target(rel, suffix, kind=None, rule=None):
    """Library path for the video at <root>/<rel>, or None when unsure. kind is
    set for STAGING: its "episode"/"movie", and the ids in rel pick the TMDB entry.
    rule, an overrides.txt line's (kind, TMDB id, season, episode), replaces the
    guessed kind, the ids and (when given) the episode."""
    g = guess(rel, rule[0] if rule else kind, bool(kind))
    title, year = g.get("title"), g.get("year")
    tmdb_id, tvdb_id = (g.get("tmdb_id"), g.get("tvdb_id")) if kind else (None, None)
    if rule:
        tmdb_id, tvdb_id = rule[1], None
        if rule[2] is not None:
            g["season"], g["episode"] = rule[2], rule[3]  # absolute-numbered anime
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
        hits = [tmdb(f"tv/{tmdb_id}", append_to_response="external_ids")]
        if tvdb_id and hits[0]["external_ids"].get("tvdb_id") not in (None, tvdb_id):
            return None  # TVDB's TMDB link (Sonarr's {TmdbId}) points at another show
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


def handle(f, rel, kind=None, rule=None):
    """Place one video and its English subtitle; False when left for a human."""
    sample = re.search(r"(?i)\bsample", f.name) or f.parent.name.lower() in ("sample", "samples")
    if sample or f.stat().st_size < MIN_SIZE:
        print(f"[SKIP] sample or extra: {rel}")
        return True
    dst = target(rel, f.suffix.lower(), kind, rule)
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


def unpack(f, rel, rule=None):
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
        ok = bool(vids) and all([handle(v, str(rel.parent / v.relative_to(x)), rule=rule) for v in vids])
        if not ok:  # name the archive: it, not what came out of it, goes on the done list
            print(f"[HUMAN] archive not fully sorted, left for a human: {rel}")
        return ok


def overrides(text):
    """overrides.txt's rules {path: "skip" or (kind, TMDB id, season, episode)}, and
    its malformed lines. A path ending in "/" covers every file under it. Paths
    are only ever compared with the files media-sort found, never opened."""
    rules, bad = {}, []
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        # lazy: the path ends at the first "=" that a rule follows (paths and comments may hold "=")
        m = re.fullmatch(r"(?i)(.*?)\s*=\s*(?:(skip)|(tv|movie)\s+(\d+)(?:\s+S(\d+)E(\d+))?)\s*(?:#.*)?", line.strip())
        if not m or not m[1] or m[5] and (m[3].lower() == "movie" or m[1].endswith("/")):  # an episode is one file
            bad.append(line)
        elif m[2]:
            rules[m[1]] = "skip"
        else:
            rules[m[1]] = ("movie" if m[3].lower() == "movie" else "episode", int(m[4])) + ((int(m[5]), int(m[6])) if m[5] else (None, None))
    return rules, bad


def override(key, rules):
    """The rule for the file media-sort keys as key: its own line, else the longest folder line over it."""
    hits = [p for p in rules if p == key or p.endswith("/") and key.startswith(p)]
    return rules[max(hits, key=len)] if hits else None


def report(key, rel, kind, reason):
    """needs-sorting.txt's entry for a file left for a human: why, what guessit
    read, and TMDB's top 3 for that title as commented-out override lines."""
    g = guess(rel, kind, bool(kind))
    movie = g.get("type") == "movie"
    read = ", ".join(f"{k} {g[k]}" for k in ("title", "year", "season", "episode") if k in g)
    out = [f"# {key}", f"#   {reason}; guessit read: {g.get('type')}, {read}"]
    try:
        hits = tmdb("search/movie" if movie else "search/tv", query=g["title"])["results"][:3] if g.get("title") else []
    except Exception as e:  # TMDB down: still list the file
        hits = []
        out.append(f"#   no TMDB candidates: {e!r}")
    for h in hits:
        name, date = (h.get("title"), h.get("release_date")) if movie else (h.get("name"), h.get("first_air_date"))
        out.append(f"# {key} = {'movie' if movie else 'tv'} {h['id']}  # {name} ({(date or '?')[:4]})")
    return "\n".join(out) + "\n\n"


def main():
    """Sort every new file; True when something failed (it is retried next run)."""
    done_list = Path(os.environ["DONE_LIST"])  # FileBot's exclude list: /watch/... paths, then STAGING's
    done = set(done_list.read_text().splitlines())
    unsorted = OUT / "Unsorted"  # on the samba share: needs-sorting.txt for cole, overrides.txt from him
    ov = unsorted / "overrides.txt"
    rules, bad = overrides(ov.read_text(encoding="utf-8-sig", errors="replace") if ov.exists() else "")
    needs = []
    for line in bad:
        print(f"[WARN] overrides.txt: ignored, not '<path> = tv|movie <id> [SxxEyy]' or '<path> = skip': {line}")
        needs.append(f"# overrides.txt: this line was ignored, see the format above:\n#   {line}\n\n")
    failed = False
    # never .torrents: Sonarr/Radarr decide what in there is the requested file
    files = [(f, WATCH, None) for f in sorted(WATCH.rglob("*"))]
    files += [(f, OUT / d, kind) for d, kind in STAGING.items() for f in sorted((OUT / d).rglob("*"))]
    for f, root, kind in files:
        if str(f) in done or f.is_symlink() or not f.is_file():
            continue
        rel = f.relative_to(root)
        rule = override(str(f), rules)
        try:
            if rule == "skip" and (f.suffix.lower() in VIDEO or first_volume(f.name)):
                print(f"[SKIP] overrides.txt says skip: {rel}")
                ok = True
            elif f.suffix.lower() in VIDEO:
                ok = handle(f, str(rel), kind, rule)
            elif first_volume(f.name):
                ok = unpack(f, rel, rule)
            else:
                continue
        except Exception as e:  # TMDB down or rate-limited, disk full: not marked done
            print(f"[ERROR] {rel}: {e!r}")
            failed = True
            needs.append(f"# {f}\n#   error, retried next run: {e!r}\n\n")
            continue
        if not ok:
            needs.append(report(f, str(rel), kind, "archive not fully sorted (see the journal)" if first_volume(f.name) else "no confident match"))
        elif not DRY:
            with done_list.open("a") as d:
                d.write(f"{f}\n")
    text = HELP + "".join(needs) if needs else "# Nothing needs sorting.\n"
    if DRY:
        print(text, end="")
    else:  # whole or not at all: cole may be reading it over samba
        part = unsorted / ".needs-sorting.txt.part"
        part.write_text(text, errors="surrogateescape")
        part.replace(unsorted / "needs-sorting.txt")
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
        ("search/movie", "Mystery"): {"results": [{"id": i, "title": f"Mystery {i}", "release_date": f"200{i}-01-01"} for i in range(1, 5)]},
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
        for d in ["TV/Cyberpunk - Edgerunners", "TV/Cyberpunk Edgerunners", "TV/JUJUTSU KAISEN", "Movies", "Unsorted"]:
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
        assert sorted((OUT / "Movies").rglob("*.*")) + sorted((OUT / "TV").rglob("*.*")) == [movie.with_suffix(".mkv"), movie.with_suffix(".srt")]
        assert movie.with_suffix(".srt").read_text().endswith("2_English.srt")
        assert Path(t, "done.txt").read_text().splitlines() == [str(WATCH / p) for p in files[:3]]
        assert not main() and len(Path(t, "done.txt").read_text().splitlines()) == 3  # done stays done

        # STAGING: the id in Sonarr/Radarr's folder name picks the show or movie
        # (their titles are wrong here on purpose; JJK has only a TVDB id), the
        # library gets a hardlink, and .torrents is never read
        answers |= {
            ("tv/1", None): {"id": 1, "name": "Cyberpunk: Edgerunners", "external_ids": {"tvdb_id": 5}},
            ("find/9", None): {"tv_results": [{"id": 2, "name": "Jujutsu Kaisen"}]},
            ("movie/8", None): {"title": "Heat", "release_date": "1995-12-15"},
        }
        staged = [
            "TV/.sonarr/Wrong (2020) [tmdbid-] [tvdbid-9]/Season 1/Wrong (2020) - S01E05.mkv",
            "TV/.sonarr/Wrong (2022) [tmdbid-1] [tvdbid-5]/Season 2/Wrong (2022) - S02E03.mkv",
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
        assert folder(tv, "Sonarr") == "Sonarr"  # not .sonarr
        assert target("Wrong (2022) [tmdbid-1] [tvdbid-6]/Season 2/Wrong (2022) - S02E03.mkv", ".mkv", "episode") is None  # ids disagree
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

        # overrides.txt: a file's own line, else the longest folder line; malformed lines are returned
        rules, bad = overrides("# note\n\n/a/b.mkv = tv 1 s01e02\n/a/ = TV 2  # Show = Name (2019)\n/a/c/ = movie 3\n/x=y.mkv = skip\nno rule\n/m.mkv = movie 4 S01E02\n/z/ = tv 5 S01E01\n/w.mkv = tv abc\n")
        assert bad == ["no rule", "/m.mkv = movie 4 S01E02", "/z/ = tv 5 S01E01", "/w.mkv = tv abc"]
        assert override("/a/b.mkv", rules) == ("episode", 1, 1, 2) and override("/a/c/d.mkv", rules) == ("movie", 3, None, None)
        assert override("/a/e.mkv", rules) == ("episode", 2, None, None) and override("/ab/e.mkv", rules) is None and override("/x=y.mkv", rules) == "skip"
        # the line's episode replaces guessit's absolute number
        answers |= {("tv/2", None): {"id": 2, "name": "Jujutsu Kaisen", "external_ids": {}}, ("tv/2/season/2/episode/10", None): {"name": "Thunderclap"}}
        assert target("[SubsPlease] Jujutsu Kaisen - 34 (1080p).mkv", ".mkv", None, ("episode", 2, 2, 10)) == tv / "JUJUTSU KAISEN/Season 2/JUJUTSU KAISEN 2x10 - Thunderclap.mkv"

        # needs-sorting.txt lists what was left for a human, with TMDB's top 3 as override lines
        needs, mystery, unknown = OUT / "Unsorted/needs-sorting.txt", WATCH / "Mystery.mkv", WATCH / "Unknown.Show.S01E01.mkv"
        text = needs.read_text()
        assert text.startswith(HELP) and f"# {mystery}\n#   no confident match; guessit read: movie, title Mystery\n" in text
        assert f"# {mystery} = movie 3  # Mystery 3 (2003)\n\n" in text and "Mystery 4" not in text
        # an override files it (copied, like any /watch file); a malformed line is reported, not fatal
        answers |= {("movie/11", None): {"title": "Mystery Men", "release_date": "1999-08-06"}, ("search/tv", "Unknown Show"): {"results": []}}
        unknown.write_text("x")
        os.truncate(unknown, MIN_SIZE)
        (OUT / "Unsorted/overrides.txt").write_text(f"{mystery} = movie 11\nbroken line\n")
        assert not main()
        assert (OUT / "Movies/Mystery Men (1999)/Mystery Men (1999).mkv").stat().st_nlink == 1
        text = needs.read_text()
        assert "#   broken line\n" in text and f"# {unknown}\n" in text and str(mystery) not in text
        # skip: on the done list, no longer listed; with nothing left the file says so
        (OUT / "Unsorted/overrides.txt").write_text(f"{mystery} = movie 11\n{WATCH}/ = tv 1\n{unknown} = skip\n")
        assert not main()
        assert Path(t, "done.txt").read_text().splitlines()[-2:] == [str(mystery), str(unknown)]
        assert needs.read_text() == "# Nothing needs sorting.\n" and not (OUT / "Unsorted/.needs-sorting.txt.part").exists()
    print("self-test passed")


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
