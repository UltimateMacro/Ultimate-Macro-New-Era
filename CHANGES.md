# AutoHotkey edition

## 1.4.0.40

- Wait for a recognizable TDS screen rather than relaunching a healthy client
  during setup. A closed client stops playback without a relaunch loop.
- Recheck Restart, Play Again, and Timescale confirmation before clicking.
  The tower panel must clear before the next placement.
- Retry recognition of the current Survival menu and scroll it in small steps.
- Show modifiers alongside the strategy's map, mode, and required loadout.
- Add optional extra UI wait, pre-join delay, and key delay in Advanced settings.
- Let file and update dialogs appear without the main window pinned above them.
- Signed update installation still requires approval and does not restart the macro.
- Resize Roblox to 1680 x 945 and move it to the top left corner when a run
  starts, using the ULT Autoresizer by hesgly. Docked and fullscreen games are left alone.

## 1.4.0.39

- Reuse the scaled backdrop and drawing buffers so hovering, switching tabs
  and resizing do less work. Paint a fresh frame before showing a page.

- Add a private server invite field under Settings. Save a Roblox TDS invite
  and use Join private server before starting. New launches and disconnect
  recovery use the same saved invite; forget it to go back to public TDS.
- Windows protects the saved invite for the current account. The link does not
  go into engine settings, exported profiles, or Output logs.

## 1.4.0.38

- Hardcore map search reads only the selected Roblox client. It no longer
  mistakes the macro's nearby strategy title for a map board when docked.
  Weak or unconfirmed terrain matches stop before strategy placements.
- Keep recorded tower placements aligned with the map in tall/docked windows.
  World X uses the game's vertical field of view; HUD scaling stays separate.
  A point outside the current view stops with a clear message, and blocked-tile
  retries remain local instead of doubling across the map.
- Close the previous tower panel before switching upgrade or sell targets,
  including when it covers the next tower in a narrow window. Selling a replayed
  tower no longer assumes it has a recording-window handle.
- If timescale tickets run out, cancel the identified ticket dialog and keep
  playing at normal speed. Do not retry tickets in subsequent matches of the
  same Start; a new Start retries the user's saved preference.
- An unavailable or delayed optional timescale confirmation no longer restarts
  the macro. Count ticket usage only after its confirmation closes. Never click
  Get More or guess a missing Cancel button.
- Rebuild the workspace layout from the actual client size when startup ends,
  including when animations are disabled.
- Keep OFF and the first dropdown choices visible when the whole list fits.

## 1.4.0.37

- Strategy rotation checks only its two assigned slots, even in a large library.
- Restore the modified reference's 10 ms mouse / 20 ms key timing. Inventory
  clicks use the configured movement speed, settle before pressing, map through
  the captured client's physical origin and hold for 100 ms.
  A missed action gets one retry only while the same owned button still offers
  that action on two fresh observations. Covered controls receive no click.
- Easy and Casual keep their separate cards in the Survival menu.
- Advanced settings and Match options scroll their newly opened section into view.
- Offscreen edit controls stay hidden, and repeated layout passes no longer move
  unchanged native fields or scroll a field while arranging the page.
- Valid recording shortcuts save when leaving a field. Invalid or conflicting
  shortcuts keep the last working bindings and show the reason in Settings.
- Lobby detection accepts the current Play label instead of restarting solely
  because the old image does not match. A verified open inventory can proceed
  directly to auto-equip. Relaunch keeps the launcher's docked bounds.
- Wait for a responsive replacement game window with stable geometry before
  docking it. A newly visible boot window is no longer treated as ready.
- Undocked relaunch retains maximized mode or the previous windowed bounds.
  Undocking after a relaunch still restores the original pre-dock layout.
- Compact clients retain the full Override Map caption and Add Modifier tooltip.
- Auto-equip focuses inside the search field, uses the modified reference's
  literal text entry, then checks the selected tower and owned action.
- Compact title checks tolerate a HUD-obscured ending only after six exact
  leading letters on two observations. Different names and roles do not pass.
- Compact inventory recognition pairs the current close glyph with the search
  anchor on two stable frames instead of rejecting the menu on the old glyph alone.
- Items entry retries its exact label at fixed OCR scales when the retired icon
  or a single raster size does not match after a relaunch.
- Clearing follows the current action row, tolerates wrapped descriptions and
  covers the first and fifth slots in tall docked clients. The current button
  row anchors the strip; fixed OCR scales handle different caption rasterization.
  The exact DJ Booth card caption is accepted for a strategy's DJ requirement.
- Remove the retired white-pixel/topbar chat click, which could select unrelated
  Roblox controls. Close chat manually before starting if it covers the game.
- Closing the app disconnects paint handlers and queued drawing timers before
  freeing the graphics resources.

The Windows capture indicator may appear during target-window OCR. It is not
suppressed by changing Windows security or capture permissions. These changes
do not make old strategies compatible with every TDS tower or balance update.

## 1.4.0.36

- The lobby selector checks the Survival icon as well as its label and scrolls
  the confirmed mode menu to find cards below the first row.
