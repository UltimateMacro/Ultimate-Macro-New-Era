import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, basename } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const worker = join(here, '..', 'app', 'DashboardHealthWorker.ps1');
const ps = join(process.env.WINDIR, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
const parse = spawnSync(ps, ['-NoProfile', '-NonInteractive', '-Command', '& { param($file) $tokens=$null; $parseErrors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$parseErrors); if($parseErrors.Count) { $parseErrors | ForEach-Object {$_.Message}; exit 1 } }', worker], { windowsHide: true, encoding: 'utf8', timeout: 15000 });
assert.equal(parse.status, 0, parse.stderr + parse.stdout);
const parent = realpathSync(tmpdir()), fixture = mkdtempSync(join(parent, 'ultmacro-health-qa-'));
const path = join(fixture, 'health.json');
const child = spawn(ps, ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', worker, '-ParentPid', String(process.pid), '-OutputPath', path], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
let errors = '';
child.stderr.on('data', data => { errors += data.toString(); });
try {
  const until = Date.now() + 45000;
  while (!existsSync(path) && Date.now() < until && child.exitCode === null) await new Promise(resolve => setTimeout(resolve, 250));
  assert(existsSync(path), 'Real hidden health worker produced no output: ' + errors);
  const data = JSON.parse(readFileSync(path, 'utf8'));
  assert(Date.now() - Date.parse(data.sampledAt) >= -5000 && Date.now() - Date.parse(data.sampledAt) < 45000);
  assert(readFileSync(path).length <= 16384);
  for (const field of ['cpuPercent', 'gpuPercent']) assert(data[field] === null || (Number.isFinite(data[field]) && data[field] >= 0 && data[field] <= 100));
  assert(data.memoryUsedBytes === null || data.memoryUsedBytes >= 0 && data.memoryUsedBytes <= data.memoryTotalBytes);
  assert(Array.isArray(data.processes) && data.processes.length <= 8);
  assert(Array.isArray(data.temperatures) && data.temperatures.length <= 4);
  for (const row of data.processes) {
    assert(row.pid > 4 && row.pid !== process.pid && row.pid !== child.pid);
    assert.match(row.startedAt, /^\d{14}$/);
    assert(Number.isFinite(row.cpuPercent) && row.cpuPercent >= 0 && row.cpuPercent <= 100);
    assert(Number.isSafeInteger(row.memoryBytes) && row.memoryBytes >= 0);
  }
  for (const row of data.temperatures) assert(row.source === 'LibreHardwareMonitor' && row.celsius >= 0 && row.celsius < 130);
  writeFileSync(join(here, 'Health-QA-results.json'), JSON.stringify({ passed: true, sampledAt: data.sampledAt, bytes: readFileSync(path).length, processes: data.processes.length, temperatures: data.temperatures.length, parserPassed: true }, null, 2));
  console.log('PASS: real hidden health worker; timestamp, size, CPU/GPU/RAM, process identities, temperature schema, parent exclusion and parser.');
} finally {
  if (child.exitCode === null) child.kill();
  if (child.exitCode === null) await new Promise(resolve => child.once('exit', resolve));
  assert.equal(dirname(realpathSync(fixture)), parent);
  assert(basename(fixture).startsWith('ultmacro-health-qa-'));
  rmSync(fixture, { recursive: true, force: true, maxRetries: 8, retryDelay: 200 });
}
