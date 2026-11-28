import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Load-check every entry script with the bundled AutoHotkey v2 runtime.
// /Validate parses the script and all of its #Includes without running it.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const runtime = resolve(root, 'submacros/AutoHotkey64.exe');
const scripts = [
  'Main.ahk',
  ...readdirSync(resolve(root, 'submacros'))
    .filter((name) => name.toLowerCase().endsWith('.ahk'))
    .sort()
    .map((name) => 'submacros/' + name),
];

for (const script of scripts) {
  const result = spawnSync(runtime, ['/ErrorStdOut', '/Validate', script], {
    cwd: root,
    windowsHide: true,
    encoding: 'utf8',
    timeout: 20000,
  });
  assert.equal(result.status, 0, script + ': ' + (result.error?.message || '') + result.stdout + result.stderr);
  console.log('PASS: ' + script);
}
console.log(`All ${scripts.length} scripts loaded cleanly.`);
