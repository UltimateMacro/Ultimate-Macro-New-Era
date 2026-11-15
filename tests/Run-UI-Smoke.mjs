import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { basename, dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, '..');
const recorderMode = process.argv.includes('--recorder');
const residentMode = process.argv.includes('--resident');
const shortcutMode = process.argv.includes('--shortcuts');
const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const once = (source, from, to) => {
  assert.equal(source.split(from).length, 2, 'Missing unique UI fixture anchor: ' + from);
  return source.replace(from, () => to);
};
const parent = realpathSync(tmpdir()), fixture = mkdtempSync(join(parent, 'ultmacro-ui-qa-'));
try {
  cpSync(source, fixture, { recursive: true, filter: path => !['.git', 'tests', '.github'].includes(basename(path)) });
  let main = read(join(source, 'Main.ahk')).replace('#Include engine\\UM14Engine.ahk', '') + read(join(source, 'engine', 'UM14Engine.ahk'));
  main = once(main, 'OnError(MacroErrorHandler)', 'OnError(QaUiError)\nSuspend(true)\n#NoTrayIcon');
  const from = main.indexOf('LegacyConnectionsStart(A_AppData "\\Ultimate_Macro\\Connections-14"');
  const to = main.indexOf('global MainGui := Gui(', from);
  assert(from > 0 && to > from);
  main = main.slice(0, from) + 'QaUiSetup()\n' + main.slice(to);
  main = once(main, 'A_AppData "\\Ultimate_Macro\\Options"', 'A_ScriptDir "\\fixture-data\\Options"');
  main = once(main, 'A_AppData "\\Ultimate_Macro\\state.ini"', 'A_ScriptDir "\\fixture-data\\state.ini"');
  main = once(main, 'if FileExist(IconPath)\n    TraySetIcon(IconPath)', '');
  main = once(main, 'MW.Open()\nInstallResidentTrayMenu()\nSetTimer(Hoverwatchdog, 10)\nSetTimer(() => CheckForUpdates(false), -1500)', 'MW.Open(false)\nQaUiTest()');
  main = once(main, '~F1:: StartStrategy(0, 0)\n~F2:: StopStrategy(0, 0)', '');
  main = once(main, '\nStartStrategy(*) {', '\nStartStrategy(*) => QaUnexpectedRun()\nUnusedLegacyStart(*) {');
  main = once(main, '\nStopStrategy(*) {', '\nStopStrategy(*) => QaUnexpectedRun()\nUnusedLegacyStop(*) {');
  if (shortcutMode) {
    main = once(main, 'MW.Open(false)\nQaUiTest()', 'QaShortcutSeed()\nMW.Open(false)\nQaShortcutTest()');
    main += '\n#Include Shortcut-QA.ahk\n';
    writeFileSync(join(fixture, 'Shortcut-QA.ahk'), read(join(here, 'Shortcut-QA.ahk')));
  }
  if (residentMode) {
    // Exercise the real tray callbacks, with only the actual foreground-show,
    // hover polling and process-exit boundaries neutralized in this temp copy.
    main = once(main, 'MW.Open(false)\nQaUiTest()', 'MW.Open(false)\nQaResidentTest()');
    const start = main.indexOf('\nShowResidentMacro(*) {');
    const end = main.indexOf('\nDiscordLink(ctrl, *) {', start);
    assert(start > 0 && end > start);
    const callbacks = main.slice(start, end)
      .replace('MW.Open()', 'MW.Open(false)')
      .replace('MW.gui.Show()', 'QaHiddenShow()')
      .replace('SetTimer(Hoverwatchdog, 10)', '; No mouse polling in background QA')
      .replace('ExitApp()', 'QaExitCalled := true')
      .replace('global RunningStrategy', 'global RunningStrategy, QaExitCalled');
    main = main.slice(0, start) + callbacks + main.slice(end);
    const prompt = main.match(/MsgBox\(requiredTowers, "Required Towers", (.+)\)/)?.[1];
    assert(prompt, 'Missing original required-towers prompt');
    main += '\nQaRealPromptOptions(remoteStart) => ' + prompt + '\n#Include Resident-QA.ahk\n';
    writeFileSync(join(fixture, 'Resident-QA.ahk'), read(join(here, 'Resident-QA.ahk')));
  }
  if (recorderMode) {
    const replaceCalls = text => {
      const names = new Set(['InputBox','ModernMsgBox','MsgBox','ActivateRoblox','MouseGetPos','GetRobloxHWND','getRobloxPos','MouseMove','Click','Send','SendEvent','Sleep','HyperSleep','ScaleX','ScaleY','AdvancedImageSearch','waitForTowerUI','UpdateTowerIndicator','DeleteAllIndicators','ShowTowerPathDialog','WinClose','PixelSearch','SellTower','SpawnTower','UpgradeTower','CloneTower','BrawlerReposition','ActivateRaiseTheDead','ChangeTargets','SetDJTrack','AlignCamera','ToggleAutoskip','InputHook']);
      let result = '', quoted = '', comment = false;
      for (let i = 0; i < text.length;) {
        const ch = text[i];
        if (comment) { result += ch; i++; if (ch === '\n') comment = false; continue; }
        if (ch === '`') { result += text.slice(i, i + 2); i += 2; continue; }
        if (quoted) { result += ch; i++; if (ch === quoted) quoted = ''; continue; }
        if (ch === '"' || ch === "'") { quoted = ch; result += ch; i++; continue; }
        if (ch === ';') { comment = true; result += ch; i++; continue; }
        const word = /^[A-Za-z_][A-Za-z0-9_]*/.exec(text.slice(i))?.[0];
        if (word) { result += names.has(word) && /^\s*\(/.test(text.slice(i + word.length)) ? 'Qa' + word : word; i += word.length; continue; }
        result += ch; i++;
      }
      return result;
    };
    const legacy = join(fixture, 'app', 'LegacyRecorder.ahk');
    writeFileSync(legacy, replaceCalls(read(legacy)));
    const bridge = join(fixture, 'app', 'RecorderBridge.ahk');
    let bridgeText = read(bridge).replace('A_AppData "\\Ultimate_Macro\\Recordings"', 'A_ScriptDir "\\fixture-data\\Recordings"');
    bridgeText = bridgeText.replace(/RecorderGameFocused\(\) \{[\s\S]*?\n\}/, 'RecorderGameFocused() => QaFocus');
    writeFileSync(bridge, bridgeText);
    const begin = main.indexOf('ExecuteStep(step) {'), end = main.indexOf('\nLowerGraphics() {', begin);
    assert(begin > 0 && end > begin);
    main = main.slice(0, begin) + replaceCalls(main.slice(begin, end)) + main.slice(end);
    main = main.replace('QaExecuteStep(step) {', 'ExecuteStep(step) {');
    const rb = main.indexOf('~RButton:: {'), rbEnd = main.indexOf('\nglobal ActivePathSelectTowerID', rb);
    assert(rb > 0 && rbEnd > rb);
    main += '\n' + replaceCalls(main.slice(rb, rbEnd).replace('~RButton:: {', 'QaRightButton() {'));
    main = main.replace('MW.Open(false)\nQaUiTest()', 'MW.Open(false)\nQaRecorderTest()');
    main += '\n#Include Recorder-QA.ahk\n';
    writeFileSync(join(fixture, 'Recorder-QA.ahk'), read(join(here, 'Recorder-QA.ahk')));
  }
  main += `
QaUiError(err, *) {
    FileAppend("FAIL: " err.Message " at " err.File ":" err.Line " (" err.What ")\x60n" err.Stack "\x60n", "**")
    ExitApp(1)
}
QaUnexpectedRun(*) {
    throw Error("UI smoke test must never run gameplay")
}
class NoWire {
    static Begin(*) => QaUnexpectedRun()
    static Check(*) => QaUnexpectedRun()
}
QaUiSetup() {
    DashboardMatch.root := A_ScriptDir "\\fixture-data\\connections"
    DashboardHealth.output := DashboardMatch.root "\\health.json"
    DashboardActivity.dir := DashboardMatch.root "\\activity"
    DashboardRemote.cooldownFile := DashboardMatch.root "\\cooldown.ini"
    Dashboard.Init(DashboardMatch.root, App.RELEASE, "", NoWire)
    UpdateHelper.Initialize(SettingsFile, App.UPDATE_VERSION)
}
QaUiTest() {
    ProcessSetPriority("BelowNormal")
    try {
        if !MW.gui || !MW.ready
            throw Error("Hidden UI did not finish constructing")
        if MW.mapScrollLabel.text != "Map-list scroll steps"
            || !InStr(MW.mapScrollHelp.text, "This does not limit matches.")
            || !InStr(MW.repeatHelp.text, "No fixed match-count limit.")
            throw Error("Run options still imply a match-count field")
        ScrollDownAmountCtrl.Text := "99"
        OnScrollDownAmountChange()
        if ScrollDownAmount != 20 || IniRead(SettingsFile, "Options", "ScrollDownAmount", -1) != 20
            throw Error("Original bounded map-scroll preference did not persist")
        ScrollDownAmountCtrl.Text := "7"
        OnScrollDownAmountChange()
        if ScrollDownAmount != 7 || IniRead(SettingsFile, "Options", "ScrollDownAmount", -1) != 7
            throw Error("Valid map-scroll preference did not persist")
        for size in [[1100, 800], [720, 540], [1366, 768], [900, 680]] {
            MW.OnSize(0, size[1], size[2])
            Sleep(75)
            Loop MW.pages.Length {
                MW.SelectPage(A_Index, false)
                Sleep(20)
            }
        }
        MW.SelectPage(2, false)
        if MW.tabs[2].text != "Record" || !MW.recordStart.IsEnabled() || MW.recordStop.IsEnabled()
            throw Error("Record tab or idle recording controls missing")
        MW.SelectPage(4, false)
        if AutoCloseChat != 1 || AutoCloseChatCtrl.Value != 1
            throw Error("Automatic chat close is not on by default")
        foundChat := false
        for mirror in MW.mirrors {
            if mirror.model = AutoCloseChatCtrl {
                foundChat := true
                if !mirror.view.checked
                    throw Error("Chat-close setting is not visibly enabled")
            }
        }
        if !foundChat
            throw Error("Settings is missing the chat-close toggle")
        AutoCloseChatCtrl.Value := 0
        EnableAutoCloseChat()
        if AutoCloseChat != 0 || IniRead(SettingsFile, "Options", "AutoCloseChat", -1) != 0
            throw Error("Disabled chat-close preference did not save")
        AutoCloseChatCtrl.Value := 1
        EnableAutoCloseChat()
        if AutoCloseChat != 1 || IniRead(SettingsFile, "Options", "AutoCloseChat", -1) != 1
            throw Error("Enabled chat-close preference did not save")
        if !MW.dashboardCode.password || MW.dashboardLink.IsEnabled() != Dashboard.CanConnect || MW.dashboardUnlink.IsEnabled()
            throw Error("Dashboard settings control state is wrong")
        MW.dashboardCode.Text := "bad"
        MW.LinkDashboard()
        if MW.dashboardCode.Text != "" || IsObject(Dashboard.pending)
            throw Error("Dashboard code was retained or invalid input caused HTTP")
        for state in ["connecting", "connected", "offline", "expired", "disconnected"] {
            Dashboard.SetState(state, "QA " state)
            MW.ConnectionChanged()
        }
        FileAppend("PASS: hidden complete UI startup, 4 sizes x 7 pages, restored Record tab, masked/cleared dashboard field and connection states; no game input or HTTP.\x60n", "*")
        ExitApp(0)
    } catch as err
        QaUiError(err)
}
`;
  // Read the real state-change adapter name rather than invent a UI callback.
  const skin = read(join(source, 'ui', 'LegacySkin.ahk'));
  assert(skin.includes('static ConnectionChanged() {') && skin.includes('MW.dashboardStatus.SetText(Dashboard.message)'), 'Cannot locate dashboard UI state adapter');
  writeFileSync(join(fixture, 'Main-UI-QA.ahk'), '\ufeff' + main);
  const result = spawnSync(join(fixture, 'submacros', 'AutoHotkey64.exe'), ['/ErrorStdOut', 'Main-UI-QA.ahk'], { cwd: fixture, windowsHide: true, encoding: 'utf8', timeout: residentMode ? 60000 : 25000 });
  const output = (result.stdout || '') + (result.stderr || '');
  const suite = recorderMode ? 'Recorder' : residentMode ? 'Resident' : shortcutMode ? 'Shortcut' : 'UI';
  writeFileSync(join(here, suite + '-QA.log'), output);
  process.stdout.write(output);
  assert.equal(result.status, 0, result.error?.message || 'Hidden UI smoke failed');
  assert.match(output, recorderMode ? /SUCCESS: \d+ recorder round-trip assertions/ : residentMode ? /SUCCESS: \d+ resident lifecycle assertions/ : shortcutMode ? /SUCCESS: \d+ shortcut regression assertions/ : /PASS: hidden complete UI startup/);
  writeFileSync(join(here, suite + '-QA-results.json'), JSON.stringify({ passed: true, testedAt: new Date().toISOString(), assertions: recorderMode || residentMode || shortcutMode ? Number(output.match(/SUCCESS: (\d+)/)[1]) : undefined, sizes: 4, pages: 7, recordTab: true, noGameInput: true, noHttp: true }, null, 2));
} finally {
  assert.equal(dirname(realpathSync(fixture)), parent);
  assert(basename(fixture).startsWith('ultmacro-ui-qa-'));
  rmSync(fixture, { recursive: true, force: true, maxRetries: 8, retryDelay: 200 });
}