- Narrow Roblox windows use the full-width menu layout, including the far-left
  Survival tab and right-hand Frost card while docked.
- Squad selection can use the card label when the artwork does not match.
- Restoring a docked layout on startup refreshes the app to its new size.
- Import older settings recognizes 1.3.6 `.ump` profiles. It imports supported
  preferences only, leaving strategies and private fields untouched.
- Modifier setup checks the map-vote screen, then hovers over the Add Modifier
  icon to verify its tooltip before clicking the icon.

## 1.4.0.35 release candidate

- Docking reports whether Windows applied the layout. A rejected or stalled
  move no longer leaves the controls stuck. Restore avoids windows the user
  has moved or the macro cannot identify.
- Playback waits for the new docking position after a Roblox relaunch.
- Manual update review blocks playback and duplicate checks. Settings shows
  the outcome of background checks, or that automatic checks are off.
- Rapid window resizing cannot expose a half-built drawing buffer to queued
  paints. Scrollbar geometry stays inside short panels, and the Output drawer
  opens at compact heights without an integer conversion error.
- The backdrop blends in a single pass to avoid the live docking repaint crash.
- When the older Items icon does not match, auto-equip checks the exact Items
  label in its lobby control region before clicking. The inventory search and
  close controls must then stay visible in the same positions across two frames.
- Equipment verification moves the pointer off the button so hover colors
  do not hide the result, with a same-row label check as a fallback. Search
  sends paced keystrokes and checks the tower name before equipping. Visible
  cards can be selected without typing a search when their label is unambiguous.

## 1.4.0.34 preview

- The updater retries the whole manifest/signature pair once if the server
  changes offers between the two requests. An invalid signature still fails.
- Packages that use a path as both a file and a folder are rejected before
  the install prompt. Background downloads and explicit install approval remain.

## 1.4.0.23-ahk1

### Fixes (round 3)
- Auto equip failed with "The selected game could not be read for inventory verification" when the macro window (always on top) covered Roblox: the engine refuses to read the game through any overlapping window. Starting a run now minimizes the macro whenever it overlaps Roblox, including F1 starts from inside Roblox and docked layouts that still overlap.
- Engine patch A14: the error now says when another window covers the inventory (with its position) and the capture stage otherwise, instead of the generic message.

### Fixes (round 2)
- Fixed the GDI+ access violation (0xc0000005 in Gfx.ahk) when resizing the window or switching the Christmas theme. The background was drawn from a cached bitmap that a resize or theme change could free mid-paint; that cache is gone and painting is now uninterruptible.
- Flat background like the Python window. The faded scenery is off by default (existing profiles are migrated); it is still available as an opt-in under Settings > Theme background.
- Sidebar matches the Python layout: "Library" caption above the list, regular-weight strategy titles.

## Port

- The Python/Qt window (`ultmacro_ui/window.py`) is rebuilt in AutoHotkey v2 with
  a small GDI+ widget toolkit: same pages (Run, Record, Party, Discord, Tools,
  Settings), same layout metrics, charcoal/lavender palette, Christmas theme,
  translucent cards over the Alpine backdrop, toggles, 2 px corners, two-line
  strategy rows with slot badges, compact layout under 740 px, boot stage,
  window opacity, startup sounds and community translations.
- The C# `LegacyHost`/`EngineController`/`EngineWorkspace` are ported to
  `app\Engine.ahk`: session-scoped WM_COPYDATA protocol, build check, adoption of
  relaunched engines, 8 s stop grace, emergency termination, held-input release,
  session revocation and the outside-engine Roblox relaunch for disconnects.
- Webhook notifications, the personal bot remote (!stop/!status/!start/!screenshot)
  and the official UltBot `/remote link` relay are ported with async WinHTTP.
- Docking, Roblox launch, legacy settings import, Output export, strategy import
  and the crate utility are ported.
- The engine is rebuilt from `legacy-133a` with the repository's own
  `EnginePatcher` (132 anchored patches) plus 13 recorder patches (see
  `engine\ENGINE-NOTICE.md`). Native DLLs and the interpreter come from 1.3.3a.

## Fixes and improvements over the hybrid build

- Recording no longer needs the Python recorder: the engine recorder is driven
  from the UI. Placement uses the Ctrl+1–5 slot and an automatic tower ID instead
  of two blocking InputBoxes; F2 in Roblox keeps a draft instead of opening the
  legacy save dialogs.
- "Run and record action" and "Record sell clicks" now work with the engine
  (new `recordstep` verb; sell clicks need a positive Sell-button match).
- The recording map list only offers maps the engine can actually select, and
  all engine modes are available (Casual, Voidcore, Pizza Party, …).
- Stopping a recording always keeps the draft (Stop button, F2 and F8).
- The launcher never treats itself as an engine process when it runs on the
  bundled interpreter.
- A terminal engine error ends the run immediately instead of waiting 30 s.
- Dialog default buttons carry the accent, never the destructive choice.
- Settings are validated field by field; a bad value only resets itself.
