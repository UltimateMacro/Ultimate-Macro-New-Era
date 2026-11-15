# Ultimate Macro 1.4.1.4 — run-options clarification

* Renamed **Scroll amount** to **Map-list scroll steps**. The 5–20 value controls mouse-wheel scrolling in the map/mode menu, not how many matches run.
* Added clear guidance that there is **no fixed 20-match cap**. Use F2 or dashboard stop controls when you want to stop.
* Preserved the working gameplay engine, watchdog, recorder, dashboard and automatic chat closing from 1.4.1.3. Explicit stop and cooldown controls remain available.
* Added regression checks past 20 match-end/relaunch decisions and corrected the outdated package-version checker without bypassing hash or version checks.

Install the full ZIP into a new folder or use **Settings → Check / review update** in a replacement-key build. Builds trusting the deleted old key still need one manual ZIP install.

Regression tests use hidden UI and inert game/process input. They are not a claim of live testing every strategy. The existing unrelated website-test failures are outside this UI-only hotfix.
