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
    members_display = (number(members) if stats.get("discord_members_fresh")
                       else "~" + number(members)) if members is not None else "—"
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="760" height="605" viewBox="0 0 760 605" role="img" aria-labelledby="title desc">
<title id="title">Ultimate Macro community statistics</title>
<desc id="desc">{number(stats['total_downloads'])} GitHub release downloads across Darksen and The New Era, {html.escape(members_display)} approximate Discord members, {number(stats['stars'])} stars on this GitHub repository.</desc>
<defs>
  <linearGradient id="downloads" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#101720"/><stop offset=".62" stop-color="#142132"/><stop offset="1" stop-color="#1A344C"/></linearGradient>
  <linearGradient id="community" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#111721"/><stop offset=".62" stop-color="#1B1E35"/><stop offset="1" stop-color="#2B2746"/></linearGradient>
  <linearGradient id="stars" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#14171A"/><stop offset=".62" stop-color="#221F18"/><stop offset="1" stop-color="#3C3013"/></linearGradient>
</defs>
<rect x="2" y="2" width="756" height="190" rx="20" fill="url(#downloads)" stroke="#344B5E" stroke-width="2"/>
<rect x="2" y="207" width="756" height="190" rx="20" fill="url(#community)" stroke="#474360" stroke-width="2"/>
<rect x="2" y="412" width="756" height="190" rx="20" fill="url(#stars)" stroke="#675735" stroke-width="2"/>
<g font-family="Arial, Helvetica, sans-serif">
  <text x="38" y="58" font-size="30" font-weight="600" fill="#A9C7E7">Downloads</text>
  <text x="37" y="133" font-size="78" font-weight="700" letter-spacing="-2" fill="#F2F7FF">{number(stats['total_downloads'])}</text>
  <text x="40" y="166" font-size="21" fill="#B1C0D2">Darksen + The New Era</text>
  <text x="38" y="263" font-size="30" font-weight="600" fill="#C4B5FD">Community of</text>
  <text x="37" y="338" font-size="78" font-weight="700" letter-spacing="-2" fill="#F8F6FF">{html.escape(members_display)}</text>
  <text x="40" y="371" font-size="21" fill="#BFC0D6">Discord members</text>
  <text x="38" y="468" font-size="30" font-weight="600" fill="#F5CD69">GitHub stars</text>
  <text x="37" y="543" font-size="78" font-weight="700" letter-spacing="-2" fill="#FFFAEB">{number(stats['stars'])}</text>
  <text x="40" y="576" font-size="21" fill="#D5C6A0">Show some love to the project</text>
</g>
<g fill="none" stroke="#A8D9FF" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
  <path d="M674 53v55m-22-22 22 22 22-22M640 117v18h68v-18"/>
</g>
<g fill="none" stroke="#C9BBFF" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="674" cy="257" r="16"/><path d="M648 307v-7c0-25 52-25 52 0v7"/>
  <path d="M638 271a13 13 0 1 1 8-24M628 306v-10q0-10 11-14M710 271a13 13 0 1 0-8-24M720 306v-10q0-10-11-14"/>
</g>
<path d="m674 456 13.7 28 30.9 4.5-22.3 21.7 5.3 30.7-27.6-14.5-27.6 14.5 5.3-30.7-22.3-21.7 30.9-4.5z" fill="#F5C451" stroke="#FFE4A0" stroke-width="3" stroke-linejoin="round"/>
</svg>
"""


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
