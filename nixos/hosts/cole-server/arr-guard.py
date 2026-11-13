"""Sonarr and Radarr may only monitor what was requested in Ombi.

Each run unmonitors every Sonarr episode and Radarr movie that no (non-denied)
Ombi request asked for, and turns Sonarr's "monitor new seasons" off: Ombi
leaves it at "all", so a requested show would grab every later season. It
never monitors, searches or deletes anything. Then it lists settings that would
let downloads outgrow the requests, and exits 1 if there are any.

arr-guard [--dry-run | --self-test]"""

import json
import os
import sys
import urllib.request

DRY = "--dry-run" in sys.argv
SONARR, RADARR, OMBI = "http://127.0.0.1:8989/api/v3", "http://127.0.0.1:7878/api/v3", "http://127.0.0.1:5000/api/v1"
KEYS = {SONARR: ("SONARR_API_KEY", "X-Api-Key"), RADARR: ("RADARR_API_KEY", "X-Api-Key"), OMBI: ("OMBI_API_KEY", "ApiKey")}
MIN_FREE_MB = 150_000  # Sonarr/Radarr refuse grabs that would leave less free on /HDD4TB


def api(base, path, body=None):
    env, header = KEYS[base]
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data, {header: os.environ[env], "Content-Type": "application/json"}, method="GET" if body is None else "PUT")
    with urllib.request.urlopen(req, timeout=60) as r:  # keys go in headers: errors never show them
        return json.load(r) if body is None else None


def requested(tv, movies):
    """Ombi's non-denied requests: {tvdbId: {(season, episode)}} and {tmdbId}."""
    eps = {}
    for r in tv:
        for c in r["childRequests"]:
            if not c.get("denied"):
                for s in c["seasonRequests"]:
                    eps.setdefault(r["tvDbId"], set()).update((s["seasonNumber"], e["episodeNumber"]) for e in s["episodes"])
    return eps, {m["theMovieDbId"] for m in movies if not m.get("denied")}


def strays(series, episodes, eps):
    """Monitored Sonarr episodes nobody requested; episodes is {seriesId: [episode]}."""
    return [(s, e) for s in series for e in episodes[s["id"]] if e["monitored"] and (e["seasonNumber"], e["episodeNumber"]) not in eps.get(s["tvdbId"], ())]


def problems(app, base):
    """Settings that would let Sonarr/Radarr download more, or more often, than asked."""
    mm = api(base, "/config/mediamanagement")
    checks = {
        f"Minimum Free Space under {MIN_FREE_MB} MB, or its check skipped": mm["minimumFreeSpaceWhenImporting"] < MIN_FREE_MB or mm["skipFreeSpaceCheckWhenImporting"],
        "hardlinks off (every import is a full copy)": not mm["copyUsingHardlinks"],
        "propers/repacks replace existing files": mm["downloadPropersAndRepacks"] == "preferAndUpgrade",
    }
    bad = [msg for msg, failed in checks.items() if failed]
    bad += [f"quality profile {p['name']} allows upgrades" for p in api(base, "/qualityprofile") if p["upgradeAllowed"]]
    bad += [f"download client {c['name']} removes completed torrents" for c in api(base, "/downloadclient") if c["removeCompletedDownloads"]]
    # seedRatio, seedTime, seasonPackSeedTime: what Prowlarr's Full Sync copies from its indexers
    bad += [f"indexer {i['name']} stops seeding ({f['name']})" for i in api(base, "/indexer") for f in i["fields"] if f["name"].startswith("seedCriteria.") and f.get("value")]
    bad += [f"import list {x['name']}" for x in api(base, "/importlist")]
    if base == RADARR:
        bad += [f"collection {c['title']} monitored (adds its movies)" for c in api(base, "/collection") if c["monitored"]]
    return [f"[SETTING] {app}: {b}" for b in bad]


def main():
    eps, movie_ids = requested(api(OMBI, "/Request/tv"), api(OMBI, "/Request/movie"))  # Ombi down: exit before changing anything
    series = api(SONARR, "/series")
    new_seasons = [s for s in series if s["monitorNewItems"] != "none"]
    for s in new_seasons:
        print(f"[NEW SEASONS OFF] {s['title']}")
    stray = strays(series, {s["id"]: api(SONARR, f"/episode?seriesId={s['id']}") for s in series}, eps)
    for s, e in stray:
        print(f"[UNMONITOR] {s['title']} S{e['seasonNumber']:02d}E{e['episodeNumber']:02d}")
    movies = [m for m in api(RADARR, "/movie") if m["monitored"] and m["tmdbId"] not in movie_ids]
    for m in movies:
        print(f"[UNMONITOR] {m['title']} ({m['year']})")
    if not DRY:
        if new_seasons:
            api(SONARR, "/series/editor", {"seriesIds": [s["id"] for s in new_seasons], "monitorNewItems": "none"})
        if stray:
            api(SONARR, "/episode/monitor", {"episodeIds": [e["id"] for _, e in stray], "monitored": False})
        if movies:
            api(RADARR, "/movie/editor", {"movieIds": [m["id"] for m in movies], "monitored": False})
    bad = problems("Sonarr", SONARR) + problems("Radarr", RADARR)
    for b in bad:
        print(b)
    return bool(bad)


def self_test():
    tv = [{"tvDbId": 1, "childRequests": [
        {"denied": None, "seasonRequests": [{"seasonNumber": 2, "episodes": [{"episodeNumber": 1}, {"episodeNumber": 2}]}]},
        {"denied": True, "seasonRequests": [{"seasonNumber": 3, "episodes": [{"episodeNumber": 1}]}]},
    ]}]
    eps, movie_ids = requested(tv, [{"theMovieDbId": 7, "denied": False}, {"theMovieDbId": 8, "denied": True}])
    assert eps == {1: {(2, 1), (2, 2)}} and movie_ids == {7}
    ep = lambda i, s, e, mon=True: {"id": i, "seasonNumber": s, "episodeNumber": e, "monitored": mon}  # noqa: E731
    series = [{"id": 10, "tvdbId": 1}, {"id": 11, "tvdbId": 2}]
    episodes = {10: [ep(1, 2, 1), ep(2, 2, 3), ep(3, 3, 1), ep(4, 1, 1, False)], 11: [ep(5, 1, 1)]}
    # requested stays; unrequested, denied and never-requested shows go; unmonitored ones are left alone
    assert [e["id"] for _, e in strays(series, episodes, eps)] == [2, 3, 5]
    print("self-test passed")


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
