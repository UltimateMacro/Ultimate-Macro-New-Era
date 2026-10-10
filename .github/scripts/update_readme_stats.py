#!/usr/bin/env python3
"""Refresh the README's GitHub release, Discord, and star counts.

Only published release download assets count. These are download events,
not unique people. Discord's invite API returns an approximate member count.
"""
import datetime as dt
import html
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / ".github" / "assets"
STATE_PATH = ASSETS / "community-stats.json"
IMAGE_PATH = ASSETS / "community-stats.svg"
REPOS = ("DarksenDev/tds-macro", "UltimateMacro/Ultimate-Macro-New-Era")
DOWNLOAD_EXTENSIONS = (".zip", ".exe", ".msi", ".7z", ".rar")
INVITE = "ultmacro"


def get_json(url, *, discord=False):
    headers = {
        "Accept": "application/vnd.github+json" if not discord else "application/json",
        "User-Agent": "UltimateMacro-ReadmeStats/1.0",
    }
    if not discord:
        headers["X-GitHub-Api-Version"] = "2022-11-28"
        if os.environ.get("GH_TOKEN"):
            headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=25) as response:
        return json.load(response)


def release_downloads(repo):
    total = 0
    counted = 0
    for page in range(1, 101):
        url = f"https://api.github.com/repos/{repo}/releases?per_page=100&page={page}"
        releases = get_json(url)
        if not isinstance(releases, list):
            raise ValueError(f"Invalid releases response for {repo}")
        for release in releases:
            if release.get("draft"):
                continue
            for asset in release.get("assets", []):
                name = str(asset.get("name", "")).lower()
                if name.endswith(DOWNLOAD_EXTENSIONS):
                    total += int(asset["download_count"])
                    counted += 1
        if len(releases) < 100:
            return {"downloads": total, "assets": counted}
    raise ValueError(f"Release pagination exceeded 100 pages for {repo}")


def read_state():
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def draw(stats):
    number = lambda n: f"{n:,}"
    members = stats.get("discord_members")
    if members is None:
        members_display = "—"
    elif stats.get("discord_members_fresh", False):
        members_display = number(members)
    else:
        members_display = "~" + number(members)

    when = stats["updated_at"]
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="215" viewBox="0 0 1200 215" role="img" aria-labelledby="title desc">
<title id="title">Ultimate Macro community</title>
<desc id="desc">{number(stats['total_downloads'])} GitHub release downloads across Darksen and The New Era, approximately {html.escape(members_display)} Discord members, {number(stats['stars'])} GitHub stars. Figures last changed {html.escape(when)}.</desc>
<rect x="1" y="1" width="1198" height="213" rx="18" fill="#111821" stroke="#2f3a49" stroke-width="2"/>
<path d="M400 35V178 M800 35V178" stroke="#324053" stroke-width="2"/>
<g font-family="Arial, Helvetica, sans-serif">
<text x="46" y="58" font-size="24" font-weight="600" fill="#b0c1d4">Trusted by the community</text>
<text x="46" y="143" font-size="70" font-weight="700" fill="#f3f6fa">{number(stats['total_downloads'])}</text>
<text x="47" y="182" font-size="23" fill="#b0c1d4">GitHub downloads</text>
<text x="447" y="58" font-size="24" font-weight="600" fill="#b0c1d4">Community of</text>
<text x="446" y="143" font-size="70" font-weight="700" fill="#f3f6fa">{html.escape(members_display)}</text>
<text x="447" y="182" font-size="23" fill="#b0c1d4">Discord members</text>
<text x="846" y="58" font-size="24" font-weight="600" fill="#b0c1d4">On GitHub</text>
<text x="846" y="143" font-size="70" font-weight="700" fill="#f3f6fa">{number(stats['stars'])}</text>
<text x="847" y="182" font-size="23" fill="#b0c1d4">Stars</text>
</g>
</svg>"""
    return svg + "\n"


def main():
    old = read_state()
    darksen, new_era = (release_downloads(repo) for repo in REPOS)
    repo = get_json("https://api.github.com/repos/UltimateMacro/Ultimate-Macro-New-Era")
    stars = int(repo["stargazers_count"])
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    members = old.get("discord_members")
    member_checked_at = old.get("discord_members_checked_at")
    fresh = False
    try:
        invitation = get_json(
            f"https://discord.com/api/v10/invites/{INVITE}?with_counts=true",
            discord=True,
        )
        value = invitation.get("approximate_member_count")
        if not isinstance(value, int) or value < 0:
            raise ValueError("Discord invite returned no valid member count")
        members, member_checked_at, fresh = value, now, True
    except (urllib.error.URLError, ValueError, KeyError) as err:
        print(f"Warning: Discord count unavailable; keeping last known estimate: {err}")
    stats = {
        "darksen_downloads": darksen["downloads"],
        "new_era_downloads": new_era["downloads"],
        "total_downloads": darksen["downloads"] + new_era["downloads"],
        "counted_release_assets": darksen["assets"] + new_era["assets"],
        "stars": stars,
        "discord_members": members,
        "discord_members_checked_at": member_checked_at,
        "discord_members_fresh": fresh,
        "updated_at": now,
    }
    changed_fields = ("darksen_downloads", "new_era_downloads", "total_downloads",
                      "counted_release_assets", "stars", "discord_members",
                      "discord_members_fresh")
    if IMAGE_PATH.exists() and all(old.get(key) == stats[key] for key in changed_fields):
        print("Community counts unchanged; no commit needed")
        return
    ASSETS.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")
    IMAGE_PATH.write_text(draw(stats), encoding="utf-8")
    print(f"GitHub downloads: {stats['total_downloads']}; stars: {stars}; Discord: {members}")


if __name__ == "__main__":
    main()
