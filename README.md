# Ultimate Macro: New Era

<p align="center">
  <strong>Open-source strategy recording and automation for Roblox Tower Defense Simulator.</strong>
</p>

<p align="center">
  <a href="https://github.com/UltimateMacro/Ultimate-Macro-New-Era/releases">Download</a>
  ·
  <a href="docs/README.md">Documentation</a>
  ·
  <a href="CONTRIBUTING.md">Contributing</a>
  ·
  <a href="SECURITY.md">Security</a>
</p>

Ultimate Macro: New Era continues Darksen's original Ultimate Macro with an active maintenance line focused on reliability, strategy tooling, recovery, and a cleaner user experience.

> **Users should install from the official GitHub Releases page.** Repository checkouts contain development and QA tooling that is intentionally excluded from release ZIPs.

## Highlights

- Record and replay complete TDS strategies.
- Place, upgrade, sell, target, reposition, and use abilities.
- Strategy rotation and community `.strat` support.
- Strategy Lab tooling for editing and reviewing recorded strategies.
- TimeScale support with verified activation and bounded recovery.
- Auto Equip, Auto Skip, Party Mode, VIP server support, and reconnect recovery.
- Resolution-aware image detection and OCR.
- Discord webhook reporting and authenticated Official Remote controls.
- Profiles, persistent logging, updater rollback, and protected user strategies.

## Quick start

1. Download `TDS_Macro.zip` from the [official releases](https://github.com/UltimateMacro/Ultimate-Macro-New-Era/releases).
2. Extract the ZIP completely.
3. Run `Main.ahk`.
4. Configure the macro and Roblox settings.
5. Start the macro.

See [Installation](docs/user/INSTALLATION.md) and [Troubleshooting](docs/user/TROUBLESHOOTING.md) for more detail.

## Recommended environment

- Windows 10 or Windows 11
- 1920×1080 recommended
- 100% Windows display scaling recommended
- Roblox at 60 FPS
- TDS UI Scale: Large
- TDS Screen Shake: Disabled
- TDS Prefer Vertical Upgrades: Enabled

## Repository layout

```text
.github/       GitHub workflows, issue forms, ownership and PR templates
Resources/     Runtime images and bundled strategies
lib/           Runtime libraries and integrations
submacros/     Updater, watchdog and supporting runtime components
tests/         Regression and repository contracts
tools/         Developer validation and packaging tools
docs/          User, development and QA documentation
Main.ahk       Runtime entry point
```

The project is being migrated toward smaller runtime modules incrementally. Large runtime refactors must preserve behavior and add regression coverage before code is moved.

## Development workflow

- `main` is the stable/public-ready line.
- `integration` is the shared staging line in the private development mirror.
- `dev/<handle>` is a long-lived personal workspace.
- `feature/<handle>/<topic>`, `fix/<handle>/<topic>`, and `refactor/<topic>` are short-lived task branches.
- Release candidates use `release/<version>`.

See [Branching model](docs/development/BRANCHING.md), [Architecture](docs/development/ARCHITECTURE.md), and [Release process](docs/development/RELEASE_PROCESS.md).

## Development team

- pizzaroles24
- ziadod
- kronoxxv
- banana.dev
- itzshovel
- salkann
- aiden

### QA

- nytli
- tristanm1ce
- frostzzz

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md). Runtime changes should be focused, testable, and accompanied by the relevant automated and manual checks.

Never publish Discord tokens, webhook URLs, Roblox private-server links, personal configuration, or unsanitized logs/screenshots.

## Credits

Ultimate Macro was originally created by Darksen. The New Era exists because of that work and continues under the same open-source spirit.

- Original project: [DarksenDev/tds-macro](https://github.com/DarksenDev/tds-macro)
- Support Darksen: [DonationAlerts](https://www.donationalerts.com/r/darksen1)
- Support New Era Developers: [DonationAlerts](https://www.donationalerts.com/r/neweradevelopers)

## License

Licensed under the [GNU General Public License v3.0](LICENSE).
