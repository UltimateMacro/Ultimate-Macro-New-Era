import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = name => readFileSync(join(root, name),'utf8').replaceAll('\r\n','\n');
const engine = read('engine/UM14Engine.ahk');
const functions = new Map([...engine.matchAll(/^([A-Za-z_][\w]*)\([^\n]*\)\s*\{[^]*?^\}/gm)].map(m=>[m[1].toLowerCase(),m[0]]));
// Hashes of complete functions in the owner's supplied, pinned 1.3.3.10 ZIP.
// Only separate dashboard activity notifications are removed for comparison.
const expected = {
  EquipTowers:'97f3562f3143992de45aa1279a8d24ad1d05421aa640f9ea8c42fa4ef1ef85f9',
  JoinGame:'9fac6982052f61f8e3a0e2848f01780115e51cc28b7e7651333af2cc10568015',
  SelectMap:'90181c20b79ff66a6f853859e87a4c5e38a13fa9a3c86929715da811a0642305',
  RunStrategy:'f53c02e6a51668cb2e20fa05a295e669cc6481b1592aeac2aa5712f346406187',
  PlayStrategy:'89ab1d8089faa2d5be8e7196f95ea378336ea800cb5455bbf4ca74451b28fcd5',
  SpawnTower:'9efce5fb84e3034e3b133a30da3239d79bbefa961c617a374b28a394222a7ee9',
  UpgradeTower:'d6ab7a2b27bda4900887df3987879efe97eaf6b0bb278739edf25b1e76d018a6',
  CheckRestart:'67b68e38d1b4083c58c5f5c7c38a3bbd66cffea8ae24746c946f30d17c24f816',
  CheckTheMapF:'74f84954395eef4815fc77908c8bf81e5e3aa16b650c8acf560e078182f4da5b',
  activateTimescale:'af655be1baf643505954e1a151f23c26770a25c362264b1cd0e56f087bd74e62',
  UseAbilities:'5f23e50ec2540b57c486aec7078e291b4ea656f2f93ee61c4adf758692a92b0c',
  AlignCamera:'f1ac7615554aabb32006591eb5305b0a15419b628aaf3b1b6c07b06bef80cc90'
};
for(const [name, digest] of Object.entries(expected)) {
  const actual = functions.get(name.toLowerCase());
  assert(actual, name);
  const gameplay = actual.replace(/^\s*Dashboard(?:Match\.Started|Activity\.(?:SessionStarted|Succeeded))\([^\n]*\)\n/gm,'');
  assert.equal(createHash('sha256').update(gameplay).digest('hex'),digest,'Changed legacy gameplay: '+name);
}
let chat = functions.get('closechat');
assert(chat);
const legacyChat = chat.replace('    global AutoCloseChat\n    if (!AutoCloseChat)\n        return\n','')
  .replace('    hwnd := GetRobloxHWND()\n    if (!hwnd || !WinActive("ahk_id " DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")))\n        return\n','');
assert.equal(createHash('sha256').update(legacyChat).digest('hex'),'9c7066e99714b25193efacf7106343fbb1c4ca0611395bd4f1e4f112a8b6024e','Chat body must match the original 140px implementation');
assert(engine.includes('global AutoCloseChat := IniRead(SettingsFile, "Options", "AutoCloseChat", 1)'));
assert(read('ui/LegacySkin.ahk').includes('for model in [AutoCloseChatCtrl,'));
for(const name of ['EquipTowers','SelectMap','AlignCamera']) assert(functions.get(name.toLowerCase()).includes('closeChat()'));
for(const name of ['GetRobloxHWND','WinActive','DllCall','getRobloxPos','PixelGetColor','MouseGetPos','MouseMove','Sleep','Click','LogToConsole']) {
  chat = chat.replace(new RegExp('\\b'+name+'(?=\\()', 'g'), 'Qa'+name);
}
const harness = `
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Warn All, StdOut
ProcessSetPriority("BelowNormal")
OnError(QaFail)
global Q := {}, AutoCloseChat := 1, checks := 0
QaFail(err,*) {
    FileAppend("FAIL: " err.Message " line " err.Line "\x60n", "**")
    ExitApp(1)
}
Need(ok, label) {
    global checks
    if !ok
        throw Error(label)
    checks++
}
for mode in ["open", "closed", "other-game", "no-roblox", "disabled"] {
    Q := {mode:mode, reads:[], moves:[], clicks:0, waits:[], log:0}
    AutoCloseChat := mode != "disabled"
    closeChat()
    if mode = "open" {
        Need(Q.reads.Length = 1 && Q.reads[1][1] = 140 && Q.reads[1][2] = 29, "Detect at the original 140,29")
        Need(Q.moves.Length = 2 && Q.moves[1][1] = 140 && Q.moves[1][2] = 35 && Q.moves[1][3] = 2, "Original click location/speed")
        Need(Q.clicks = 1 && Q.waits.Length = 2 && Q.waits[1] = 100 && Q.waits[2] = 100, "Original one-click timing")
        Need(Q.moves[2][1] = 321 && Q.moves[2][2] = 123 && Q.log = 1, "Restore cursor and log")
    } else if mode = "closed" {
        Need(Q.reads.Length = 1 && Q.clicks = 0 && Q.moves.Length = 0, "Do not reopen closed chat")
    } else {
        Need(Q.reads.Length = 0 && Q.clicks = 0 && Q.moves.Length = 0, "No game input while disabled or another game is active")
    }
}
FileAppend("PASS: " checks " inert chat behavior checks; no game, focus, mouse, pixel capture or network touched.\x60n", "*")
ExitApp(0)
QaGetRobloxHWND() => Q.mode = "no-roblox" ? 0 : 423
QaDllCall(*) => 423
QaWinActive(*) => Q.mode != "other-game"
QagetRobloxPos(&x,&y,&w,&h) => (x:=0,y:=0,w:=1920,h:=1009)
QaPixelGetColor(x,y,*) {
    Q.reads.Push([x,y])
    return Q.mode = "open" && x = 140 && y = 29 ? 0xF4F5F8 : 0
}
QaMouseGetPos(&x,&y) => (x:=321,y:=123)
QaMouseMove(args*) => Q.moves.Push(args)
QaClick(*) => Q.clicks++
QaSleep(ms) => Q.waits.Push(ms)
QaLogToConsole(*) => Q.log++
`;
const parent = realpathSync(tmpdir()), scratch = mkdtempSync(join(parent,'ultmacro-chat-qa-'));
try {
  const path = join(scratch,'Chat-QA.ahk');
  writeFileSync(path,'\ufeff'+harness+'\n'+chat);
  const result = spawnSync(join(root,'submacros/AutoHotkey64.exe'),['/ErrorStdOut',path],{cwd:scratch,windowsHide:true,timeout:20000,encoding:'utf8'});
  process.stdout.write(result.stdout||''); process.stderr.write(result.stderr||'');
  assert(!result.error, String(result.error)); assert.equal(result.status,0);
  console.log('PASS: 12 pinned gameplay functions, original chat body, default-on UI and three integration call sites.');
} finally {
  assert(dirname(realpathSync(scratch))===parent && scratch.startsWith(join(parent,'ultmacro-chat-qa-')));
  rmSync(scratch,{recursive:true});
}
