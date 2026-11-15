import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
for (const script of ['Main.ahk', 'submacros/watchdog.ahk', 'submacros/auto_spin.ahk', 'submacros/auto_open_consumable.ahk', 'submacros/remote_screenshot.ahk']) {
  const result = spawnSync(resolve(root, 'submacros/AutoHotkey64.exe'), ['/ErrorStdOut', '/Validate', script], { cwd: root, windowsHide: true, encoding: 'utf8', timeout: 20000 });
  assert.equal(result.status, 0, script + ': ' + (result.error?.message || '') + result.stdout + result.stderr);
  console.log('PASS: ' + script);
}
const helper = spawnSync(resolve(root, 'updater/UltimateMacro.AhkUpdater.exe'), ['--self-test'], { cwd: root, windowsHide: true, encoding: 'utf8', timeout: 45000 });
process.stdout.write((helper.stdout || '') + (helper.stderr || ''));
assert.equal(helper.status, 0, helper.error?.message || 'Updater safety tests failed');
