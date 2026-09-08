# Troubleshooting

## Macro does not start

- Confirm the release was fully extracted.
- Confirm required runtime files were not removed by antivirus or manual cleanup.
- Use the official release ZIP rather than a partial copy of the repository.
- Capture the exact error message before changing files.

## Image detection or placement is inaccurate

Record display resolution, Windows scaling, Roblox client size, monitor/window position, and whether the problem is consistent or intermittent.

Avoid changing thresholds or coordinates before reproducing the problem on a clean configuration.

## TimeScale, placement, upgrade, or sell reports success incorrectly

Treat this as a state-verification bug. Report what input was sent, what Roblox visibly did, and what the macro logged afterwards.

## Recorder / Strategy Lab issue

Preserve the original `.strat` file and a sanitized copy of the relevant log. Do not edit the file before attaching reproduction details.

## Update problem

Do not manually delete the current installation while diagnosing an update failure. The transactional updater is designed to preserve or restore the prior installation when validation fails.

## Sensitive reports

Use the private security route described in [SECURITY.md](../../SECURITY.md) for vulnerabilities, updater bypasses, credential exposure, or arbitrary code/file execution.
