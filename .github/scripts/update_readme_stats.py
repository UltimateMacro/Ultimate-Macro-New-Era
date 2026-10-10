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
    member_count = stats.get("discord_members")
    member_fresh = stats.get("discord_members_fresh", False)
    if member_count is None:
        members_display = "Pending"
        members_sub = "Discord count unavailable"
    else:
        members_display = number(member_count) if member_fresh else "~" + number(member_count)
        members_sub = "Discord members (approx.)"
    when = stats["updated_at"].replace("T", " ")[:16] + " UTC"
    if member_fresh:
        discord_note = "Discord invite API"
    else:
        last = stats.get("discord_members_checked_at", "unknown")[:10]
        discord_note = f"member estimate last checked {last}"
    # The artwork is deliberately static SVG: GitHub READMEs do not execute JS.
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="300" viewBox="0 0 1200 300" role="img" aria-labelledby="title desc">
<title id="title">Ultimate Macro community statistics</title>
<desc id="desc">{number(stats['total_downloads'])} GitHub release downloads from Darksen and New Era, {html.escape(members_display)} Discord members, {number(stats['stars'])} GitHub stars. Updated {when}.</desc>
<rect x="1" y="1" width="1198" height="298" rx="20" fill="#10151d" stroke="#2c3949" stroke-width="2"/>
<path d="M400 40v190M800 40v190" stroke="#2c3949" stroke-width="2"/>
<g font-family="Arial, Helvetica, sans-serif">
<text x="46" y="64" font-size="17" font-weight="700" letter-spacing="2" fill="#92a8bf">TRUSTED BY THE COMMUNITY</text>
<text x="46" y="152" font-size="74" font-weight="700" fill="#f5f7fa">{number(stats['total_downloads'])}</text>
<text x="47" y="195" font-size="21" fill="#c1cedd">GitHub release downloads</text>
<text x="47" y="225" font-size="15" fill="#879cb2">Darksen + The New Era</text>
<text x="446" y="64" font-size="17" font-weight="700" letter-spacing="2" fill="#92a8bf">COMMUNITY OF</text>
<text x="446" y="152" font-size="74" font-weight="700" fill="#f5f7fa">{html.escape(members_display)}</text>
<text x="447" y="195" font-size="21" fill="#c1cedd">{members_sub}</text>
<text x="447" y="225" font-size="15" fill="#879cb2">{html.escape(discord_note)}</text>
<text x="846" y="64" font-size="17" font-weight="700" letter-spacing="2" fill="#92a8bf">GITHUB STARS</text>
<text x="846" y="152" font-size="74" font-weight="700" fill="#f5f7fa">{number(stats['stars'])}</text>
<text x="847" y="195" font-size="21" fill="#c1cedd">On The New Era</text>
<text x="847" y="225" font-size="15" fill="#879cb2">Public repository</text>
<path d="M46 251h1108" stroke="#2c3949" stroke-width="1"/>
<text x="46" y="278" font-size="14" fill="#879cb2">Download events, not unique users  ·  Counts refreshed about hourly</text>
<text x="1154" y="278" text-anchor="end" font-size="13" fill="#879cb2">{html.escape(when)}</text>
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
    ASSETS.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")
    IMAGE_PATH.write_text(draw(stats), encoding="utf-8")
    print(f"GitHub downloads: {stats['total_downloads']}; stars: {stars}; Discord: {members}")


if __name__ == "__main__":
    main()
