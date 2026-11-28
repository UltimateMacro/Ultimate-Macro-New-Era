import { spawnSync } from 'node:child_process';
import { readdirSync, rmSync, writeFileSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Load-check every entry script with the bundled AutoHotkey v2 runtime.
// /Validate parses the script and all of its #Includes without running it.
// Each script is wrapped so warnings print to the log instead of opening a
// MsgBox, which would otherwise hang the runner until the timeout.
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const runtime = resolve(root, 'submacros/AutoHotkey64.exe');
const scripts = [
  'Main.ahk',
  ...readdirSync(resolve(root, 'submacros'))
    .filter((name) => name.toLowerCase().endsWith('.ahk'))
    .sort()
    .map((name) => 'submacros/' + name),
];

let failed = 0;
for (const script of scripts) {
  const target = resolve(root, script);
  const wrapper = resolve(dirname(target), '.ci-validate-' + basename(target));
  writeFileSync(wrapper, `#Warn All, StdOut\n#Include "${target}"\n`, 'utf8');
  let result;
  try {
    result = spawnSync(runtime, ['/ErrorStdOut', '/Validate', wrapper], {
      cwd: root,
      windowsHide: true,
      encoding: 'utf8',
      timeout: 30000,
    });
  } finally {
    rmSync(wrapper, { force: true });
  }

  const output = ((result.stdout || '') + (result.stderr || '')).trim();
  for (const line of output.split(/\r?\n/).filter(Boolean)) {
    const kind = /warning/i.test(line) ? 'warning' : 'error';
    console.log(`::${kind} file=${script}::${line}`);
  }
  if (result.error || result.status !== 0) {
    const why = result.error?.code === 'ETIMEDOUT'
      ? 'timed out (the script probably opened a dialog)'
      : result.error?.message || `exit code ${result.status}`;
    console.log(`::error file=${script}::${script} failed to load: ${why}`);
    failed++;
  } else {
    console.log('PASS: ' + script);
  }
}

if (failed) {
  console.log(`${failed} of ${scripts.length} script(s) failed to load.`);
  process.exit(1);
}
console.log(`All ${scripts.length} scripts loaded cleanly.`);
