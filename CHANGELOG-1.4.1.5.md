# Ultimate Macro 1.4.1.5

* Restored the original **two-strategy rotation from 1.3.3a** in the current
  1.4 UI. The supplied modified 1.3.3.10 had removed it.
* In **Run → Strategy cycling**, turn on **Strategy rotation**, choose
  **Strategy 2**, and set **Swap after** to a number of **Runs** or **Minutes**.
  Strategy 1 runs first, then the two alternate between matches. The minutes
  timer is checked at match boundaries, not in the middle of a match.
* Kept the original automatic loadout change when switching strategies.
  Enabling rotation enables auto-equip; fresh starts begin with strategy 1.
  The watchdog's normal relaunch retains the active slot and interval progress.
* Added checks for missing strategy files/invalid intervals and locked slot
  editing during a run. Explicit dashboard stop/cooldown commands take priority.
  Dashboard status now reports both selected slots and the active strategy.
* Preserved the modified 1.3.3.10 gameplay core, the recorder, default-on chat
  closing, UltBot/dashboard pairing, tray mode and existing signed updater.
* Updated website link-preview images to the current UI, using a new image
  filename. Previously posted Discord messages may retain cached previews.

Verification: 1,415 hidden rotation assertions, original-switch provenance,
pinned gameplay-core comparisons, existing recorder/shortcut/lifecycle/chat
checks, dashboard contract checks, package hashes and updater safety tests.
Tests run without controlling a live game; this is not a claim that every
community strategy, game mode or resolution has been live-tested.

The signed v2 updater is supported. Installations that only trust the lost
older signing key still need a one-time manual download; signature verification
has not been weakened or bypassed.
