import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=join(dirname(fileURLToPath(import.meta.url)),'..');
const read=name=>readFileSync(join(root,name),'utf8').replaceAll('\r\n','\n');
const watchdog=read('submacros/watchdog.ahk');
const get=name=>{const m=watchdog.match(new RegExp('^'+name+'\\([^\\n]*\\) \\{[^]*?^\\}','m'));assert(m,'Missing '+name);return m[0];};
const finish=get('FinishDetectedMatch');
const restart=get('RestartMain').replace(/\bRun\(/g,'QaRun(').replace(/\bExitApp\(/g,'QaExitApp(');
const match=read('app/DashboardMatch.ahk');
const stop=match.match(/^    static ApplyStop\(state\) \{[^]*?^    \}/m)?.[0].replace('    static ApplyStop(','QaApplyStop(');
assert(stop);
for(const code of [finish,restart,stop]) assert(!code.includes('ScrollDownAmount'),'Map scrolling must not control match repeat');
const skin=read('ui/LegacySkin.ahk');
assert(skin.includes('Label("Map-list scroll steps")'));
assert(skin.includes('This does not limit matches.'));
assert(skin.includes('No fixed match-count limit.'));
const harness=`
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Warn All, StdOut
ProcessSetPriority("BelowNormal")
OnError(QaFail)
global StateFile := A_ScriptDir "\\state.ini", SettingsFile := A_ScriptDir "\\settings.ini", MainPID := 123
global WebhookEnabled := false, WebhookLink := "", QaPaired := false, QaStop := false, Q := {}, checks := 0
IniWrite("OFF", SettingsFile, "Webhook", "Enabled")
QaFail(err,*) {
    FileAppend("FAIL: " err.Message " at line " err.Line "\x60n", "**")
    ExitApp(1)
}
Need(ok,label) {
    global checks
    if !ok
        throw Error(label)
    checks++
}
for paired in [false,true] {
    QaPaired := paired
    Q := {restarts:0,closes:0,exits:0,published:0}
    Loop 60 {
        IniWrite(1, StateFile, "State", "Running")
        IniWrite(A_Index, StateFile, "State", "TotalMatches")
        FinishDetectedMatch(Mod(A_Index,3) ? "Triumph" : "Loss", {})
        Need(Q.restarts = A_Index && Q.closes = A_Index && Q.exits = A_Index, "Every match, including 20 and 21, uses the original relaunch path")
        Need(IniRead(StateFile,"State","Running",0) = 1, "No implicit match-count stop")
        Need(Q.published = (paired ? A_Index : 0), "Existing paired/unpaired result behavior stays intact")
    }
}
QaStop := true
IniWrite(1, StateFile,"State","Running")
FinishDetectedMatch("Triumph",{})
Need(IniRead(StateFile,"State","Running",1) = 0 && !QaStop, "Explicit dashboard stop is still honored and consumed")
FileAppend("PASS: " checks " assertions across 120 inert match-end/relaunch decisions and explicit stop; no real game, process control, focus, input, capture or network.\x60n", "*")
ExitApp(0)
class OwnedParent {
    static Close() => Q.closes++
}
class DashboardMatch {
    static Linked() => QaPaired
    static StopPending() => QaPaired && QaStop
    static SetStop(value) {
        global QaStop
        QaStop := value
    }
    static ApplyStop(state) => QaApplyStop(state)
    static Publish(*) => Q.published++
}
QaRun(command) {
    if !InStr(command,"Main.ahk") || !InStr(command,"AutoHotkey64.exe")
        throw Error("Unexpected relaunch target")
    Q.restarts++
}
QaExitApp(*) => Q.exits++
GetRobloxHWND(*) => 0
WinActive(*) {
    throw Error("Background regression must not inspect foreground apps")
}
CloseMain(*) {
    throw Error("Background regression must not close apps")
}
SendInfo(*) {
    throw Error("Background regression must not send webhooks")
}
`;
const parent=realpathSync(tmpdir()),scratch=mkdtempSync(join(parent,'ultmacro-run-options-qa-'));
try {
  const path=join(scratch,'RunOptions-QA.ahk');
  writeFileSync(path,'\ufeff'+harness+'\n'+finish+'\n'+restart+'\n'+stop);
  const result=spawnSync(join(root,'submacros/AutoHotkey64.exe'),['/ErrorStdOut',path],{cwd:scratch,windowsHide:true,timeout:30000,encoding:'utf8'});
  process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');
  assert(!result.error,String(result.error));assert.equal(result.status,0);
} finally {
  assert(dirname(realpathSync(scratch))===parent && scratch.startsWith(join(parent,'ultmacro-run-options-qa-')));
  rmSync(scratch,{recursive:true});
}
