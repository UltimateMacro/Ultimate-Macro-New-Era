(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);

  const els = {
    titlebar: $('titlebar'),
    brandIcon: $('brandIcon'),
    brandFallback: $('brandFallback'),
    docName: $('docName'),
    docDirty: $('docDirty'),
    docMap: $('docMap'),
    winMinBtn: $('winMinBtn'),
    winMaxBtn: $('winMaxBtn'),
    winCloseBtn: $('winCloseBtn'),

    openBtn: $('openBtn'),
    emptyOpenBtn: $('emptyOpenBtn'),
    saveCopyBtn: $('saveCopyBtn'),
    overwriteBtn: $('overwriteBtn'),
    undoBtn: $('undoBtn'),
    redoBtn: $('redoBtn'),
    modeVisualBtn: $('modeVisualBtn'),
    modeCodeBtn: $('modeCodeBtn'),
    codeView: $('codeView'),
    codeArea: $('codeArea'),
    codeGutter: $('codeGutter'),
    codeFileName: $('codeFileName'),
    codeIssue: $('codeIssue'),
    codeApplyBtn: $('codeApplyBtn'),
    codeRevertBtn: $('codeRevertBtn'),
    codeRefBtn: $('codeRefBtn'),
    codeRefSearch: $('codeRefSearch'),
    codeRefList: $('codeRefList'),
    replayStrategyBtn: $('replayStrategyBtn'),
    calibrationBtn: $('calibrationBtn'),

    mapPicker: $('mapPicker'),
    mapPickerBtn: $('mapPickerBtn'),
    mapPickerText: $('mapPickerText'),
    mapMenu: $('mapMenu'),
    mapSearch: $('mapSearch'),
    mapMenuList: $('mapMenuList'),
    importMapBtn: $('importMapBtn'),
    captureMapBtn: $('captureMapBtn'),

    layerSelect: $('layerSelect'),
    fitBtn: $('fitBtn'),
    footprintBtn: $('footprintBtn'),
    rangeBtn: $('rangeBtn'),
    zoomLabel: $('zoomLabel'),
    macroRootBtn: $('macroRootBtn'),
    macroStatus: $('macroStatus'),

    viewport: $('viewport'),
    emptyState: $('emptyState'),
    world: $('world'),
    mapImage: $('mapImage'),
    rangeLayer: $('rangeLayer'),
    footprintLayer: $('footprintLayer'),
    markerLayer: $('markerLayer'),
    calibrationLayer: $('calibrationLayer'),
    actionLayer: $('actionLayer'),
    viewportLoader: $('viewportLoader'),
    viewportLoaderText: $('viewportLoaderText'),

    xInput: $('xInput'),
    yInput: $('yInput'),
    applyXYBtn: $('applyXYBtn'),
    stageHint: $('stageHint'),

    portrait: $('portrait'),
    portraitSkeleton: $('portraitSkeleton'),
    portraitFallback: $('portraitFallback'),
    selectedName: $('selectedName'),
    metaSlot: $('metaSlot'),
    metaId: $('metaId'),
    metaPos: $('metaPos'),
    metaPlane: $('metaPlane'),
    metaRing: $('metaRing'),
    metaRange: $('metaRange'),
    metaStatus: $('metaStatus'),

    footprintValue: $('footprintValue'),
    footprintInput: $('footprintInput'),
    syncFootprintBtn: $('syncFootprintBtn'),
    resetFootprintBtn: $('resetFootprintBtn'),
    portraitStatusBadge: $('portraitStatusBadge'),
    refreshSelectedBtn: $('refreshSelectedBtn'),
    syncPortraitsBtn: $('syncPortraitsBtn'),

    tabPlacements: $('tabPlacements'),
    tabActions: $('tabActions'),
    tabStrategy: $('tabStrategy'),
    placementHeading: $('placementHeading'),
    placementCount: $('placementCount'),
    actionCount: $('actionCount'),
    panelPlacements: $('panelPlacements'),
    panelActions: $('panelActions'),
    panelStrategy: $('panelStrategy'),
    actionRows: $('actionRows'),

    replayBar: $('replayBar'),
    replayPlacedCount: $('replayPlacedCount'),
    replayUpgradingCount: $('replayUpgradingCount'),
    replayUpgradedCount: $('replayUpgradedCount'),
    replayFailedCount: $('replayFailedCount'),
    placementRows: $('placementRows'),

    resolutionInfo: $('resolutionInfo'),
    mapInfo: $('mapInfo'),
    mapImageInfo: $('mapImageInfo'),
    geometryInfo: $('geometryInfo'),
    geometryConfidenceInfo: $('geometryConfidenceInfo'),
    healthInfo: $('healthInfo'),
    encodingInfo: $('encodingInfo'),
    fileInfo: $('fileInfo'),

    statusText: $('statusText'),
    summaryText: $('summaryText'),
    toastStack: $('toastStack'),

    calibrationMarkHud: $('calibrationMarkHud'),
    calibrationMarkProgress: $('calibrationMarkProgress'),
    calibrationMarkTower: $('calibrationMarkTower'),
    calibrationMarkInstruction: $('calibrationMarkInstruction'),
    calibrationUndoMarkBtn: $('calibrationUndoMarkBtn'),
    calibrationReturnBtn: $('calibrationReturnBtn'),

    confirmModal: $('confirmModal'),
    confirmTitle: $('confirmTitle'),
    confirmBody: $('confirmBody'),
    confirmOkBtn: $('confirmOkBtn'),
    confirmCancelBtn: $('confirmCancelBtn'),

    calibrationModal: $('calibrationModal'),
    calibrationCloseBtn: $('calibrationCloseBtn'),
    calibrationBaselineBtn: $('calibrationBaselineBtn'),
    calibrationGoSandboxBtn: $('calibrationGoSandboxBtn'),
    calibrationManualBtn: $('calibrationManualBtn'),
    calibrationTowerSelect: $('calibrationTowerSelect'),
    calibrationMarkBtn: $('calibrationMarkBtn'),
    calibrationExportBtn: $('calibrationExportBtn'),
    calibrationReplayBtn: $('calibrationReplayBtn'),
    calibrationFolderBtn: $('calibrationFolderBtn'),
    calibrationSessionInfo: $('calibrationSessionInfo'),
    calibrationBaselineInfo: $('calibrationBaselineInfo'),
    calibrationManualInfo: $('calibrationManualInfo'),
    calibrationMarkCount: $('calibrationMarkCount'),
    calibrationScaleInfo: $('calibrationScaleInfo'),
    calibrationMacroInfo: $('calibrationMacroInfo'),
    calibrationRows: $('calibrationRows'),
  };

  const state = {
    doc: null,
    activeSlot: 0,
    selectedIndex: -1,
    selectedActionIndex: -1,
    scale: 1,
    fitScale: 1,
    offsetX: 0,
    offsetY: 0,
    panning: null,
    dragging: null,
    undo: [],
    redo: [],
    dirty: false,
    codeMode: false,
    codeEdited: false,
    map: null,
    mapCatalog: [],
    selectedMap: '',
    macroRoot: '',
    portraitCache: new Map(),
    mapPayloadCache: new Map(),
    portraitStatus: { total: 0, available: 0, missing: [] },
    markerEls: [],
    footprintEls: [],
    rangeEls: [],
    rowEls: [],
    actionEls: [],
    actionRowEls: [],
    actionDragging: null,
    collisionSet: new Set(),
    collisionPairs: new Set(),
    footprintsVisible: true,
    rangesVisible: false,
    mapAutoCaptureTried: new Set(),
    calibration: {
      open: false,
      marking: false,
      activeSlot: 1,
      marks: [],
      sessionPath: '',
      baselinePath: '',
      manualPath: '',
      clientWidth: 0,
      clientHeight: 0,
      autoPreparing: false,
      autoPreparedPath: '',
      macroVersion: '',
      cameraContract: '',
      solved: null,
    },
    replay: { state: '', epoch: 0, failedIds: new Set(), steps: new Map(), announced: new Map(), pollTimer: 0 },
  };

  const COMMAND_REFERENCE = [
    {
      name: 'File layout',
      signature: '[Info] / [Settings] / [DO NOT EDIT] / [Steps]',
      summary:
        'A .strat file is plain text split into sections. [Settings] holds the run configuration, [DO NOT EDIT] stores the resolution the strategy was recorded at, and [Steps] holds one command per line, executed top to bottom. [Info] is optional and only describes the strategy in the macro list.',
      params: [
        ['[Info]', 'Optional. Shown on the strategy card in the macro. See the Info keys entry below.'],
        ['[Settings]', 'key = value lines. See the Settings keys entry below.'],
        [
          '[DO NOT EDIT]',
          'width and height of the Roblox client when the strategy was recorded. Every coordinate in [Steps] is scaled from these numbers, so changing them moves every placement.',
        ],
        [
          '[Steps]',
          'The command list. Blank lines are ignored, and anything after a ; on a line is treated as a comment.',
        ],
      ],
      example:
        '[Settings]\nmap=Crossroads\ndifficulty=Molten\nrequiredTowers=Minigunner, Commander\n\n[DO NOT EDIT]\nwidth=1920\nheight=1080\n\n[Steps]\nSleep(2000)\nSpawnTower(960, 540, 1, Mini1)',
    },
    {
      name: 'Settings keys',
      signature: '[Settings] key = value',
      summary:
        'The configuration the macro reads before a run starts. Unknown keys are ignored, and any key left out falls back to the default shown here.',
      params: [
        ['map', 'Map name exactly as TDS spells it, for example Crossroads.'],
        ['difficulty', 'Casual, Easy, Intermediate, Molten, Fallen, Hardcore, Voidcore, or an Arcade / Trial name.'],
        [
          'requiredTowers',
          'Comma separated loadout in hotbar order. Prefix a tower with G for the golden version and R for the regular one, for example G Minigunner. Slot n in SpawnTower is the n-th tower here.',
        ],
        ['modifiers', 'Comma separated match modifiers to apply in the map menu. Leave empty for none.'],
        ['autoChain', 'ON or OFF. Spams Call of Arms during the run.'],
        ['autoCaravan', 'ON or OFF. Spams Support Caravan.'],
        ['autoDropTheBeat', 'ON or OFF. Spams Drop the Beat.'],
        ['autoSkip', 'ON or OFF, default ON. Presses the wave skip button when it appears.'],
        ['abilitySpam', 'ON or OFF, default ON. Allows abilities to be used between steps.'],
        ['moveEnabled', 'true or false. Walk after aligning the camera so the view is not blocked.'],
        ['moveDirection', 'W, A, S or D. Which way to walk when moveEnabled is true.'],
        ['moveDuration', 'How long to hold that key, in milliseconds. Default 750.'],
      ],
      example:
        'requiredTowers=G Minigunner, Commander, DJ\nmodifiers=Fog\nautoChain=ON\nmoveEnabled=true\nmoveDirection=S\nmoveDuration=750',
    },
    {
      name: 'Info keys',
      signature: '[Info] key = value',
      summary:
        'Optional description shown on the strategy card inside the macro. Nothing here changes how the run is played, so it is safe to edit freely.',
      params: [
        ['title', 'Name shown on the card. Defaults to the file name.'],
        ['author', 'Who made the strategy. Defaults to You for local recordings.'],
        ['desc', 'One or two lines describing the strategy or what it needs.'],
        ['time', 'Roughly how long a run takes, for example 6-7 minutes.'],
        ['income', 'What a run pays out, for example up to 5,000 coins per hour.'],
      ],
      example:
        '[Info]\ntitle=Coin + Any Tower EXP Farm\nauthor=gall\ndesc=Modifiers recommended, timescale optional.\nincome=up to 5,000 coins per hour\ntime=6-7 minutes',
    },
    {
      name: 'SpawnTower',
      signature: 'SpawnTower(x, y, slot, towerID)',
      summary:
        'Places a tower from the hotbar on the map and gives it an id. Every later command that touches this tower refers to it by that id.',
      params: [
        [
          'x',
          'Horizontal position in pixels, measured from the left edge of the Roblox client at the resolution in [DO NOT EDIT].',
        ],
        ['y', 'Vertical position in pixels, measured from the top edge.'],
        ['slot', 'Hotbar slot, 1 to 5. Slot n is the n-th tower in requiredTowers.'],
        [
          'towerID',
          'A name of your choice, such as Mini1 or dj. It has to be unique in the file. UpgradeTower, SellTower, ChangeTargets, CloneTower and BrawlerReposition all take this id.',
        ],
      ],
      note: 'This is the line the visual editor rewrites when a marker is dragged, so its x and y stay in sync with the map view.',
      example: 'SpawnTower(1063, 528, 1, Mini1)',
    },
    {
      name: 'UpgradeTower',
      signature: 'UpgradeTower(towerID [, skipOpen] [, amount] [, path] [, pathLevel])',
      summary:
        'Buys upgrades for a tower that is already placed. The macro opens the tower panel, waits until the upgrade is affordable and confirms each one.',
      params: [
        ['towerID', 'The id used in SpawnTower.'],
        [
          'skipOpen',
          'true or false, default false. Pass true when the tower panel is already open so the macro does not click the tower again.',
        ],
        ['amount', 'How many upgrades to buy in a row. Default 1.'],
        [
          'path',
          'Which upgrade path to take on a branching tower. Default 0, the top path. Only needed for towers that branch.',
        ],
        [
          'pathLevel',
          'The level at which the tower branches. Default 0. Used together with path so the macro knows when the choice appears.',
        ],
      ],
      example: 'UpgradeTower(Mini1)\nUpgradeTower(Mini1, false, 4)\nUpgradeTower(Ace1, false, 1, 2, 3)',
    },
    {
      name: 'SellTower',
      signature: 'SellTower(towerID)',
      summary: 'Sells a placed tower and frees its spot. The id stops being usable by later commands.',
      params: [['towerID', 'The id used in SpawnTower.']],
      example: 'SellTower(Scout1)',
    },
    {
      name: 'CloneTower',
      signature: 'CloneTower(towerID, x, y [, wait])',
      summary: 'Uses the Hologram ability to place a copy of an existing tower at a new spot.',
      params: [
        ['towerID', 'The tower to copy, by the id used in SpawnTower.'],
        ['x', 'Horizontal position of the clone, in the same pixel space as SpawnTower.'],
        ['y', 'Vertical position of the clone.'],
        ['wait', 'Optional milliseconds to wait before cloning. Default 0, and it is skipped while recording.'],
      ],
      example: 'CloneTower(Mini1, 1180, 553)\nCloneTower(Mini1, 1180, 553, 4000)',
    },
    {
      name: 'BrawlerReposition',
      signature: 'BrawlerReposition(towerID, x, y)',
      summary: 'Moves a placed Brawler to a new spot using its reposition ability.',
      params: [
        ['towerID', 'The Brawler, by the id used in SpawnTower.'],
        ['x', 'New horizontal position, in the same pixel space as SpawnTower.'],
        ['y', 'New vertical position.'],
      ],
      example: 'BrawlerReposition(Brawler1, 992, 604)',
    },
    {
      name: 'EnforcerReposition',
      signature: 'EnforcerReposition(enforcerID, towerID, x, y)',
      summary:
        'Uses the Helicopter Reposition ability of a top path Enforcer to carry another placed tower to a new spot.',
      params: [
        ['enforcerID', 'The Enforcer running the ability, by the id used in SpawnTower. It has to be top path level 5 or higher.'],
        ['towerID', 'The tower being carried, by the id used in SpawnTower.'],
        ['x', 'New horizontal position of the carried tower, in the same pixel space as SpawnTower.'],
        ['y', 'New vertical position of the carried tower.'],
      ],
      example: 'EnforcerReposition(Enf1, Mini1, 1024, 512)',
    },
    {
      name: 'ActivateEnforcerVan',
      signature: 'ActivateEnforcerVan([wait])',
      summary:
        'Presses the SWAT Van keybind of a bottom path Enforcer. The strategy needs a bottom path Enforcer at level 5 or higher, otherwise the step is skipped.',
      params: [
        ['wait', 'Optional milliseconds to wait before pressing it. Default 0, and it is skipped while recording.'],
      ],
      example: 'ActivateEnforcerVan()\nActivateEnforcerVan(3000)',
    },
    {
      name: 'ActivateRaiseTheDead',
      signature: 'ActivateRaiseTheDead([wait])',
      summary: 'Presses the Raise the Dead keybind, which revives the Necromancer skeletons.',
      params: [
        ['wait', 'Optional milliseconds to wait before pressing it. Default 0, and it is skipped while recording.'],
      ],
      example: 'ActivateRaiseTheDead()\nActivateRaiseTheDead(2500)',
    },
    {
      name: 'ChangeTargets',
      signature: 'ChangeTargets(towerID, target)',
      summary: 'Opens the tower panel and cycles its targeting until it matches the target asked for.',
      params: [
        ['towerID', 'The tower, by the id used in SpawnTower.'],
        [
          'target',
          'One of First Enemy, Last Enemy, Strongest, Weakest, Closest, Farthest or Random. Written without quotes.',
        ],
      ],
      example: 'ChangeTargets(Mini1, Strongest)',
    },
    {
      name: 'SetDJTrack',
      signature: 'SetDJTrack("track")',
      summary: 'Selects a track on the DJ Booth. The strategy has to place a tower with the id DJ first.',
      params: [
        [
          'track',
          'green, purple or red, in quotes. The macro matches the track by its colour icon, so any other value is refused at runtime.',
        ],
      ],
      example: 'SetDJTrack("green")',
    },
    {
      name: 'ToggleAutoskip',
      signature: 'ToggleAutoskip()',
      summary:
        'Presses the in-game autoskip toggle once. Use it to turn wave skipping off for a hard wave and on again afterwards.',
      params: [],
      example: 'ToggleAutoskip()',
    },
    {
      name: 'Click',
      signature: 'Click(x, y [, Right])',
      summary: 'Clicks a point on screen. Useful for buttons the other commands do not cover.',
      params: [
        ['x', 'Horizontal position, in the same pixel space as SpawnTower.'],
        ['y', 'Vertical position.'],
        ['Right', 'Optional. Add Right for a right click, anything else is a left click.'],
      ],
      example: 'Click(960, 540)\nClick(960, 540, Right)',
    },
    {
      name: 'Send',
      signature: 'Send("key", hold:=ms)',
      summary:
        'Holds a keyboard key down for a set time, then releases it. This is what the input recorder writes for movement and ability keys.',
      params: [
        ['key', 'The key name in quotes, for example "w" or "space".'],
        ['hold', 'How long to hold it, in milliseconds. The hold:= part is required.'],
      ],
      example: 'Send("w", hold:=450)',
    },
    {
      name: 'Sleep',
      signature: 'Sleep(ms)',
      summary: 'Waits before running the next step. This is how a strategy lines up with the waves.',
      params: [['ms', 'Milliseconds to wait. 1000 is one second.']],
      example: 'Sleep(12000)',
    },
    {
      name: 'Commander',
      signature: 'Commander := true',
      summary:
        'Tells the macro a Commander is in the loadout so it handles the Call of Arms ability during the run. The recorder adds this line by itself when it sees a Commander.',
      params: [],
      example: 'Commander := true',
    },
  ];

  const SLOT_COLORS = [
    '#5a616b',
    '#3a86ff',
    '#e09334',
    '#3dd68c',
    '#9b8cff',
    '#e5484d',
    '#2fb6c4',
    '#c8752f',
    '#6e7bd9',
    '#c05c94',
  ];

  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const slotColor = (slot) => SLOT_COLORS[Math.abs(Number(slot) || 0) % SLOT_COLORS.length];

  function setStatus(text) {
    els.statusText.textContent = text;
  }

  const SEPARATORS = /[\\/]+/;

  function pathTail(path, segments = 2) {
    const text = String(path || '');
    const parts = text.split(SEPARATORS).filter(Boolean);
    if (parts.length <= segments) return text;
    return '…\\' + parts.slice(-segments).join('\\');
  }

  function folderName(path) {
    const parts = String(path || '')
      .split(SEPARATORS)
      .filter(Boolean);
    return parts.length ? parts[parts.length - 1] : '';
  }

  function toast(text, kind = 'info', timeout = 2800) {
    if (!text) return;
    const node = document.createElement('div');
    node.className = `toast ${kind}`;
    node.textContent = String(text);
    els.toastStack.appendChild(node);
    requestAnimationFrame(() => node.classList.add('show'));
    window.setTimeout(() => {
      node.classList.remove('show');
      window.setTimeout(() => node.remove(), 200);
    }, timeout);
  }

  function notify(message, kind = 'error') {
    const text = String(message || '').trim();
    if (!text) return;
    setStatus(text);
    toast(text, kind === 'warn' || kind === 'success' || kind === 'info' ? kind : 'error', 5600);
  }

  let pendingConfirm = null;

  function askConfirm({ title, body, confirmLabel = 'Confirm', danger = false }) {
    settleConfirm(false);
    els.confirmTitle.textContent = title;
    els.confirmBody.textContent = body;
    els.confirmOkBtn.textContent = confirmLabel;
    els.confirmOkBtn.classList.toggle('danger', danger);
    els.confirmOkBtn.classList.toggle('primary', !danger);
    els.confirmModal.hidden = false;
    requestAnimationFrame(() => els.confirmOkBtn.focus());
    return new Promise((resolve) => {
      pendingConfirm = resolve;
    });
  }

  function settleConfirm(answer) {
    if (!pendingConfirm) return;
    const resolve = pendingConfirm;
    pendingConfirm = null;
    els.confirmModal.hidden = true;
    resolve(answer);
  }

  function busy(button, text) {
    if (!button) return () => { };
    const label = button.textContent;
    const wasDisabled = button.disabled;
    button.classList.add('is-busy');
    button.disabled = true;
    if (text) button.textContent = text;
    let restored = false;
    return () => {
      if (restored) return;
      restored = true;
      button.classList.remove('is-busy');
      button.textContent = label;
      button.disabled = wasDisabled;
      syncControls();
    };
  }

  function setViewportLoading(active, text = 'Loading…') {
    els.viewportLoader.hidden = !active;
    els.viewportLoaderText.textContent = text;
  }

  function ensureHost() {
    if (!window.ahk) throw new Error('AHK host bridge is unavailable. Launch this UI through StrategyEditorHost.ahk.');
  }

  els.winMinBtn.addEventListener('click', () => {
    try {
      ahk.MinimizeWindow();
    } catch { }
  });
  els.winMaxBtn.addEventListener('click', toggleMaximize);
  els.winCloseBtn.addEventListener('click', requestClose);

  async function requestClose() {
    if (state.dirty) {
      const confirmed = await askConfirm({
        title: 'Close Strategy Lab?',
        body: 'This strategy has unsaved changes. They are lost unless you save a copy first.',
        confirmLabel: 'Close anyway',
        danger: true,
      });
      if (!confirmed) return;
    }
    try {
      ahk.CloseWindow();
    } catch { }
  }

  function toggleMaximize() {
    try {
      ahk.ToggleMaximize();
    } catch { }
  }

  els.titlebar.addEventListener('pointerdown', (ev) => {
    if (ev.button !== 0 || ev.target.closest('.win-btn')) return;
    try {
      ahk.BeginWindowDrag();
    } catch { }
  });

  els.titlebar.addEventListener('dblclick', (ev) => {
    if (!ev.target.closest('.win-btn')) toggleMaximize();
  });

  async function chooseMacroRoot() {
    try {
      ensureHost();
      const chosen = await ahk.ChooseMacroRoot();
      if (!chosen) return;
      state.macroRoot = String(chosen);
      await refreshMapCatalog(selectedMapName());
      toast('Ultimate Macro folder linked.', 'success');
    } catch (err) {
      setStatus(`Macro folder selection failed: ${err.message || err}`);
      toast(`Could not link the macro folder: ${err.message || err}`, 'error');
    }
  }

  function renderMacroRoot() {
    els.macroStatus.textContent = state.macroRoot ? folderName(state.macroRoot) : 'Not detected';
    els.macroRootBtn.title = state.macroRoot
      ? `Reading maps from ${state.macroRoot}. Click to pick a different installation.`
      : 'Ultimate Macro was not detected. Click to pick the folder that contains Main.ahk and Resources.';
  }

  function documentMapName() {
    return String(state.doc?.mapCanonical || state.doc?.mapName || '').trim();
  }

  function selectedMapName() {
    return String(state.selectedMap || documentMapName()).trim();
  }

  function selectedMapEntry() {
    const name = selectedMapName();
    if (!name) return null;
    return (
      state.mapCatalog.find((m) => String(m.name) === name) || { name, cached: false, supported: false, difficulty: '' }
    );
  }

  async function refreshMapCatalog(preferred = '') {
    try {
      ensureHost();
      const raw = await ahk.GetMapCatalog();
      const payload = raw ? JSON.parse(String(raw)) : { maps: [] };
      state.mapCatalog = Array.isArray(payload.maps) ? payload.maps : [];
      state.macroRoot = payload.macroRoot || '';
      renderMacroRoot();
      buildMapMenu(preferred || selectedMapName());
    } catch (err) {
      setStatus(`Map catalog warning: ${err.message || err}`);
    }
  }

  function buildMapMenu(preferred = '') {
    const byName = new Map(state.mapCatalog.map((m) => [String(m.name), m]));

    const docMapName = documentMapName();
    if (docMapName && !byName.has(docMapName)) {
      const synthetic = { name: docMapName, category: 'Strategy', difficulty: '', supported: false, cached: false };
      state.mapCatalog.unshift(synthetic);
      byName.set(synthetic.name, synthetic);
    }

    if (preferred && byName.has(preferred)) state.selectedMap = preferred;
    else if (docMapName && byName.has(docMapName)) state.selectedMap = docMapName;
    else if (state.selectedMap && !byName.has(state.selectedMap)) state.selectedMap = '';

    renderMapMenu(els.mapSearch.value);
    renderMapPickerLabel();
    syncControls();
  }

  function renderMapMenu(query = '') {
    const q = String(query || '')
      .trim()
      .toLowerCase();
    const matches = state.mapCatalog.filter(
      (m) => !q || `${m.name} ${m.category || ''} ${m.difficulty || ''}`.toLowerCase().includes(q),
    );
    const groups = [
      ['Verified by installed macro', matches.filter((m) => m.supported)],
      ['Cached map library', matches.filter((m) => !m.supported && m.cached)],
      ['Known TDS maps', matches.filter((m) => !m.supported && !m.cached)],
    ];

    els.mapMenuList.replaceChildren();
    let count = 0;

    for (const [label, items] of groups) {
      if (!items.length) continue;
      const title = document.createElement('div');
      title.className = 'map-group';
      title.textContent = label;
      els.mapMenuList.appendChild(title);

      for (const m of [...items].sort((a, b) => String(a.name).localeCompare(String(b.name)))) {
        count++;
        const option = document.createElement('button');
        option.type = 'button';
        option.className = `map-option${String(m.name) === state.selectedMap ? ' active' : ''}`;
        option.setAttribute('role', 'option');
        option.setAttribute('aria-selected', String(String(m.name) === state.selectedMap));

        const name = document.createElement('span');
        name.className = 'map-option-name';
        name.textContent = m.name;
        option.appendChild(name);

        const tags = document.createElement('span');
        tags.className = 'map-tags';
        if (m.supported)
          tags.appendChild(
            mapTag(
              'verified',
              'verified',
              m.supportEvidence ? `Installed macro evidence: ${m.supportEvidence}` : 'Verified by the installed macro',
            ),
          );
        if (m.cached) tags.appendChild(mapTag('cached', 'cached', 'A map screenshot is cached locally'));
        if (m.difficulty) tags.appendChild(mapTag('', m.difficulty, ''));
        option.appendChild(tags);

        option.addEventListener('click', () => chooseMap(m.name));
        els.mapMenuList.appendChild(option);
      }
    }

    if (!count) {
      const empty = document.createElement('div');
      empty.className = 'map-empty';
      empty.textContent = q ? `No maps match “${query}”.` : 'No maps found.';
      els.mapMenuList.appendChild(empty);
    }
  }

  function mapTag(kind, text, title) {
    const tag = document.createElement('span');
    tag.className = `map-tag${kind ? ` ${kind}` : ''}`;
    tag.textContent = text;
    if (title) tag.title = title;
    return tag;
  }

  function renderMapPickerLabel() {
    const entry = selectedMapEntry();
    els.mapPickerText.textContent = entry ? entry.name : 'Choose map…';
    els.mapPickerBtn.title = entry ? `Map library entry: ${entry.name}` : 'Pick the map this strategy was recorded on';
  }

  function toggleMapMenu(force) {
    const open = typeof force === 'boolean' ? force : els.mapMenu.hidden;
    els.mapMenu.hidden = !open;
    els.mapPicker.classList.toggle('open', open);
    els.mapPickerBtn.setAttribute('aria-expanded', String(open));
    if (open) {
      renderMapMenu(els.mapSearch.value);
      requestAnimationFrame(() => els.mapSearch.focus());
    }
  }

  async function chooseMap(name) {
    state.selectedMap = String(name || '');
    renderMapPickerLabel();
    renderMapMenu(els.mapSearch.value);
    toggleMapMenu(false);
    syncControls();
    renderDocBar();
    await loadSelectedMap({ silent: false });
    await refreshGeometryForMap();
  }

  async function refreshGeometryForMap() {
    if (!state.doc || !window.ahk?.GetGeometry) return;
    try {
      const raw = await ahk.GetGeometry(selectedMapName());
      if (!raw) return;
      applyGeometryPayload(JSON.parse(String(raw)));
    } catch { }
  }

  function applyGeometryPayload(payload) {
    if (!state.doc || !payload) return;
    state.doc.pixelsPerUnit = Number(payload.pixelsPerUnit) || state.doc.pixelsPerUnit;
    state.doc.pixelsPerStud = Number(payload.pixelsPerStud) || state.doc.pixelsPerUnit;
    state.doc.geometrySource = payload.geometrySource || state.doc.geometrySource;
    state.doc.geometryConfidence = Number(payload.geometryConfidence) || 0;
    state.doc.geometryOffsetX = Number(payload.geometryOffsetX) || 0;
    state.doc.geometryOffsetY = Number(payload.geometryOffsetY) || 0;
    if (payload.geometryProjection) state.doc.geometryProjection = payload.geometryProjection;
    refreshGeometryVisuals();
    state.doc.placements.forEach((p, index) => updateMarkerPosition(index, state.markerEls[index], p));
    refreshActionGeometry();
  }

  function clearMapVisual() {
    state.map = null;
    els.mapImage.removeAttribute('src');
    els.mapImage.hidden = true;
    els.world.classList.add('no-map');
    els.mapImageInfo.textContent = 'Not cached';
  }

  async function loadSelectedMap({ silent = false, allowCapture = false } = {}) {
    const mapName = selectedMapName();
    if (!mapName) {
      if (!silent) setStatus('Choose a map first.');
      return false;
    }
    try {
      ensureHost();
      const cached = state.mapPayloadCache.get(mapName);
      if (cached) {
        setMapPayload(cached, { fromCache: true });
        return true;
      }

      if (!silent) setStatus(`Loading ${mapName} from the map library…`);
      setViewportLoading(true, `Loading ${mapName}…`);
      let data = window.ahk?.AutoLoadMapBackground
        ? await ahk.AutoLoadMapBackground(mapName, false)
        : await ahk.LoadCachedMap(mapName);
      if (!data && allowCapture && window.ahk?.AutoLoadMapBackground) {
        setViewportLoading(true, `Capturing ${mapName} from the open Roblox client…`);
        data = await ahk.AutoLoadMapBackground(mapName, true);
        if (data) await refreshMapCatalog(mapName);
      }
      if (data) {
        const text = String(data);
        state.mapPayloadCache.set(mapName, text);
        setMapPayload(text);
        return true;
      }
      clearMapVisual();
      if (!silent)
        setStatus(`No map image for ${mapName} yet. Use Capture while the map is open, or Import a screenshot.`);
      return false;
    } catch (err) {
      if (!silent) {
        setStatus(`Map load failed: ${err.message || err}`);
        toast(`Map load failed: ${err.message || err}`, 'error');
      }
      return false;
    } finally {
      setViewportLoading(false);
    }
  }

  const MAP_TEMPLATE_MATCH_THRESHOLD = 0.8;

  function loadImageFromDataUrl(dataUrl) {
    return new Promise((resolve) => {
      if (!dataUrl) {
        resolve(null);
        return;
      }
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => resolve(null);
      image.src = dataUrl;
    });
  }

  function grayscaleOf(image, width, height) {
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(width));
    canvas.height = Math.max(1, Math.round(height));
    const context = canvas.getContext('2d', { willReadFrequently: true });
    if (!context) return null;
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const data = new Float64Array(canvas.width * canvas.height);
    for (let i = 0; i < data.length; i++) {
      const offset = i * 4;
      data[i] = 0.299 * pixels[offset] + 0.587 * pixels[offset + 1] + 0.114 * pixels[offset + 2];
    }
    return { data, width: canvas.width, height: canvas.height };
  }

  function bestTemplateScore(frame, template) {
    if (!frame || !template) return 0;
    if (template.width > frame.width || template.height > frame.height) return 0;

    const count = template.data.length;
    let templateSum = 0;
    for (let i = 0; i < count; i++) templateSum += template.data[i];
    const templateMean = templateSum / count;
    let templateVariance = 0;
    for (let i = 0; i < count; i++) templateVariance += (template.data[i] - templateMean) ** 2;
    if (templateVariance <= 1e-6) return 0;
    const templateNorm = Math.sqrt(templateVariance);

    const scoreAt = (ox, oy) => {
      let sum = 0;
      for (let ty = 0; ty < template.height; ty++) {
        const frameRow = (oy + ty) * frame.width + ox;
        for (let tx = 0; tx < template.width; tx++) sum += frame.data[frameRow + tx];
      }
      const frameMean = sum / count;
      let cross = 0;
      let frameVariance = 0;
      for (let ty = 0; ty < template.height; ty++) {
        const frameRow = (oy + ty) * frame.width + ox;
        const templateRow = ty * template.width;
        for (let tx = 0; tx < template.width; tx++) {
          const f = frame.data[frameRow + tx] - frameMean;
          cross += f * (template.data[templateRow + tx] - templateMean);
          frameVariance += f * f;
        }
      }
      if (frameVariance <= 1e-6) return 0;
      return cross / (Math.sqrt(frameVariance) * templateNorm);
    };

    const maxX = frame.width - template.width;
    const maxY = frame.height - template.height;
    const coarse = Math.max(1, Math.round(Math.min(template.width, template.height) / 12));

    let best = { score: 0, x: 0, y: 0 };
    for (let oy = 0; oy <= maxY; oy += coarse) {
      for (let ox = 0; ox <= maxX; ox += coarse) {
        const score = scoreAt(ox, oy);
        if (score > best.score) best = { score, x: ox, y: oy };
      }
    }

    for (let oy = Math.max(0, best.y - coarse); oy <= Math.min(maxY, best.y + coarse); oy++) {
      for (let ox = Math.max(0, best.x - coarse); ox <= Math.min(maxX, best.x + coarse); ox++) {
        const score = scoreAt(ox, oy);
        if (score > best.score) best = { score, x: ox, y: oy };
      }
    }
    return best.score;
  }

  async function verifyCapturedMap(mapName, framePayload) {
    if (!window.ahk?.GetMapTemplate) return { verified: null, score: 0 };
    let templatePayload;
    try {
      const raw = await ahk.GetMapTemplate(mapName);
      if (!raw) return { verified: null, score: 0 };
      templatePayload = JSON.parse(String(raw));
    } catch {
      return { verified: null, score: 0 };
    }

    const [frameImage, templateImage] = await Promise.all([
      loadImageFromDataUrl(framePayload?.dataUrl),
      loadImageFromDataUrl(templatePayload?.dataUrl),
    ]);
    if (!frameImage || !templateImage) return { verified: null, score: 0 };

    const clientScale = frameImage.naturalHeight / 1009;
    const shortestTemplateSide = Math.min(templateImage.naturalWidth, templateImage.naturalHeight) * clientScale;
    const analysisWidth = clamp(
      Math.round((48 * frameImage.naturalWidth) / Math.max(1, shortestTemplateSide)),
      420,
      960,
    );
    const frameFactor = analysisWidth / frameImage.naturalWidth;
    const frame = grayscaleOf(
      frameImage,
      frameImage.naturalWidth * frameFactor,
      frameImage.naturalHeight * frameFactor,
    );
    const template = grayscaleOf(
      templateImage,
      templateImage.naturalWidth * clientScale * frameFactor,
      templateImage.naturalHeight * clientScale * frameFactor,
    );
    const score = bestTemplateScore(frame, template);
    return { verified: score >= MAP_TEMPLATE_MATCH_THRESHOLD, score };
  }

  async function ensureMapBackground(mapName) {
    if (!mapName) return;
    const loaded = await loadSelectedMap({ silent: true });
    if (loaded || state.mapAutoCaptureTried.has(mapName)) return;
    if (state.replay.state === 'running') return;
    state.mapAutoCaptureTried.add(mapName);

    const captured = await loadSelectedMap({ silent: true, allowCapture: true });
    if (!captured) {
      setStatus(`${mapName} has no map image yet. Open the map in Roblox and press Capture, or Import a screenshot.`);
      return;
    }

    const check = await verifyCapturedMap(mapName, state.map);
    if (check.verified === false) {
      state.mapPayloadCache.delete(mapName);
      clearMapVisual();
      try {
        if (window.ahk?.ForgetMapBackground) await ahk.ForgetMapBackground(mapName);
      } catch { }
      await refreshMapCatalog(mapName);
      setStatus(
        `The captured frame does not match the ${mapName} reference image (${check.score.toFixed(2)}). Enter the map in Roblox and press Capture.`,
      );
      toast(`That capture was not ${mapName}. Enter the match first, then press Capture.`, 'warn', 6000);
      return;
    }

    const suffix =
      check.verified === true ? ` Verified against the macro reference image (${check.score.toFixed(2)}).` : '';
    toast(`${mapName} captured from the open Roblox client and added to the map library.${suffix}`, 'success', 4600);
  }

  async function importSelectedMap() {
    const mapName = selectedMapName();
    if (!mapName) {
      setStatus('Choose a map first.');
      return;
    }
    const done = busy(els.importMapBtn, 'Importing…');
    try {
      ensureHost();
      setViewportLoading(true, `Importing ${mapName}…`);
      const data = await ahk.ImportMap(mapName);
      if (data) {
        const text = String(data);
        state.mapPayloadCache.set(mapName, text);
        setMapPayload(text);
        await refreshMapCatalog(mapName);
        toast(`${mapName} imported into the local map library.`, 'success');
      } else {
        setStatus('No map was imported.');
      }
    } catch (err) {
      setStatus(`Import failed: ${err.message || err}`);
      toast(`Import failed: ${err.message || err}`, 'error');
    } finally {
      setViewportLoading(false);
      done();
    }
  }

  async function captureRoblox() {
    const mapName = selectedMapName();
    if (!mapName) {
      setStatus('Choose a map first so the capture has a stable library name.');
      return;
    }
    const done = busy(els.captureMapBtn, 'Capturing…');
    try {
      ensureHost();
      setViewportLoading(true, 'Capturing lossless Roblox client…');
      setStatus(`Aligning the camera and capturing ${mapName}…`);
      const data = await ahk.CaptureRoblox(mapName);
      if (data) {
        const text = String(data);
        state.mapPayloadCache.set(mapName, text);
        setMapPayload(text);
        await refreshMapCatalog(mapName);
        toast(`Lossless ${mapName} capture saved.`, 'success');
      } else {
        setStatus('No capture was saved.');
      }
    } catch (err) {
      setStatus(`Capture failed: ${err.message || err}`);
      toast(`Capture failed: ${err.message || err}`, 'error');
    } finally {
      setViewportLoading(false);
      done();
    }
  }

  function setMapPayload(jsonText, options = {}) {
    let payload;
    try {
      payload = typeof jsonText === 'string' ? JSON.parse(jsonText) : jsonText;
    } catch {
      return;
    }
    if (!payload || !payload.dataUrl) return;
    state.map = payload;
    els.mapImage.src = payload.dataUrl;
    els.mapImage.hidden = false;
    els.world.classList.remove('no-map');
    const quality = payload.lossless ? 'lossless' : 'lossy';
    const label = payload.mapName || selectedMapName() || payload.name || 'Map';
    els.mapImageInfo.textContent = `${payload.format || 'image'} • ${quality} • ${payload.source || 'file'}`;
    setStatus(`Map loaded: ${label} (${quality})${options.fromCache ? ' • memory cache' : ''}.`);
    setViewportLoading(false);
    renderDocBar();
  }

  async function openStrategy() {
    const done = busy(els.openBtn, 'Opening…');
    try {
      ensureHost();
      setStatus('Opening strategy…');
      setViewportLoading(true, 'Reading strategy…');
      const result = await ahk.OpenStrategy();
      if (!result) {
        setStatus('Open canceled.');
        setViewportLoading(false);
      }
    } catch (err) {
      setViewportLoading(false);
      setStatus(`Open failed: ${err.message || err}`);
      toast(`Open failed: ${err.message || err}`, 'error');
    } finally {
      done();
    }
  }

  function loadStrategy(payload) {
    if (typeof payload === 'string') payload = JSON.parse(payload);
    if (!Array.isArray(payload.placements)) payload.placements = [];
    if (!Array.isArray(payload.requiredTowers)) payload.requiredTowers = [];
    payload.spatialActions = spatialActionsFromText(payload.text || '');

    stopReplayPolling();
    resetEditorMode();
    state.doc = payload;
    state.activeSlot = 0;
    state.selectedIndex = -1;
    state.selectedActionIndex = -1;
    state.undo = [];
    state.redo = [];
    state.dirty = false;
    state.map = null;
    state.mapAutoCaptureTried = new Set();
    state.selectedMap = String(payload.mapCanonical || payload.mapName || '');
    state.collisionSet = new Set();
    state.collisionPairs = new Set();
    state.portraitCache.clear();
    state.replay.state = '';
    state.replay.failedIds = new Set();
    state.replay.steps = new Map();
    state.replay.announced = new Map();
    payload.placements.forEach((p) => {
      p.replayFailed = false;
    });

    state.calibration.marking = false;
    state.calibration.marks = [];
    state.calibration.sessionPath = '';
    state.calibration.baselinePath = '';
    state.calibration.manualPath = '';
    state.calibration.clientWidth = 0;
    state.calibration.clientHeight = 0;
    state.calibration.autoPreparing = false;
    state.calibration.autoPreparedPath = '';
    state.calibration.macroVersion = '';
    state.calibration.cameraContract = '';
    state.calibration.solved = null;
    document.body.classList.remove('marking');
    els.calibrationMarkHud.hidden = true;

    setViewportLoading(false);
    els.world.hidden = false;
    els.emptyState.hidden = true;
    els.viewport.classList.remove('is-empty');
    els.world.style.width = `${payload.strategyWidth}px`;
    els.world.style.height = `${payload.strategyHeight}px`;
    clearMapVisual();

    els.resolutionInfo.textContent = `${payload.strategyWidth} × ${payload.strategyHeight}${payload.hasExplicitDimensions === false ? ' • legacy fallback' : ''}`;
    els.mapInfo.textContent = payload.mapName || '—';
    els.mapImageInfo.textContent = 'Not cached';
    els.encodingInfo.textContent = payload.encoding || '—';
    els.fileInfo.textContent = payload.path ? pathTail(payload.path) : '—';
    els.fileInfo.title = payload.path || '';
    renderGeometryInfo(payload);

    buildLayerOptions();
    buildRanges();
    buildFootprints();
    buildMarkers();
    buildActionLayer();
    buildRows();
    buildActionRows();
    recomputeCollisions();
    renderCalibrationMarks();
    updateCalibrationControls();
    clearSelection();
    setDirty(false);
    renderDocBar();
    syncCodeEditor();
    requestAnimationFrame(() => fitWorld(true));

    const loadout = new Set(payload.requiredTowers.filter(Boolean).map((x) => String(x).toLowerCase())).size;
    setStatus(`Loaded ${payload.placements.length} placement${payload.placements.length === 1 ? '' : 's'}.`);
    if (loadout > 5)
      toast(`This strategy declares ${loadout} required towers; normal TDS loadouts hold 5.`, 'warn', 5200);
    if (payload.hasExplicitDimensions === false) {
      toast(
        'Strategy width/height metadata is missing. The macro falls back to 1920×1080, so alignment is approximate until it is re-recorded.',
        'warn',
        6500,
      );
    }

    refreshPortraitStatus().then(updateHealth);
    populateCalibrationTowerOptions();
    refreshMapCatalog(documentMapName()).then(() => ensureMapBackground(selectedMapName()));

    if (String(payload.strategyLabMode || '').toLowerCase() === 'sandbox-calibration') {
      window.setTimeout(() => openCalibration({ autoPrepare: true }), 220);
    }
  }

  function renderGeometryInfo(payload) {
    const offsetX = Number(payload.geometryOffsetX || 0);
    const offsetY = Number(payload.geometryOffsetY || 0);
    const projection = payload.geometryProjection || null;
    const affine = String(projection?.model || '').toLowerCase() === 'affine-v1';
    const fallback = baseScale();

    if (affine) {
      const px = Number(projection.ppuX0 || fallback).toFixed(2);
      const py = Number(projection.ppuY0 || fallback).toFixed(2);
      els.geometryInfo.textContent = `${px}×${py} px/stud • projected`;
      els.geometryInfo.title = `Position-aware affine scale • ${Number(projection.samples || 0)} samples • RMSE X/Y ${Number(projection.rmseX || 0).toFixed(2)}/${Number(projection.rmseY || 0).toFixed(2)} px/stud • visual offset ${offsetX.toFixed(2)}, ${offsetY.toFixed(2)}`;
    } else {
      els.geometryInfo.textContent = `${fallback.toFixed(2)} px/stud`;
      els.geometryInfo.title = `Uniform stud scale • visual offset ${offsetX.toFixed(2)}, ${offsetY.toFixed(2)} strategy px • run Calibration to measure this client exactly`;
    }

    const confidence = Number(payload.geometryConfidence || 0);
    const source = payload.geometrySource || 'bundled-strategy-solve';
    els.geometryConfidenceInfo.textContent =
      confidence > 0 ? `${source} • ${Math.round(confidence * 100)}%` : `${source} • uncalibrated`;
  }

  function renderDocBar() {
    const doc = state.doc;
    els.docName.textContent = doc?.name || 'No strategy loaded';
    els.docName.title = doc?.path || '';
    const map = selectedMapName();
    els.docMap.textContent = doc ? map || 'no map' : '';
  }

  function buildLayerOptions() {
    const options = [{ value: 0, label: 'All placements' }];
    const seen = new Set();
    for (const p of state.doc.placements) {
      const slot = Number(p.slot) || 0;
      if (slot <= 0 || seen.has(slot)) continue;
      seen.add(slot);
      const tower = state.doc.requiredTowers[slot - 1] || p.towerName || '';
      options.push({ value: slot, label: `Slot ${slot}${tower ? ` — ${tower}` : ''}` });
    }
    options.sort((a, b) => a.value - b.value);
    els.layerSelect.replaceChildren(
      ...options.map((o) => {
        const el = document.createElement('option');
        el.value = String(o.value);
        el.textContent = o.label;
        return el;
      }),
    );
    els.layerSelect.value = '0';
  }

  function displayPoint(p) {
    return {
      x: Number(p.x) + Number(state.doc?.geometryOffsetX || 0),
      y: Number(p.y) + Number(state.doc?.geometryOffsetY || 0),
    };
  }

  function canonicalPoint(p) {
    return {
      x: (Number(p.x) * 1920) / Math.max(1, Number(state.doc.strategyWidth)),
      y: (Number(p.y) * 1009) / Math.max(1, Number(state.doc.strategyHeight)),
    };
  }

  const SCALE_MIN = 4;
  const SCALE_MAX = 60;
  const DEFAULT_SCALE = 13.4;
  const COLLISION_TOLERANCE_RATIO = 0.03;
  const COLLISION_TOLERANCE_FLOOR = 2;

  function baseScale() {
    const value = Number(state.doc?.pixelsPerStud ?? state.doc?.pixelsPerUnit);
    return Number.isFinite(value) && value >= SCALE_MIN && value <= SCALE_MAX ? value : DEFAULT_SCALE;
  }

  function projectionAt(p) {
    const fallback = baseScale();
    const model = state.doc?.geometryProjection || null;
    if (!model || String(model.model || '').toLowerCase() !== 'affine-v1') {
      return { ppuX: fallback, ppuY: fallback, model: 'global-v1' };
    }

    const point = canonicalPoint(p);
    const nx = point.x / 1920 - 0.5;
    const ny = point.y / 1009 - 0.5;
    const ppuX = Number(model.ppuX0) + Number(model.ppuXX || 0) * nx + Number(model.ppuXY || 0) * ny;
    const ppuY = Number(model.ppuY0) + Number(model.ppuYX || 0) * nx + Number(model.ppuYY || 0) * ny;
    if (
      !Number.isFinite(ppuX) ||
      !Number.isFinite(ppuY) ||
      ppuX < SCALE_MIN ||
      ppuX > SCALE_MAX ||
      ppuY < SCALE_MIN ||
      ppuY > SCALE_MAX
    ) {
      return { ppuX: fallback, ppuY: fallback, model: 'global-v1' };
    }
    return { ppuX, ppuY, model: 'affine-v1' };
  }

  function studsToStrategyPixels(p, studs) {
    const projection = projectionAt(p);
    return {
      w: (studs * projection.ppuX * 2 * Number(state.doc.strategyWidth)) / 1920,
      h: (studs * projection.ppuY * 2 * Number(state.doc.strategyHeight)) / 1009,
    };
  }

  function catalogFootprint(p) {
    return clamp(Number(p?.footprint) || 1.5, 0.25, 4);
  }
  function effectiveFootprint(p) {
    return clamp(Number(p?.footprintOverride ?? catalogFootprint(p)), 0.25, 4);
  }

  function footprintSize(p) {
    return studsToStrategyPixels(p, effectiveFootprint(p));
  }

  function rangeLevels(p) {
    const levels = Array.isArray(p?.rangeLevels) ? p.rangeLevels.map(Number).filter(Number.isFinite) : [];
    return levels;
  }

  function upgradeLevel(p) {
    const levels = rangeLevels(p);
    if (!levels.length) return 0;
    const requested = Number(p?.upgradeLevel ?? 0);
    return clamp(Math.round(Number.isFinite(requested) ? requested : 0), 0, levels.length - 1);
  }

  function rangeStuds(p) {
    const levels = rangeLevels(p);
    if (!levels.length) return Number(p?.rangeStuds) || 0;
    return levels[upgradeLevel(p)] || 0;
  }

  function rangeKnown(p) {
    const status = String(p?.rangeStatus || 'unknown').toLowerCase();
    return rangeStuds(p) > 0 && (status === 'wiki-exact' || status === 'wiki-partial');
  }

  function rangeSize(p) {
    return studsToStrategyPixels(p, rangeStuds(p));
  }

  function placementPlanesOverlap(a, b) {
    const ta = String(a?.placementType || 'unknown').toLowerCase();
    const tb = String(b?.placementType || 'unknown').toLowerCase();
    return !((ta === 'ground' && tb === 'cliff') || (ta === 'cliff' && tb === 'ground'));
  }

  function pairCollides(a, b) {
    if (a.replayFailed || b.replayFailed) return false;
    if (!placementPlanesOverlap(a, b)) return false;
    const pa = canonicalPoint(a),
      pb = canonicalPoint(b);
    const ga = projectionAt(a),
      gb = projectionAt(b);
    const ppuX = Math.max(SCALE_MIN, (ga.ppuX + gb.ppuX) / 2);
    const ppuY = Math.max(SCALE_MIN, (ga.ppuY + gb.ppuY) / 2);
    const radiusA = effectiveFootprint(a);
    const radiusB = effectiveFootprint(b);
    const dxUnits = (pa.x - pb.x) / ppuX;
    const dyUnits = (pa.y - pb.y) / ppuY;
    const distanceUnits = Math.sqrt(dxUnits * dxUnits + dyUnits * dyUnits);
    const contactUnits = radiusA + radiusB;
    const scale = Math.max(SCALE_MIN, (ppuX + ppuY) / 2);
    const tolerance = Math.max(COLLISION_TOLERANCE_FLOOR / scale, contactUnits * COLLISION_TOLERANCE_RATIO);
    return distanceUnits < contactUnits - tolerance;
  }

  function recomputeCollisions(liveIndex = -1) {
    if (!state.doc) return;
    const placements = state.doc.placements;
    const pairs = new Set();

    if (liveIndex >= 0) {
      for (const key of state.collisionPairs) {
        const [a, b] = key.split(':').map(Number);
        if (a !== liveIndex && b !== liveIndex) pairs.add(key);
      }
      for (let j = 0; j < placements.length; j++) {
        if (j === liveIndex) continue;
        if (pairCollides(placements[liveIndex], placements[j])) {
          pairs.add(`${Math.min(liveIndex, j)}:${Math.max(liveIndex, j)}`);
        }
      }
    } else {
      for (let i = 0; i < placements.length; i++) {
        for (let j = i + 1; j < placements.length; j++) {
          if (pairCollides(placements[i], placements[j])) pairs.add(`${i}:${j}`);
        }
      }
    }

    const affected = new Set();
    for (const key of pairs) {
      const [a, b] = key.split(':').map(Number);
      affected.add(a);
      affected.add(b);
    }
    state.collisionPairs = pairs;
    state.collisionSet = affected;
    state.footprintEls.forEach((el, i) => el?.classList.toggle('collision', affected.has(i)));
    updateSummary();
    updateHealth();
  }

  function buildRanges() {
    els.rangeLayer.replaceChildren();
    state.rangeEls = state.doc.placements.map((p, index) => {
      const el = document.createElement('div');
      el.className = 'range';
      el.dataset.index = String(index);
      els.rangeLayer.appendChild(el);
      styleRange(index, el, p);
      return el;
    });
    updateRangeVisibility();
  }

  function rangeIsVisible(index) {
    if (!state.doc) return false;
    const p = state.doc.placements[index];
    if (!p || !(rangeStuds(p) > 0)) return false;
    if (state.activeSlot !== 0 && Number(p.slot) !== state.activeSlot) return false;
    return state.rangesVisible || index === state.selectedIndex;
  }

  function updateRangeVisibility() {
    state.rangeEls.forEach((el, index) => {
      if (!el) return;
      el.classList.toggle('hidden', !rangeIsVisible(index));
      el.classList.toggle('selected', index === state.selectedIndex);
    });
  }

  function styleRange(index, element, placement) {
    const p = placement || state.doc?.placements[index];
    const el = element || state.rangeEls[index];
    if (!p || !el) return;
    el.classList.toggle('estimated', !rangeKnown(p));
    updateRangePosition(index, el, p);
  }

  function updateRangePosition(index, element, placement) {
    const p = placement || state.doc?.placements[index];
    const el = element || state.rangeEls[index];
    if (!p || !el) return;
    const studs = rangeStuds(p);
    if (!(studs > 0)) return;
    const dp = displayPoint(p);
    const size = rangeSize(p);
    el.style.left = `${dp.x}px`;
    el.style.top = `${dp.y}px`;
    el.style.width = `${size.w}px`;
    el.style.height = `${size.h}px`;
    el.title = `${p.towerName || `Slot ${p.slot}`} • range ${studs} studs at level ${upgradeLevel(p)}`;
  }

  function refreshGeometryVisuals() {
    if (!state.doc) return;
    state.doc.placements.forEach((p, index) => {
      updateFootprintPosition(index, state.footprintEls[index], p);
      updateRangePosition(index, state.rangeEls[index], p);
    });
    recomputeCollisions();
    renderGeometryInfo(state.doc);
    if (state.selectedIndex >= 0) renderSelectedMeta();
  }

  function buildFootprints() {
    els.footprintLayer.replaceChildren();
    state.footprintEls = state.doc.placements.map((p, index) => {
      const el = document.createElement('div');
      el.className = 'footprint';
      el.dataset.index = String(index);
      el.addEventListener('pointerdown', markerPointerDown);
      els.footprintLayer.appendChild(el);
      styleFootprint(index, el, p);
      return el;
    });
    els.footprintLayer.classList.toggle('off', !state.footprintsVisible);
  }

  function styleFootprint(index, el, p) {
    el.classList.toggle('estimated', !p.footprintKnown);
    el.classList.toggle('cliff', p.placementType === 'cliff');
    el.classList.toggle('both', p.placementType === 'both');
    el.classList.toggle('replay-failed', Boolean(p.replayFailed));
    el.title = `${p.towerName || `Slot ${p.slot}`} • footprint ${effectiveFootprint(p).toFixed(2)} studs • ${Object.hasOwn(p, 'footprintOverride') ? 'custom' : p.footprintStatus || 'estimated'} • drag to move`;
    updateFootprintPosition(index, el, p);
  }

  function updateFootprintPosition(index, element, placement) {
    const p = placement || state.doc?.placements[index];
    const el = element || state.footprintEls[index];
    if (!p || !el) return;
    const dp = displayPoint(p);
    const size = footprintSize(p);
    el.style.left = `${dp.x}px`;
    el.style.top = `${dp.y}px`;
    el.style.width = `${size.w}px`;
    el.style.height = `${size.h}px`;
  }

  function buildMarkers() {
    els.markerLayer.replaceChildren();
    state.markerEls = state.doc.placements.map((p, index) => {
      const el = document.createElement('div');
      el.className = 'marker';
      el.dataset.index = String(index);
      el.style.background = slotColor(p.slot);
      el.textContent =
        String(p.towerId || index + 1)
          .replace(/[^0-9]+/g, '')
          .slice(-2) || String(index + 1);
      el.addEventListener('pointerdown', markerPointerDown);
      els.markerLayer.appendChild(el);
      updateMarkerPosition(index, el, p);
      return el;
    });
  }

  function updateMarkerPosition(index, el, p) {
    const marker = el || state.markerEls[index];
    const placement = p || state.doc?.placements[index];
    if (!marker || !placement) return;
    const dp = displayPoint(placement);
    marker.style.left = `${dp.x}px`;
    marker.style.top = `${dp.y}px`;
    marker.title = `${placement.towerName || `Slot ${placement.slot}`} • ${placement.x}, ${placement.y}`;
  }


  function spatialActionsFromText(text) {
    if (!window.StrategySpatial?.parse) return [];
    return window.StrategySpatial.parse(text || '');
  }

  function placementByTowerId(towerId) {
    const wanted = String(towerId || '').trim().toLowerCase();
    if (!wanted || !state.doc) return null;
    return state.doc.placements.find((p) => String(p.towerId || '').trim().toLowerCase() === wanted) || null;
  }

  function actionTargetTowerName(action) {
    return placementByTowerId(action?.targetId)?.towerName || action?.targetId || 'Unknown';
  }

  function actionSourcePoint(action, index) {
    if (!state.doc || !action) return action || { x: 0, y: 0 };
    let source = placementByTowerId(action.targetId) || placementByTowerId(action.actorId);
    for (let i = 0; i < index; i++) {
      const prior = state.doc.spatialActions?.[i];
      if (!prior || prior.kind === 'clone') continue;
      if (String(prior.targetId || '').trim().toLowerCase() === String(action.targetId || '').trim().toLowerCase()) {
        source = prior;
      }
    }
    return source || action;
  }

  function actionShortLabel(action, index) {
    const prefix = action.kind === 'clone' ? 'C' : action.kind === 'brawler-reposition' ? 'B' : 'E';
    return `${prefix}${index + 1}`;
  }

  function buildActionLayer() {
    els.actionLayer.replaceChildren();
    state.actionEls = [];
    const actions = state.doc?.spatialActions || [];
    const ns = 'http://www.w3.org/2000/svg';
    actions.forEach((action, index) => {
      const group = document.createElementNS(ns, 'g');
      group.dataset.index = String(index);
      const line = document.createElementNS(ns, 'line');
      line.classList.add('action-link');
      const handle = document.createElementNS(ns, 'circle');
      handle.classList.add('action-handle');
      handle.setAttribute('r', '11');
      handle.dataset.index = String(index);
      handle.addEventListener('pointerdown', actionPointerDown);
      const label = document.createElementNS(ns, 'text');
      label.classList.add('action-label');
      label.textContent = actionShortLabel(action, index);
      group.append(line, handle, label);
      els.actionLayer.appendChild(group);
      const entry = { group, line, handle, label };
      state.actionEls.push(entry);
      updateActionPosition(index, entry, action);
    });
  }

  function updateActionPosition(index, entry = state.actionEls[index], action = state.doc?.spatialActions?.[index]) {
    if (!entry || !action) return;
    const source = displayPoint(actionSourcePoint(action, index));
    const target = displayPoint(action);
    entry.line.setAttribute('x1', String(source.x));
    entry.line.setAttribute('y1', String(source.y));
    entry.line.setAttribute('x2', String(target.x));
    entry.line.setAttribute('y2', String(target.y));
    entry.handle.setAttribute('cx', String(target.x));
    entry.handle.setAttribute('cy', String(target.y));
    entry.label.setAttribute('x', String(target.x + 15));
    entry.label.setAttribute('y', String(target.y - 12));
    entry.group.setAttribute('aria-label', `${action.label}: ${action.targetId} to ${action.x}, ${action.y}`);
  }

  function refreshActionGeometry() {
    (state.doc?.spatialActions || []).forEach((action, index) => updateActionPosition(index, state.actionEls[index], action));
  }

  function buildActionRows() {
    els.actionRows.replaceChildren();
    const actions = state.doc?.spatialActions || [];
    state.actionRowEls = actions.map((action, index) => {
      const tr = document.createElement('tr');
      tr.className = 'action-row';
      tr.dataset.index = String(index);
      tr.appendChild(cell(String(index + 1), 'c-idx'));
      tr.appendChild(cell(action.label, 'action-kind'));
      tr.appendChild(cell(actionTargetTowerName(action)));
      tr.appendChild(cell(String(action.x), 'c-num'));
      tr.appendChild(cell(String(action.y), 'c-num'));
      tr.addEventListener('click', () => selectAction(index, true));
      els.actionRows.appendChild(tr);
      return tr;
    });
    if (!actions.length) emptyRow(els.actionRows, 5, 'No draggable CloneTower / BrawlerReposition / EnforcerReposition actions.');
    els.actionCount.textContent = String(actions.length);
  }

  function updateActionRow(index) {
    const action = state.doc?.spatialActions?.[index];
    const row = state.actionRowEls[index];
    if (!action || !row) return;
    row.cells[3].textContent = String(action.x);
    row.cells[4].textContent = String(action.y);
  }

  function clearActionSelection() {
    if (state.selectedActionIndex >= 0) {
      state.actionEls[state.selectedActionIndex]?.handle.classList.remove('selected');
      state.actionRowEls[state.selectedActionIndex]?.classList.remove('selected');
    }
    state.selectedActionIndex = -1;
  }

  async function selectAction(index, center = false) {
    if (!state.doc || index < 0 || index >= (state.doc.spatialActions?.length || 0)) return;
    if (state.selectedIndex >= 0) {
      state.markerEls[state.selectedIndex]?.classList.remove('selected');
      state.rowEls[state.selectedIndex]?.classList.remove('selected');
      state.selectedIndex = -1;
      updateRangeVisibility();
    }
    clearActionSelection();
    state.selectedActionIndex = index;
    state.actionEls[index]?.handle.classList.add('selected');
    state.actionRowEls[index]?.classList.add('selected');
    state.actionRowEls[index]?.scrollIntoView({ block: 'nearest' });

    const action = state.doc.spatialActions[index];
    const source = actionSourcePoint(action, index);
    els.selectedName.textContent = action.label;
    els.selectedName.title = action.command;
    els.metaSlot.textContent = action.actorId || '—';
    els.metaId.textContent = action.targetId || '—';
    els.metaPos.textContent = `${action.x}, ${action.y}`;
    els.metaPlane.textContent = 'ACTION';
    els.metaRing.textContent = `from ${Math.round(source.x)}, ${Math.round(source.y)}`;
    els.metaRange.textContent = action.kind === 'clone' ? 'clone destination' : 'move destination';
    els.metaStatus.textContent = 'Editable';
    els.metaRing.className = '';
    els.metaRange.className = '';
    els.metaStatus.className = 'ok';
    els.xInput.value = action.x;
    els.yInput.value = action.y;
    updateFootprintControls(null);
    els.portrait.style.display = 'none';
    els.portraitFallback.style.display = 'block';
    syncControls();
    if (center) ensureMarkerVisible(action);
  }

  function moveAction(index, x, y, record = true, markDirty = true) {
    if (!state.doc || index < 0 || index >= (state.doc.spatialActions?.length || 0)) return false;
    const action = state.doc.spatialActions[index];
    const nextX = Math.round(clamp(Number(x) || 0, 0, state.doc.strategyWidth));
    const nextY = Math.round(clamp(Number(y) || 0, 0, state.doc.strategyHeight));
    if (action.x === nextX && action.y === nextY) return false;
    const oldX = action.x;
    const oldY = action.y;
    action.x = nextX;
    action.y = nextY;
    if (record) {
      state.undo.push({ kind: 'action', index, oldX, oldY, newX: nextX, newY: nextY });
      state.redo = [];
    }
    updateActionPosition(index);
    updateActionRow(index);
    refreshActionGeometry();
    if (state.selectedActionIndex === index) {
      els.xInput.value = nextX;
      els.yInput.value = nextY;
    }
    if (markDirty) setDirty(true);
    syncControls();
    return true;
  }

  function buildRows() {
    els.placementRows.replaceChildren();
    state.rowEls = state.doc.placements.map((p, index) => {
      const tr = document.createElement('tr');
      tr.dataset.index = String(index);
      tr.appendChild(cell(String(index + 1), 'c-idx'));
      tr.appendChild(cell(p.towerName || `Slot ${p.slot}`));
      tr.appendChild(cell(String(p.x), 'c-num'));
      tr.appendChild(cell(String(p.y), 'c-num'));
      tr.addEventListener('click', () => selectPlacement(index, true));
      els.placementRows.appendChild(tr);
      updateRow(index, tr, p);
      return tr;
    });
    if (!state.rowEls.length) emptyRow(els.placementRows, 4, 'This strategy has no SpawnTower placements.');
    if (state.selectedIndex >= 0) state.rowEls[state.selectedIndex]?.classList.add('selected');
    applyLayerFilter();
    updateReplaySummary();
  }

  function emptyRow(tbody, columns, text) {
    const tr = document.createElement('tr');
    tr.className = 'empty-row';
    const td = document.createElement('td');
    td.colSpan = columns;
    td.textContent = text;
    tr.appendChild(td);
    tbody.appendChild(tr);
  }

  function cell(text, className = '') {
    const td = document.createElement('td');
    if (className) td.className = className;
    td.textContent = text;
    return td;
  }

  function updateRow(index, row, p) {
    const tr = row || state.rowEls[index];
    const placement = p || state.doc?.placements[index];
    if (!tr || !placement) return;
    tr.cells[2].textContent = String(placement.x);
    tr.cells[3].textContent = String(placement.y);
    const status = replayStatus(placement, index);
    if (state.replay.state || status !== 'pending') {
      tr.dataset.status = status;
      tr.title = `${placement.towerName || `Slot ${placement.slot}`} • ${replayStatusLabel(placement, index)}`;
    } else {
      delete tr.dataset.status;
      tr.removeAttribute('title');
    }
  }

  function applyLayerFilter() {
    if (!state.doc) return;
    let visible = 0;
    state.doc.placements.forEach((p, i) => {
      const show = state.activeSlot === 0 || Number(p.slot) === state.activeSlot;
      state.markerEls[i]?.classList.toggle('hidden', !show);
      state.footprintEls[i]?.classList.toggle('hidden', !show);
      if (state.rowEls[i]) state.rowEls[i].hidden = !show;
      if (show) visible++;
    });
    updateRangeVisibility();
    els.placementCount.textContent = String(visible);
    if (state.selectedIndex >= 0) {
      const p = state.doc.placements[state.selectedIndex];
      if (state.activeSlot !== 0 && Number(p.slot) !== state.activeSlot) clearSelection();
    }
    updateSummary();
  }

  function updateSummary() {
    if (!state.doc) {
      els.summaryText.textContent = '';
      return;
    }
    const total = state.doc.placements.length;
    const actionTotal = state.doc.spatialActions?.length || 0;
    const overlaps = state.collisionPairs.size;
    els.summaryText.textContent = `${total} placement${total === 1 ? '' : 's'} · ${actionTotal} action${actionTotal === 1 ? '' : 's'} · ${overlaps} overlap${overlaps === 1 ? '' : 's'}`;
    els.summaryText.title = overlaps
      ? 'Placement hitboxes that intersect on the same plane. Attack ranges are ignored here.'
      : '';
  }

  function updateHealth() {
    if (!state.doc) {
      els.healthInfo.textContent = '—';
      return;
    }
    const placements = state.doc.placements;
    const verified = placements.filter((p) => Boolean(p.footprintKnown)).length;
    const ranged = placements.filter((p) => rangeKnown(p)).length;
    const portraits = `${state.portraitStatus.available}/${state.portraitStatus.total}`;
    const pairs = state.collisionPairs.size;
    els.healthInfo.textContent = `${portraits} art • ${verified}/${placements.length} hitbox • ${ranged}/${placements.length} range • ${pairs} overlap${pairs === 1 ? '' : 's'}`;
    els.healthInfo.title = `Portraits ${portraits}; verified footprint data ${verified}/${placements.length}; verified range data ${ranged}/${placements.length}; overlapping hitbox pairs ${pairs}.`;
  }

  async function selectPlacement(index, center = false) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return;
    clearActionSelection();
    if (state.selectedIndex >= 0) {
      state.markerEls[state.selectedIndex]?.classList.remove('selected');
      state.rowEls[state.selectedIndex]?.classList.remove('selected');
    }
    state.selectedIndex = index;
    state.markerEls[index]?.classList.add('selected');
    state.rowEls[index]?.classList.add('selected');
    updateRangeVisibility();
    state.rowEls[index]?.scrollIntoView({ block: 'nearest' });

    const p = state.doc.placements[index];
    els.selectedName.textContent = p.towerName || `Slot ${p.slot}`;
    els.selectedName.title = p.towerName || '';
    renderSelectedMeta();
    els.xInput.value = p.x;
    els.yInput.value = p.y;
    updateFootprintControls(p);
    syncControls();
    await updatePortrait(p.towerName || '');
    if (center) ensureMarkerVisible(p);
  }

  function renderSelectedMeta() {
    const index = state.selectedIndex;
    if (index < 0 || !state.doc) return;
    const p = state.doc.placements[index];
    const overlapping = state.collisionSet.has(index);
    const status = replayStatus(p, index);

    els.metaSlot.textContent = `${p.slot} · #${index + 1}`;
    els.metaId.textContent = p.towerId || '—';
    els.metaPos.textContent = `${p.x}, ${p.y}`;
    els.metaPlane.textContent = String(p.placementType || 'unknown').toUpperCase();
    els.metaRing.textContent = `${effectiveFootprint(p).toFixed(2)} studs · ${Object.hasOwn(p, 'footprintOverride') ? 'custom' : p.footprintStatus || 'estimated'}${overlapping ? ' · overlap' : ''}`;
    els.metaRing.className = overlapping ? 'bad' : '';
    const studs = rangeStuds(p);
    const levels = rangeLevels(p);
    const pathNum = Number(p.upgradePath || 0);
    const pathLabel = pathNum === 1 ? ' · path A' : pathNum === 2 ? ' · path B' : '';
    els.metaRange.textContent =
      studs > 0 ? `${studs} studs · lvl ${upgradeLevel(p)}${levels.length ? `/${levels.length - 1}` : ''}${pathLabel}` : 'no data';
    els.metaRange.className = studs > 0 ? (rangeKnown(p) ? '' : 'warn') : 'warn';
    els.metaRange.title =
      studs > 0
        ? `${p.towerName || `Slot ${p.slot}`} range per level: ${levels.join(', ')} studs (${p.rangeStatus || 'unknown'}). This strategy buys ${Number(p.upgrades) || 0} upgrade${Number(p.upgrades) === 1 ? '' : 's'}${pathNum ? ` on path ${pathNum === 1 ? 'A' : 'B'}` : ''}.`
        : 'The tower catalog has no published range for this tower.';
    els.metaStatus.textContent = replayStatusLabel(p, index);
    els.metaStatus.className =
      status === 'failed' || status === 'upgrade_failed'
        ? 'bad'
        : status === 'upgraded'
          ? 'ok'
          : status === 'placed' || status === 'upgrading'
            ? 'warn'
            : '';
  }

  function clearSelection() {
    clearActionSelection();
    if (state.selectedIndex >= 0) {
      state.markerEls[state.selectedIndex]?.classList.remove('selected');
      state.rowEls[state.selectedIndex]?.classList.remove('selected');
    }
    state.selectedIndex = -1;
    updateRangeVisibility();
    els.selectedName.textContent = 'Nothing selected';
    els.selectedName.title = '';
    for (const el of [
      els.metaSlot,
      els.metaId,
      els.metaPos,
      els.metaPlane,
      els.metaRing,
      els.metaRange,
      els.metaStatus,
    ]) {
      el.textContent = '—';
      el.className = '';
    }
    els.xInput.value = '';
    els.yInput.value = '';
    updateFootprintControls(null);
    els.portrait.style.display = 'none';
    els.portraitFallback.style.display = 'block';
    els.portraitSkeleton.hidden = true;
    syncControls();
  }

  function ensureMarkerVisible(p) {
    const rect = els.viewport.getBoundingClientRect();
    const dp = displayPoint(p);
    const sx = state.offsetX + dp.x * state.scale;
    const sy = state.offsetY + dp.y * state.scale;
    const pad = 60;
    if (sx < pad || sx > rect.width - pad || sy < pad || sy > rect.height - pad) {
      state.offsetX = rect.width / 2 - dp.x * state.scale;
      state.offsetY = rect.height / 2 - dp.y * state.scale;
      applyWorldTransform();
    }
  }

  async function updatePortrait(name) {
    els.portrait.style.display = 'none';
    els.portraitFallback.style.display = 'block';
    if (!name) {
      els.portraitSkeleton.hidden = true;
      return;
    }

    els.portraitSkeleton.hidden = false;
    if (!state.portraitCache.has(name)) {
      try {
        ensureHost();
        const data = await ahk.GetPortrait(name);
        state.portraitCache.set(name, data ? String(data) : '');
      } catch {
        state.portraitCache.set(name, '');
      }
    }
    els.portraitSkeleton.hidden = true;

    const stillSelected =
      state.selectedIndex >= 0 && (state.doc.placements[state.selectedIndex].towerName || '') === name;
    const src = state.portraitCache.get(name);
    if (src && stillSelected) {
      els.portrait.src = src;
      els.portrait.style.display = 'block';
      els.portraitFallback.style.display = 'none';
    }
    refreshPortraitStatus().then(updateHealth);
  }

  function applyPortraitStatus(payload) {
    const total = Number(payload?.total || 0);
    const available = Number(payload?.available || 0);
    const missing = Array.isArray(payload?.missing) ? payload.missing : [];
    state.portraitStatus = { total, available, missing };
    els.portraitStatusBadge.textContent = `${available}/${total}`;
    els.portraitStatusBadge.classList.toggle('complete', total > 0 && available >= total);
    els.portraitStatusBadge.title = missing.length
      ? `Missing: ${missing.join(', ')}`
      : total
        ? 'All loadout portraits are cached'
        : 'No strategy loaded';
  }

  async function refreshPortraitStatus() {
    if (!state.doc) {
      applyPortraitStatus({ total: 0, available: 0, missing: [] });
      return state.portraitStatus;
    }
    try {
      ensureHost();
      const raw = await ahk.GetPortraitStatus();
      applyPortraitStatus(raw ? JSON.parse(String(raw)) : null);
    } catch {
      applyPortraitStatus({ total: state.doc.requiredTowers.length, available: 0, missing: [] });
    }
    return state.portraitStatus;
  }

  async function refreshSelectedPortrait() {
    if (!state.doc || state.selectedIndex < 0) return;
    const name = state.doc.placements[state.selectedIndex].towerName || '';
    if (!name) return;
    const done = busy(els.refreshSelectedBtn, 'Fetching…');
    try {
      ensureHost();
      setStatus(`Refreshing the ${name} portrait…`);
      const data = await ahk.RefreshPortrait(name);
      state.portraitCache.delete(name);
      if (data) state.portraitCache.set(name, String(data));
      await updatePortrait(name);
      setStatus(data ? `${name} portrait refreshed.` : `Could not refresh ${name}; the previous portrait was kept.`);
      toast(
        data ? `${name} portrait refreshed.` : `${name} portrait could not be refreshed.`,
        data ? 'success' : 'warn',
      );
    } catch (err) {
      setStatus(`Portrait refresh failed: ${err.message || err}`);
    } finally {
      done();
    }
  }

  async function syncLoadoutPortraits() {
    if (!state.doc) return;
    const done = busy(els.syncPortraitsBtn, 'Repairing…');
    try {
      ensureHost();
      setStatus('Syncing missing portraits for this loadout…');
      const raw = await ahk.SyncLoadoutPortraits();
      state.portraitCache.clear();
      let payload = null;
      try {
        payload = raw ? JSON.parse(String(raw)) : null;
      } catch {
        payload = null;
      }
      if (payload) applyPortraitStatus(payload);
      else await refreshPortraitStatus();
      if (state.selectedIndex >= 0) await updatePortrait(state.doc.placements[state.selectedIndex].towerName || '');
      updateHealth();
      const missing = state.portraitStatus.missing;
      const ready = `${state.portraitStatus.available}/${state.portraitStatus.total}`;
      setStatus(
        missing.length
          ? `Portrait sync finished • ${ready} ready • missing: ${missing.join(', ')}.`
          : `Portraits ready • ${ready}.`,
      );
      toast(
        missing.length
          ? `Portrait repair finished: ${ready} ready.`
          : `All ${state.portraitStatus.total} loadout portraits are ready.`,
        missing.length ? 'warn' : 'success',
      );
    } catch (err) {
      setStatus(`Portrait sync failed: ${err.message || err}`);
    } finally {
      done();
    }
  }

  function updateFootprintControls(p) {
    const selected = p || (state.selectedIndex >= 0 ? state.doc?.placements[state.selectedIndex] : null);
    const enabled = Boolean(selected);
    const value = enabled ? effectiveFootprint(selected) : 1.5;

    els.footprintInput.disabled = !enabled;
    els.footprintInput.value = String(value);
    els.footprintValue.textContent = enabled ? value.toFixed(2) : '—';

    els.syncFootprintBtn.disabled = !enabled;
    els.syncFootprintBtn.title = enabled
      ? `Apply ${value.toFixed(2)} to every ${selected.towerName || `slot ${selected.slot}`} placement`
      : 'Select a placement first';
    els.resetFootprintBtn.disabled = !enabled || !Object.hasOwn(selected, 'footprintOverride');
    els.resetFootprintBtn.title = enabled
      ? `Reset to the catalog size (${catalogFootprint(selected).toFixed(2)})`
      : 'Select a placement first';
  }

  function setFootprint(index, value, reset = false) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return;
    const p = state.doc.placements[index];
    if (reset) delete p.footprintOverride;
    else p.footprintOverride = Math.round(clamp(Number(value) || catalogFootprint(p), 0.25, 4) * 100) / 100;

    updateFootprintPosition(index);
    recomputeCollisions();
    updateFootprintControls(p);
    if (state.selectedIndex === index) renderSelectedMeta();
    updateHealth();
    setStatus(
      `${p.towerName || `Slot ${p.slot}`} placement footprint set to ${effectiveFootprint(p).toFixed(2)} studs for this editor session.`,
    );
  }

  function syncFootprintAcrossTower() {
    if (!state.doc || state.selectedIndex < 0) return;
    const selected = state.doc.placements[state.selectedIndex];
    const targetName = String(selected.towerName || '')
      .trim()
      .toLowerCase();
    const targetSlot = Number(selected.slot) || 0;
    const value = effectiveFootprint(selected);
    let count = 0;

    state.doc.placements.forEach((placement, index) => {
      const sameTower = targetName
        ? String(placement.towerName || '')
          .trim()
          .toLowerCase() === targetName
        : (Number(placement.slot) || 0) === targetSlot;
      if (!sameTower) return;
      placement.footprintOverride = value;
      updateFootprintPosition(index);
      count++;
    });

    recomputeCollisions();
    updateFootprintControls(selected);
    renderSelectedMeta();
    updateHealth();
    setStatus(
      `Synced footprint ${value.toFixed(2)} studs to ${count} ${selected.towerName || `slot ${selected.slot}`} placement${count === 1 ? '' : 's'}.`,
    );
  }

  function movePlacement(index, x, y, record = true, markDirty = true) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return false;
    const p = state.doc.placements[index];
    const nextX = Math.round(clamp(Number(x) || 0, 0, state.doc.strategyWidth));
    const nextY = Math.round(clamp(Number(y) || 0, 0, state.doc.strategyHeight));
    if (p.x === nextX && p.y === nextY) return false;

    const oldX = p.x,
      oldY = p.y;
    p.x = nextX;
    p.y = nextY;
    if (record) {
      state.undo.push({ kind: 'placement', index, oldX, oldY, newX: nextX, newY: nextY });
      state.redo = [];
    }

    updateMarkerPosition(index);
    updateFootprintPosition(index);
    updateRangePosition(index);
    updateRow(index);
    refreshActionGeometry();
    recomputeCollisions();
    if (state.selectedIndex === index) {
      els.xInput.value = nextX;
      els.yInput.value = nextY;
      renderSelectedMeta();
    }
    if (markDirty) setDirty(true);
    syncControls();
    return true;
  }

  function applyCoordinateInputs() {
    if (state.selectedIndex < 0 && state.selectedActionIndex < 0) return;
    const rawX = els.xInput.value.trim();
    const rawY = els.yInput.value.trim();
    if (rawX === '' || rawY === '' || !Number.isFinite(Number(rawX)) || !Number.isFinite(Number(rawY))) {
      const selected = state.selectedActionIndex >= 0
        ? state.doc.spatialActions[state.selectedActionIndex]
        : state.doc.placements[state.selectedIndex];
      els.xInput.value = selected.x;
      els.yInput.value = selected.y;
      toast('X and Y must both be numbers.', 'warn');
      return;
    }
    if (state.selectedActionIndex >= 0) {
      if (moveAction(state.selectedActionIndex, rawX, rawY, true)) {
        const action = state.doc.spatialActions[state.selectedActionIndex];
        setStatus(`${action.label} destination moved to (${action.x}, ${action.y}).`);
      }
      return;
    }
    if (movePlacement(state.selectedIndex, rawX, rawY, true)) {
      const p = state.doc.placements[state.selectedIndex];
      setStatus(`${p.towerName || `Slot ${p.slot}`} moved to (${p.x}, ${p.y}).`);
    }
  }

  function undo() {
    const item = state.undo.pop();
    if (!item) return;
    if (item.kind === 'action') {
      moveAction(item.index, item.oldX, item.oldY, false, false);
      state.redo.push(item);
      selectAction(item.index, true);
    } else {
      movePlacement(item.index, item.oldX, item.oldY, false, false);
      state.redo.push(item);
      selectPlacement(item.index, true);
    }
    setDirty(state.undo.length > 0);
    syncControls();
  }

  function redo() {
    const item = state.redo.pop();
    if (!item) return;
    if (item.kind === 'action') {
      moveAction(item.index, item.newX, item.newY, false, false);
      state.undo.push(item);
      selectAction(item.index, true);
    } else {
      movePlacement(item.index, item.newX, item.newY, false, false);
      state.undo.push(item);
      selectPlacement(item.index, true);
    }
    setDirty(true);
    syncControls();
  }

  function setDirty(value) {
    state.dirty = Boolean(value);
    els.docDirty.hidden = !state.dirty;
    els.saveCopyBtn.classList.toggle('is-dirty', state.dirty);
    els.overwriteBtn.classList.toggle('is-dirty', state.dirty);
  }

  function renderText() {
    if (!state.doc) return '';
    const lines = state.doc.text.replace(/\r/g, '').split('\n');
    for (const p of state.doc.placements) {
      const idx = Number(p.lineNo) - 1;
      if (idx < 0 || idx >= lines.length) continue;
      lines[idx] = lines[idx].replace(/^(\s*SpawnTower\(\s*)-?\d+(\s*,\s*)-?\d+(.*)$/i, `$1${p.x}$2${p.y}$3`);
    }
    for (const action of state.doc.spatialActions || []) {
      const idx = Number(action.lineNo) - 1;
      if (idx < 0 || idx >= lines.length || !window.StrategySpatial?.rewriteLine) continue;
      lines[idx] = window.StrategySpatial.rewriteLine(lines[idx], action);
    }
    return lines.join(state.doc.newline || '\r\n');
  }

  async function saveCopy() {
    if (!state.doc) return;
    if (!(await applyCodeEdits())) return;
    const done = busy(els.saveCopyBtn, 'Saving…');
    try {
      ensureHost();
      const result = await ahk.SaveCopy(renderText());
      if (result) {
        setStatus(`Saved copy: ${String(result)}`);
        toast('Strategy copy saved. The original is unchanged.', 'success');
      } else {
        setStatus('Save canceled.');
      }
    } catch (err) {
      setStatus(`Save failed: ${err.message || err}`);
      toast(`Save failed: ${err.message || err}`, 'error');
    } finally {
      done();
    }
  }

  async function overwrite() {
    if (!state.doc) return;
    if (!(await applyCodeEdits())) return;
    const confirmed = await askConfirm({
      title: 'Overwrite the original strategy?',
      body: `${state.doc.name} is rewritten in place. A timestamped backup of the current file is created first.`,
      confirmLabel: 'Overwrite',
      danger: true,
    });
    if (!confirmed) {
      setStatus('Overwrite canceled.');
      return;
    }

    const done = busy(els.overwriteBtn, 'Saving…');
    try {
      ensureHost();
      const text = renderText();
      const result = await ahk.OverwriteStrategy(text);
      if (result) {
        state.doc.text = text;
        state.undo = [];
        state.redo = [];
        setDirty(false);
        if (state.codeMode) syncCodeEditor();
        syncControls();
        setStatus(`Saved. Backup: ${String(result)}`);
        toast('Original strategy saved and a backup was created.', 'success');
      } else {
        setStatus('Overwrite canceled.');
      }
    } catch (err) {
      setStatus(`Overwrite failed: ${err.message || err}`);
      toast(`Overwrite failed: ${err.message || err}`, 'error');
    } finally {
      done();
    }
  }

  function fitWorld(reset = false) {
    if (!state.doc || state.codeMode) return;
    const rect = els.viewport.getBoundingClientRect();
    if (rect.width < 2 || rect.height < 2) return;
    const margin = 16;
    state.fitScale = Math.max(
      0.01,
      Math.min(
        (rect.width - margin * 2) / state.doc.strategyWidth,
        (rect.height - margin * 2) / state.doc.strategyHeight,
      ),
    );
    if (reset || state.scale < state.fitScale) state.scale = state.fitScale;
    state.offsetX = (rect.width - state.doc.strategyWidth * state.scale) / 2;
    state.offsetY = (rect.height - state.doc.strategyHeight * state.scale) / 2;
    applyWorldTransform();
  }

  function applyWorldTransform() {
    els.world.style.transform = `translate3d(${state.offsetX}px, ${state.offsetY}px, 0) scale(${state.scale})`;
    els.zoomLabel.textContent = `${Math.round((state.scale / state.fitScale) * 100)}%`;
  }

  function screenToWorld(clientX, clientY) {
    const rect = els.viewport.getBoundingClientRect();
    return {
      x: (clientX - rect.left - state.offsetX) / state.scale,
      y: (clientY - rect.top - state.offsetY) / state.scale,
    };
  }

  function worldToStrategy(clientX, clientY) {
    const pt = screenToWorld(clientX, clientY);
    return {
      x: Math.round(clamp(pt.x - Number(state.doc.geometryOffsetX || 0), 0, state.doc.strategyWidth)),
      y: Math.round(clamp(pt.y - Number(state.doc.geometryOffsetY || 0), 0, state.doc.strategyHeight)),
    };
  }

  function placeSelectedAtPointer(clientX, clientY) {
    if (!state.doc) return;
    const target = worldToStrategy(clientX, clientY);
    if (state.selectedActionIndex >= 0) {
      const index = state.selectedActionIndex;
      const action = state.doc.spatialActions[index];
      if (moveAction(index, target.x, target.y, true, true))
        setStatus(`${action.label} destination moved to (${target.x}, ${target.y}).`);
      return;
    }
    if (state.selectedIndex < 0) {
      setStatus('Select a placement or action first, then right-click the map to move it there.');
      toast('Select a placement or action first, then right-click the map.', 'info', 2600);
      return;
    }
    const index = state.selectedIndex;
    const p = state.doc.placements[index];
    if (movePlacement(index, target.x, target.y, true, true)) {
      const overlap = state.collisionSet.has(index) ? ' • projected overlap' : '';
      setStatus(`Placed ${p.towerName || `Slot ${p.slot}`} at (${target.x}, ${target.y})${overlap}.`);
    } else {
      setStatus(`${p.towerName || `Slot ${p.slot}`} is already at (${target.x}, ${target.y}).`);
    }
  }

  function markerPointerDown(ev) {
    if (!state.doc || ev.button !== 0 || state.calibration.marking) return;
    ev.preventDefault();
    ev.stopPropagation();
    const index = Number(ev.currentTarget.dataset.index);
    selectPlacement(index, false);
    const p = state.doc.placements[index];
    state.dragging = { pointerId: ev.pointerId, index, oldX: p.x, oldY: p.y };
    ev.currentTarget.setPointerCapture(ev.pointerId);
  }

  function markerPointerMove(ev) {
    if (!state.dragging || ev.pointerId !== state.dragging.pointerId) return;
    const index = state.dragging.index;
    const p = state.doc.placements[index];
    const target = worldToStrategy(ev.clientX, ev.clientY);
    if (p.x === target.x && p.y === target.y) return;
    p.x = target.x;
    p.y = target.y;
    updateMarkerPosition(index);
    updateFootprintPosition(index);
    updateRangePosition(index);
    updateRow(index);
    refreshActionGeometry();
    recomputeCollisions(index);
    if (state.selectedIndex === index) {
      els.xInput.value = p.x;
      els.yInput.value = p.y;
      renderSelectedMeta();
    }
  }

  function finishMarkerDrag(ev) {
    if (!state.dragging || ev.pointerId !== state.dragging.pointerId) return;
    const drag = state.dragging;
    state.dragging = null;
    const p = state.doc.placements[drag.index];
    if (p.x === drag.oldX && p.y === drag.oldY) return;

    state.undo.push({ kind: 'placement', index: drag.index, oldX: drag.oldX, oldY: drag.oldY, newX: p.x, newY: p.y });
    state.redo = [];
    setDirty(true);
    syncControls();
    recomputeCollisions();
    const overlap = state.collisionSet.has(drag.index) ? ' • projected overlap' : '';
    setStatus(`Moved ${p.towerName || `Slot ${p.slot}`} to (${p.x}, ${p.y})${overlap}.`);
  }


  function actionPointerDown(ev) {
    if (!state.doc || ev.button !== 0 || state.calibration.marking) return;
    ev.preventDefault();
    ev.stopPropagation();
    const index = Number(ev.currentTarget.dataset.index);
    selectAction(index, false);
    const action = state.doc.spatialActions[index];
    state.actionDragging = { pointerId: ev.pointerId, index, oldX: action.x, oldY: action.y };
    ev.currentTarget.classList.add('dragging');
    ev.currentTarget.setPointerCapture(ev.pointerId);
  }

  function actionPointerMove(ev) {
    if (!state.actionDragging || ev.pointerId !== state.actionDragging.pointerId) return;
    const index = state.actionDragging.index;
    const action = state.doc.spatialActions[index];
    const target = worldToStrategy(ev.clientX, ev.clientY);
    if (action.x === target.x && action.y === target.y) return;
    action.x = target.x;
    action.y = target.y;
    updateActionPosition(index);
    updateActionRow(index);
    refreshActionGeometry();
    if (state.selectedActionIndex === index) {
      els.xInput.value = action.x;
      els.yInput.value = action.y;
      els.metaPos.textContent = `${action.x}, ${action.y}`;
    }
  }

  function finishActionDrag(ev) {
    if (!state.actionDragging || ev.pointerId !== state.actionDragging.pointerId) return;
    const drag = state.actionDragging;
    state.actionDragging = null;
    state.actionEls[drag.index]?.handle.classList.remove('dragging');
    const action = state.doc.spatialActions[drag.index];
    if (action.x === drag.oldX && action.y === drag.oldY) return;
    state.undo.push({ kind: 'action', index: drag.index, oldX: drag.oldX, oldY: drag.oldY, newX: action.x, newY: action.y });
    state.redo = [];
    setDirty(true);
    syncControls();
    setStatus(`${action.label} destination moved to (${action.x}, ${action.y}).`);
  }

  els.actionLayer.addEventListener('pointermove', actionPointerMove);
  els.actionLayer.addEventListener('pointerup', finishActionDrag);
  els.actionLayer.addEventListener('pointercancel', finishActionDrag);

  for (const layer of [els.markerLayer, els.footprintLayer]) {
    layer.addEventListener('pointermove', markerPointerMove);
    layer.addEventListener('pointerup', finishMarkerDrag);
    layer.addEventListener('pointercancel', finishMarkerDrag);
  }

  els.viewport.addEventListener('contextmenu', (ev) => {
    if (!state.doc || state.calibration.marking) return;
    ev.preventDefault();
    const actionHandle = ev.target.closest('.action-handle');
    if (actionHandle) {
      const index = Number(actionHandle.dataset.index);
      if (Number.isInteger(index)) {
        selectAction(index, false);
        setStatus('Action selected. Right-click an empty map position to move its destination there.');
      }
      return;
    }
    const marker = ev.target.closest('.marker');
    if (marker) {
      const index = Number(marker.dataset.index);
      if (Number.isInteger(index)) {
        selectPlacement(index, false);
        setStatus('Selected. Right-click an empty map position to move it there.');
      }
      return;
    }
    placeSelectedAtPointer(ev.clientX, ev.clientY);
  });

  els.viewport.addEventListener('pointerdown', (ev) => {
    if (state.calibration.marking && ev.button === 0) {
      ev.preventDefault();
      addCalibrationMark(ev.clientX, ev.clientY);
      return;
    }
    if (!state.doc || ev.button !== 0 || ev.target.closest('.marker, .footprint, .action-handle')) return;
    ev.preventDefault();
    els.viewport.setPointerCapture(ev.pointerId);
    state.panning = {
      pointerId: ev.pointerId,
      startX: ev.clientX,
      startY: ev.clientY,
      ox: state.offsetX,
      oy: state.offsetY,
      moved: false,
    };
    els.viewport.classList.add('panning');
  });

  els.viewport.addEventListener('pointermove', (ev) => {
    if (!state.panning || ev.pointerId !== state.panning.pointerId) return;
    const dx = ev.clientX - state.panning.startX;
    const dy = ev.clientY - state.panning.startY;
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) state.panning.moved = true;
    state.offsetX = state.panning.ox + dx;
    state.offsetY = state.panning.oy + dy;
    applyWorldTransform();
  });

  function finishPan(ev) {
    if (!state.panning || ev.pointerId !== state.panning.pointerId) return;
    const tapped = ev.type === 'pointerup' && !state.panning.moved;
    state.panning = null;
    els.viewport.classList.remove('panning');
    if (tapped && (state.selectedIndex >= 0 || state.selectedActionIndex >= 0) && !state.calibration.marking) {
      clearSelection();
      setStatus('Selection cleared.');
    }
  }
  els.viewport.addEventListener('pointerup', finishPan);
  els.viewport.addEventListener('pointercancel', finishPan);

  els.viewport.addEventListener(
    'wheel',
    (ev) => {
      if (!state.doc) return;
      ev.preventDefault();
      const rect = els.viewport.getBoundingClientRect();
      const mouseX = ev.clientX - rect.left;
      const mouseY = ev.clientY - rect.top;
      const wx = (mouseX - state.offsetX) / state.scale;
      const wy = (mouseY - state.offsetY) / state.scale;
      const next = clamp(state.scale * (ev.deltaY < 0 ? 1.12 : 1 / 1.12), state.fitScale, state.fitScale * 6);
      state.offsetX = mouseX - wx * next;
      state.offsetY = mouseY - wy * next;
      state.scale = next;
      applyWorldTransform();
    },
    { passive: false },
  );

  function replayStatus(p, index) {
    if (p.replayFailed) return 'failed';
    return state.replay.steps.get(String(p.towerId || `tower_${index + 1}`)) || 'pending';
  }

  function replayStatusLabel(p, index) {
    switch (replayStatus(p, index)) {
      case 'upgraded':
        return 'Placed + upgraded';
      case 'upgrading':
        return 'Upgrading…';
      case 'upgrade_failed':
        return 'Placed • upgrade failed';
      case 'placed':
        return 'Placed';
      case 'failed':
        return 'Placement failed';
      default:
        return state.replay.state === 'running' ? 'Waiting' : 'Ready';
    }
  }

  function updateReplaySummary() {
    if (!state.doc) return;
    const counts = { placed: 0, upgrading: 0, upgraded: 0, upgrade_failed: 0, failed: 0 };
    state.doc.placements.forEach((p, index) => {
      const status = replayStatus(p, index);
      if (Object.hasOwn(counts, status)) counts[status]++;
    });
    els.replayPlacedCount.textContent = String(
      counts.placed + counts.upgrading + counts.upgraded + counts.upgrade_failed,
    );
    els.replayUpgradingCount.textContent = String(counts.upgrading);
    els.replayUpgradedCount.textContent = String(counts.upgraded);
    els.replayFailedCount.textContent = String(counts.failed + counts.upgrade_failed);
    els.replayBar.hidden = !state.replay.state;
  }

  function strategyReplayText() {
    if (!state.doc || !state.doc.placements.length) return { text: '', used: 0, skipped: 0 };
    let used = 0;
    let skipped = 0;
    state.doc.placements.forEach((placement) => {
      const slot = Number(placement.slot) || 0;
      if (slot < 1 || slot > 5) {
        skipped++;
        return;
      }
      used++;
    });
    return { text: used && !skipped ? `${renderText().replace(/\s*$/, '')}\r\n` : '', used, skipped };
  }

  function replayHeaderLines(width, height) {
    return [
      '[Settings]',
      `map=${state.doc.mapName || 'Sandbox'}`,
      'difficulty=Sandbox',
      `requiredTowers=${(state.doc.requiredTowers || []).slice(0, 5).join(', ')}`,
      'strategyLabMode=sandbox-replay',
      'autoSkip=OFF',
      'moveEnabled=false',
      'moveDirection=W',
      'moveDuration=750',
      '',
      '[DO NOT EDIT]',
      `width=${width}`,
      `height=${height}`,
      '',
      '[Steps]',
    ];
  }

  async function replayStrategyInSandbox() {
    if (!state.doc) return;
    if (!(await applyCodeEdits())) return;
    const payload = strategyReplayText();
    if (!payload.text) {
      toast(
        payload.skipped
          ? 'Every SpawnTower must use a loadout slot from 1 to 5 before the full strategy can be replayed.'
          : 'This strategy has no placements in loadout slots 1-5 to replay.',
        'warn',
        4200,
      );
      return;
    }
    const done = busy(els.replayStrategyBtn, 'Launching…');
    try {
      ensureHost();
      const result = await ahk.ReplayStrategySandbox(payload.text);
      if (result) {
        state.replay.state = 'running';
        state.replay.epoch++;
        state.replay.failedIds = new Set();
        state.replay.steps = new Map();
        state.replay.announced = new Map();
        state.doc.placements.forEach((p) => {
          p.replayFailed = false;
        });
        state.rowEls.forEach((row, index) => updateRow(index, row));
        updateReplaySummary();
        pollReplayStatus(state.replay.epoch);
        setStatus(`Full Sandbox strategy replay launched for ${payload.used} placement${payload.used === 1 ? '' : 's'}.`);
        toast(
          'Full strategy replay launched. Placements, requested upgrades, waits, and supported Enforcer actions will run in order.',
          'success',
          4800,
        );
      }
    } catch (err) {
      setStatus(`Sandbox replay failed to start: ${err.message || err}`);
      toast(`Sandbox replay failed: ${err.message || err}`, 'error');
    } finally {
      done();
    }
  }

  function stopReplayPolling() {
    state.replay.epoch++;
    if (state.replay.pollTimer) window.clearTimeout(state.replay.pollTimer);
    state.replay.pollTimer = 0;
  }

  async function pollReplayStatus(epoch) {
    if (!state.doc || epoch !== state.replay.epoch || !window.ahk?.GetReplayStatus) return;
    let complete = false;
    try {
      const raw = await ahk.GetReplayStatus();
      if (epoch !== state.replay.epoch) return;
      if (raw) complete = applyReplayStatus(JSON.parse(String(raw)));
    } catch { }
    if (complete || epoch !== state.replay.epoch) return;
    state.replay.pollTimer = window.setTimeout(() => pollReplayStatus(epoch), 700);
  }

  function applyReplayStatus(payload) {
    state.replay.state = String(payload.state || '');
    state.replay.failedIds = new Set(Array.isArray(payload.failed) ? payload.failed.map(String) : []);
    state.replay.steps = new Map(
      Array.isArray(payload.steps) ? payload.steps.map((s) => [String(s.id), String(s.status || 'pending')]) : [],
    );

    let footprintsChanged = false;
    state.doc.placements.forEach((placement, index) => {
      const id = String(placement.towerId || `tower_${index + 1}`);
      const failed = state.replay.failedIds.has(id);
      if (placement.replayFailed !== failed) {
        placement.replayFailed = failed;
        state.footprintEls[index]?.classList.toggle('replay-failed', failed);
        footprintsChanged = true;
      }

      const status = state.replay.steps.get(id) || 'pending';
      if (status !== state.replay.announced.get(id)) {
        state.replay.announced.set(id, status);
        announceReplayStep(placement, index, status);
        updateRow(index);
        if (index === state.selectedIndex) renderSelectedMeta();
      }
    });

    if (footprintsChanged) recomputeCollisions();
    updateReplaySummary();

    if (state.replay.state !== 'complete') return false;
    const failed = state.doc.placements.filter((p) => p.replayFailed).length;
    const upgraded = state.doc.placements.filter((p, index) => replayStatus(p, index) === 'upgraded').length;
    setStatus(
      failed
        ? `Sandbox replay complete • ${failed} tower${failed === 1 ? '' : 's'} unconfirmed.`
        : `Sandbox replay complete • ${upgraded} tower${upgraded === 1 ? '' : 's'} placed and upgraded.`,
    );
    return true;
  }

  function announceReplayStep(placement, index, status) {
    const name = placement.towerName || `Tower ${index + 1}`;
    switch (status) {
      case 'placed':
        return toast(`${name} placed. Preparing upgrade…`, 'success');
      case 'upgrading':
        return toast(`${name} placed. Checking upgrade…`, 'success');
      case 'upgraded':
        return toast(`${name} placed and upgraded.`, 'success');
      case 'upgrade_failed':
        return toast(`${name} was placed, but the upgrade was not confirmed.`, 'warn');
      case 'failed':
        return toast(`${name} could not be placed.`, 'warn');
      default:
        return undefined;
    }
  }

  function openCalibration(options = {}) {
    state.calibration.open = true;
    els.calibrationModal.hidden = false;
    populateCalibrationTowerOptions();
    renderCalibrationMarks();
    updateCalibrationControls();
    if (state.doc && !calibrationTowerCount()) {
      setStatus(
        'This strategy does not declare requiredTowers, so calibration has no tower ranges to measure against.',
      );
      toast('This strategy has no requiredTowers, so there is no published range to calibrate against.', 'warn', 5200);
    }
    if (options.autoPrepare === true) window.setTimeout(autoPrepareSandboxCalibration, 260);
  }

  function closeCalibration() {
    state.calibration.open = false;
    state.calibration.marking = false;
    els.calibrationModal.hidden = true;
    els.calibrationMarkHud.hidden = true;
    document.body.classList.remove('marking');
    restorePlacementSidebar();
    updateCalibrationControls();
  }

  async function autoPrepareSandboxCalibration() {
    if (!state.doc || String(state.doc.strategyLabMode || '').toLowerCase() !== 'sandbox-calibration') return;
    const docKey = String(state.doc.path || 'sandbox-calibration');
    if (state.calibration.autoPreparing || state.calibration.autoPreparedPath === docKey) return;

    state.calibration.autoPreparing = true;
    try {
      const ok = await captureCalibration('baseline', { auto: true, silentHost: true });
      if (ok) {
        state.calibration.autoPreparedPath = docKey;
        setStatus('Baseline ready. Go to Sandbox, place the five towers, then capture them.');
        toast('Baseline ready. Go to Sandbox and place the five towers.', 'success', 5200);
      } else {
        setStatus('Sandbox calibration is ready. Enter Sandbox, then click Re-align + baseline.');
        toast('Open Sandbox first, then use Re-align + baseline.', 'warn', 5000);
      }
    } finally {
      state.calibration.autoPreparing = false;
      updateCalibrationControls();
    }
  }

  function populateCalibrationTowerOptions() {
    const towers = state.doc?.requiredTowers || [];
    const previous = Number(els.calibrationTowerSelect.value || state.calibration.activeSlot || 1);
    const options = towers.slice(0, 5).map((name, idx) => {
      const opt = document.createElement('option');
      opt.value = String(idx + 1);
      opt.textContent = `Slot ${idx + 1} — ${name || 'Unknown'}`;
      return opt;
    });
    if (!options.length) {
      const opt = document.createElement('option');
      opt.value = '1';
      opt.textContent = 'Open a calibration .strat first';
      options.push(opt);
    }
    els.calibrationTowerSelect.replaceChildren(...options);
    els.calibrationTowerSelect.value = String(clamp(previous, 1, options.length));
    state.calibration.activeSlot = Number(els.calibrationTowerSelect.value) || 1;
  }

  function calibrationTowerCount() {
    return Math.min(5, state.doc?.requiredTowers?.length || 0);
  }

  function updateCalibrationControls() {
    const cal = state.calibration;
    const hasDoc = Boolean(state.doc);
    const markCount = cal.marks.length;
    const expected = calibrationTowerCount();
    const complete = expected > 0 && markCount >= expected;

    els.calibrationBaselineBtn.disabled = !hasDoc;
    els.calibrationBaselineBtn.title = hasDoc
      ? 'Re-apply the verified Ultimate Macro camera pose and save a new clean baseline.'
      : 'Open a strategy first.';

    els.calibrationManualBtn.disabled = !hasDoc || !cal.baselinePath;
    els.calibrationManualBtn.title = cal.baselinePath
      ? 'Re-align the camera, capture your placed towers, then start guided marking.'
      : 'Capture the clean baseline first.';

    els.calibrationGoSandboxBtn.disabled = false;
    els.calibrationGoSandboxBtn.title =
      'Focus the Roblox window so you can enter Sandbox and place the calibration towers.';

    els.calibrationMarkBtn.disabled = !hasDoc || !cal.manualPath;
    els.calibrationMarkBtn.textContent = cal.marking
      ? 'Pause marking'
      : markCount > 0 && markCount < expected
        ? `Continue marking (${markCount}/${expected})`
        : complete
          ? 'Review marks'
          : 'Start guided marking';

    els.calibrationExportBtn.disabled = !complete;
    els.calibrationExportBtn.title = complete
      ? 'Export the complete calibration replay .strat.'
      : `Mark all ${expected || 5} tower centers first.`;
    els.calibrationReplayBtn.disabled = !complete;
    els.calibrationReplayBtn.title = complete
      ? 'Replay every calibrated placement in the open Sandbox match.'
      : `Mark all ${expected || 5} tower centers first.`;

    els.calibrationMarkCount.textContent = expected ? `${markCount}/${expected}` : String(markCount);
    const solved = cal.solved;
    els.calibrationScaleInfo.textContent = solved
      ? `${solved.pixelsPerStud.toFixed(2)} px/stud • ${solved.samples} ring${solved.samples === 1 ? '' : 's'} • ${solved.model}`
      : 'Not solved';
    els.calibrationScaleInfo.title = solved
      ? `Solved from measured in-game range circles • RMSE ${solved.rmseX.toFixed(3)} px/stud • confidence ${Math.round(solved.confidence * 100)}%`
      : 'Mark a tower center whose range circle is visible to solve the pixels-per-stud scale.';
    els.calibrationSessionInfo.textContent = cal.sessionPath ? pathTail(cal.sessionPath) : 'Not started';
    els.calibrationSessionInfo.title = cal.sessionPath;
    els.calibrationBaselineInfo.textContent = cal.baselinePath ? pathTail(cal.baselinePath) : '—';
    els.calibrationBaselineInfo.title = cal.baselinePath;
    els.calibrationManualInfo.textContent = cal.manualPath ? pathTail(cal.manualPath) : '—';
    els.calibrationManualInfo.title = cal.manualPath;
    els.calibrationMacroInfo.textContent = cal.macroVersion
      ? `${cal.macroVersion} • ${cal.cameraContract || 'verified'}`
      : 'Not verified';
  }

  async function captureCalibration(stage, options = {}) {
    const cal = state.calibration;
    const button = stage === 'baseline' ? els.calibrationBaselineBtn : els.calibrationManualBtn;
    if (stage === 'manual' && !cal.baselinePath) {
      toast('Capture the clean baseline first; it is the camera reference for this session.', 'warn', 4600);
      return false;
    }

    const done = busy(button, stage === 'baseline' ? 'Aligning…' : 'Capturing…');
    try {
      ensureHost();
      setViewportLoading(
        true,
        stage === 'baseline' ? 'Aligning the Roblox camera…' : 'Capturing the manual tower sample…',
      );
      setStatus(
        stage === 'baseline'
          ? 'Calibration: aligning the camera and capturing a clean baseline…'
          : 'Calibration: re-aligning the same camera and capturing your manual placements…',
      );

      const raw = await ahk.CalibrationCapture(stage, state.doc?.mapName || 'Sandbox', options.silentHost === true);
      if (!raw) {
        setStatus(
          options.auto
            ? 'Sandbox is not ready for automatic camera preparation yet.'
            : 'Calibration capture canceled or unavailable.',
        );
        return false;
      }

      const payload = JSON.parse(String(raw));
      if (payload.sessionPath) cal.sessionPath = payload.sessionPath;
      cal.clientWidth = Number(payload.clientWidth) || state.doc?.strategyWidth || 1920;
      cal.clientHeight = Number(payload.clientHeight) || state.doc?.strategyHeight || 1009;
      cal.macroVersion = String(payload.macroVersion || '');
      cal.cameraContract = String(payload.cameraContract || '');

      if (stage === 'baseline') {
        cal.baselinePath = payload.path || '';
        cal.manualPath = '';
        cal.marks = [];
        if (state.doc && cal.clientWidth > 0 && cal.clientHeight > 0) {
          state.doc.strategyWidth = cal.clientWidth;
          state.doc.strategyHeight = cal.clientHeight;
          els.world.style.width = `${cal.clientWidth}px`;
          els.world.style.height = `${cal.clientHeight}px`;
          els.resolutionInfo.textContent = `${cal.clientWidth} × ${cal.clientHeight} • captured`;
        }
        renderCalibrationMarks();
        requestAnimationFrame(() => fitWorld(true));
      } else {
        cal.manualPath = payload.path || '';
      }

      setMapPayload(payload);
      updateCalibrationControls();
      toast(
        stage === 'baseline'
          ? 'Baseline captured. Place your towers manually in Sandbox next.'
          : 'Manual tower sample captured after automatic camera re-alignment.',
        'success',
        3800,
      );

      if (stage === 'manual') window.setTimeout(() => beginGuidedMarking({ restart: true }), 180);
      return true;
    } catch (err) {
      setStatus(`Calibration capture failed: ${err.message || err}`);
      if (!options.auto) toast(`Calibration capture failed: ${err.message || err}`, 'error');
      return false;
    } finally {
      setViewportLoading(false);
      done();
    }
  }

  function firstUnmarkedCalibrationSlot(preferred = 1) {
    const total = calibrationTowerCount();
    if (!total) return 1;
    const marked = new Set(state.calibration.marks.map((m) => Number(m.slot)));
    const start = clamp(Number(preferred) || 1, 1, total);
    if (!marked.has(start)) return start;
    for (let slot = 1; slot <= total; slot++) {
      if (!marked.has(slot)) return slot;
    }
    return start;
  }

  function beginGuidedMarking(options = {}) {
    if (!state.doc) {
      toast('Open a calibration .strat first.', 'warn');
      return;
    }
    if (!state.calibration.manualPath) {
      toast('Capture the placed towers first so marking can use that exact screenshot.', 'warn', 4300);
      return;
    }
    const total = calibrationTowerCount();
    if (!total) {
      toast('This calibration strategy does not declare any loadout towers.', 'warn');
      return;
    }

    state.calibration.activeSlot =
      options.restart === true && !state.calibration.marks.length
        ? 1
        : firstUnmarkedCalibrationSlot(Number(els.calibrationTowerSelect.value || state.calibration.activeSlot || 1));
    els.calibrationTowerSelect.value = String(state.calibration.activeSlot);

    state.calibration.marking = true;
    state.calibration.open = false;
    els.calibrationModal.hidden = true;
    document.body.classList.add('marking');
    renderCalibrationMarkHud();
    renderCalibrationSidebar();
    updateCalibrationControls();
    requestAnimationFrame(() => fitWorld(true));
    setStatus(`Guided calibration: mark Slot ${state.calibration.activeSlot} on the captured image.`);
    toast('Click the CENTER of each tower. Its cyan range circle is measured to solve pixels per stud.', 'info', 4600);
  }

  function pauseGuidedMarkingAndReturn() {
    state.calibration.marking = false;
    document.body.classList.remove('marking');
    els.calibrationMarkHud.hidden = true;
    openCalibration();
    renderCalibrationMarks();
  }

  function toggleCalibrationMarking() {
    if (state.calibration.marking) pauseGuidedMarkingAndReturn();
    else beginGuidedMarking();
  }

  function renderCalibrationMarkHud() {
    if (!state.calibration.marking) {
      els.calibrationMarkHud.hidden = true;
      return;
    }
    const total = calibrationTowerCount();
    const slot = clamp(Number(state.calibration.activeSlot) || 1, 1, Math.max(1, total));
    const tower = state.doc?.requiredTowers?.[slot - 1] || `Slot ${slot}`;
    els.calibrationMarkHud.hidden = false;
    els.calibrationMarkProgress.textContent = `MARK ${Math.min(state.calibration.marks.length + 1, total)}/${total}`;
    els.calibrationMarkTower.textContent = `Slot ${slot} — ${tower}`;
    els.calibrationMarkInstruction.textContent =
      'Click the center of the tower; its cyan range circle is measured to solve the stud scale.';
  }

  function renderCalibrationSidebar() {
    if (!state.doc) return;
    const total = calibrationTowerCount();
    els.placementHeading.textContent = 'Marks';
    els.placementCount.textContent = `${state.calibration.marks.length}/${total}`;
    showRailPanel('placements');
    els.placementRows.replaceChildren();

    for (let slot = 1; slot <= total; slot++) {
      const tower = state.doc.requiredTowers[slot - 1] || `Slot ${slot}`;
      const mark = state.calibration.marks.find((m) => Number(m.slot) === slot);
      const tr = document.createElement('tr');
      if (!mark) tr.className = 'mark-pending';
      tr.appendChild(cell(String(slot), 'c-idx'));
      tr.appendChild(cell(tower));
      tr.appendChild(cell(mark ? String(mark.x) : '—', 'c-num'));
      tr.appendChild(cell(mark ? String(mark.y) : '—', 'c-num'));
      els.placementRows.appendChild(tr);
    }

    const slot = clamp(Number(state.calibration.activeSlot) || 1, 1, Math.max(1, total));
    els.selectedName.textContent = state.calibration.marking
      ? `Mark ${state.doc.requiredTowers[slot - 1] || `Slot ${slot}`}`
      : 'Calibration marks';
    els.metaSlot.textContent = String(slot);
    els.metaId.textContent = 'calibration';
    els.metaPos.textContent = `${state.calibration.marks.length}/${total} recorded`;
    els.metaPlane.textContent = 'CLIENT';
    els.metaRing.textContent = 'catalog';
    els.metaRange.textContent = state.calibration.solved
      ? `${state.calibration.solved.pixelsPerStud.toFixed(2)} px/stud`
      : 'measured on click';
    els.metaStatus.textContent = state.calibration.marking ? 'Marking' : 'Paused';
  }

  function restorePlacementSidebar() {
    if (!state.doc) return;
    els.placementHeading.textContent = 'Placements';
    buildRows();
    if (state.selectedIndex >= 0) selectPlacement(state.selectedIndex, false);
    else clearSelection();
  }

  function measureCyanRingRadius(x, y) {
    const image = els.mapImage;
    if (!image.complete || !image.naturalWidth || !image.naturalHeight) return 0;
    const canvas = document.createElement('canvas');
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    if (!context) return 0;
    context.drawImage(image, 0, 0);

    const search = Math.round(Math.min(canvas.width, canvas.height) * 0.9);
    const left = Math.max(0, Math.floor(x - search));
    const top = Math.max(0, Math.floor(y - search));
    const right = Math.min(canvas.width - 1, Math.ceil(x + search));
    const bottom = Math.min(canvas.height - 1, Math.ceil(y + search));
    if (right <= left || bottom <= top) return 0;
    const width = right - left + 1;
    const pixels = context.getImageData(left, top, width, bottom - top + 1).data;

    let best = { r: 0, score: 0 };
    for (let r = 12; r <= search; r++) {
      let cyan = 0;
      let total = 0;
      for (let angle = 0; angle < Math.PI * 2; angle += Math.PI / 72) {
        const px = Math.round(x + Math.cos(angle) * r);
        const py = Math.round(y + Math.sin(angle) * r);
        if (px < left || px > right || py < top || py > bottom) continue;
        const offset = ((py - top) * width + px - left) * 4;
        const red = pixels[offset],
          green = pixels[offset + 1],
          blue = pixels[offset + 2];
        total++;
        if (green >= 125 && blue >= 135 && blue > red * 1.25 && green > red * 1.15) cyan++;
      }
      if (total < 24) continue;
      const score = cyan / total;
      if (score > best.score) best = { r, score };
    }
    return best.score >= 0.18 ? best.r : 0;
  }

  function calibrationTowerCatalogEntry(slot) {
    if (!state.doc) return null;
    const bySlot = state.doc.placements.find((p) => Number(p.slot) === Number(slot));
    if (bySlot) return bySlot;
    const name = state.doc.requiredTowers?.[Number(slot) - 1];
    if (!name) return null;
    return state.doc.placements.find((p) => String(p.towerName || '') === String(name)) || null;
  }

  function markScaleFromRing(mark) {
    const radiusPx = Number(mark?.ringRadiusPx) || 0;
    if (!(radiusPx > 0)) return 0;
    const sample = calibrationTowerCatalogEntry(mark.slot);
    const studs = sample ? rangeLevels(sample)[0] || Number(sample.rangeStuds) || 0 : 0;
    if (!(studs > 0)) return 0;
    const width = Number(state.calibration.clientWidth || state.doc?.strategyWidth || 1920);
    const height = Number(state.calibration.clientHeight || state.doc?.strategyHeight || 1009);
    const canonicalRadius = (radiusPx * (1920 / Math.max(1, width) + 1009 / Math.max(1, height))) / 2;
    const scale = canonicalRadius / studs;
    return Number.isFinite(scale) && scale >= SCALE_MIN && scale <= SCALE_MAX ? scale : 0;
  }

  function solveCalibrationGeometry() {
    const samples = state.calibration.marks
      .map((mark) => ({ mark, scale: markScaleFromRing(mark) }))
      .filter((entry) => entry.scale > 0);
    if (!samples.length) return null;

    const scales = samples.map((entry) => entry.scale);
    const mean = scales.reduce((sum, value) => sum + value, 0) / scales.length;
    const variance = scales.reduce((sum, value) => sum + (value - mean) ** 2, 0) / scales.length;
    const rmse = Math.sqrt(variance);
    const spread = scales.length > 1 ? (Math.max(...scales) - Math.min(...scales)) / mean : 0;
    const confidence = clamp((Math.min(samples.length, 5) / 5) * (1 - clamp(spread, 0, 1)), 0, 1);

    const solved = {
      model: 'global-v1',
      pixelsPerStud: mean,
      ppuX0: mean,
      ppuXX: 0,
      ppuXY: 0,
      ppuY0: mean,
      ppuYX: 0,
      ppuYY: 0,
      samples: samples.length,
      rmseX: rmse,
      rmseY: rmse,
      confidence,
      referenceWidth: 1920,
      referenceHeight: 1009,
      source: 'sandbox-calibration',
    };

    if (samples.length >= 3) {
      const affine = solveAffineScale(samples, mean);
      if (affine) Object.assign(solved, affine, { model: 'affine-v1' });
    }
    return solved;
  }

  function solveAffineScale(samples, mean) {
    const rows = samples.map((entry) => {
      const width = Number(state.calibration.clientWidth || state.doc?.strategyWidth || 1920);
      const height = Number(state.calibration.clientHeight || state.doc?.strategyHeight || 1009);
      return {
        nx: (Number(entry.mark.x) * 1920) / Math.max(1, width) / 1920 - 0.5,
        ny: (Number(entry.mark.y) * 1009) / Math.max(1, height) / 1009 - 0.5,
        scale: entry.scale,
      };
    });

    let s11 = 0,
      s12 = 0,
      s22 = 0,
      t1 = 0,
      t2 = 0;
    for (const row of rows) {
      const dx = row.nx;
      const dy = row.ny;
      const dv = row.scale - mean;
      s11 += dx * dx;
      s12 += dx * dy;
      s22 += dy * dy;
      t1 += dx * dv;
      t2 += dy * dv;
    }
    const det = s11 * s22 - s12 * s12;
    if (!Number.isFinite(det) || Math.abs(det) < 1e-6) return null;
    const gx = (t1 * s22 - t2 * s12) / det;
    const gy = (t2 * s11 - t1 * s12) / det;
    if (!Number.isFinite(gx) || !Number.isFinite(gy)) return null;

    let error = 0;
    for (const row of rows) {
      const predicted = mean + gx * row.nx + gy * row.ny;
      error += (predicted - row.scale) ** 2;
    }
    const rmse = Math.sqrt(error / rows.length);

    const corners = [
      [-0.5, -0.5],
      [0.5, -0.5],
      [-0.5, 0.5],
      [0.5, 0.5],
    ];
    for (const [nx, ny] of corners) {
      const value = mean + gx * nx + gy * ny;
      if (!Number.isFinite(value) || value < SCALE_MIN || value > SCALE_MAX) return null;
    }

    return {
      ppuX0: mean,
      ppuXX: gx,
      ppuXY: gy,
      ppuY0: mean,
      ppuYX: gx,
      ppuYY: gy,
      rmseX: rmse,
      rmseY: rmse,
    };
  }

  function applySolvedGeometry(solved) {
    if (!state.doc || !solved) return;
    state.doc.pixelsPerUnit = solved.pixelsPerStud;
    state.doc.pixelsPerStud = solved.pixelsPerStud;
    state.doc.geometrySource = solved.source;
    state.doc.geometryConfidence = solved.confidence;
    state.doc.geometryProjection = {
      model: solved.model,
      referenceWidth: solved.referenceWidth,
      referenceHeight: solved.referenceHeight,
      ppuX0: solved.ppuX0,
      ppuXX: solved.ppuXX,
      ppuXY: solved.ppuXY,
      ppuY0: solved.ppuY0,
      ppuYX: solved.ppuYX,
      ppuYY: solved.ppuYY,
      samples: solved.samples,
      rmseX: solved.rmseX,
      rmseY: solved.rmseY,
      confidence: solved.confidence,
      source: solved.source,
    };
    state.calibration.solved = solved;
    refreshGeometryVisuals();
  }

  async function persistSolvedGeometry(solved) {
    if (!solved || !window.ahk?.SaveGeometry) return false;
    const fields = {
      mapName: documentMapName() || selectedMapName() || '',
      model: solved.model,
      pixelsPerStud: solved.pixelsPerStud,
      ppuX0: solved.ppuX0,
      ppuXX: solved.ppuXX,
      ppuXY: solved.ppuXY,
      ppuY0: solved.ppuY0,
      ppuYX: solved.ppuYX,
      ppuYY: solved.ppuYY,
      samples: solved.samples,
      rmseX: solved.rmseX,
      rmseY: solved.rmseY,
      confidence: solved.confidence,
      referenceWidth: solved.referenceWidth,
      referenceHeight: solved.referenceHeight,
      offsetX: Number(state.doc?.geometryOffsetX || 0),
      offsetY: Number(state.doc?.geometryOffsetY || 0),
      source: solved.source,
    };
    const payload = Object.entries(fields)
      .map(([key, value]) => `${key}=${value}`)
      .join('\n');
    try {
      const raw = await ahk.SaveGeometry(payload);
      if (raw) applyGeometryPayload(JSON.parse(String(raw)));
      return Boolean(raw);
    } catch (err) {
      setStatus(`Calibration could not be saved: ${err.message || err}`);
      return false;
    }
  }

  function addCalibrationMark(clientX, clientY) {
    if (!state.doc || !state.calibration.marking) return;

    const pt = screenToWorld(clientX, clientY);
    const slot = Number(state.calibration.activeSlot || els.calibrationTowerSelect.value || 1);
    const tower = state.doc.requiredTowers[slot - 1] || `Slot ${slot}`;
    const x = Math.round(clamp(pt.x, 0, state.doc.strategyWidth));
    const y = Math.round(clamp(pt.y, 0, state.doc.strategyHeight));
    const ringRadiusPx = measureCyanRingRadius(x, y);

    const mark = { slot, tower, x, y, ringRadiusPx };
    mark.scale = markScaleFromRing(mark);
    const existing = state.calibration.marks.findIndex((m) => Number(m.slot) === slot);
    if (existing >= 0) state.calibration.marks[existing] = mark;
    else state.calibration.marks.push(mark);
    state.calibration.marks.sort((a, b) => Number(a.slot) - Number(b.slot));

    const solved = solveCalibrationGeometry();
    if (solved) applySolvedGeometry(solved);
    renderCalibrationMarks();

    const total = calibrationTowerCount();
    if (state.calibration.marks.length >= total) {
      state.calibration.marking = false;
      document.body.classList.remove('marking');
      els.calibrationMarkHud.hidden = true;
      renderCalibrationSidebar();
      if (solved) {
        persistSolvedGeometry(solved).then((saved) => {
          if (saved)
            toast(
              `Calibrated scale saved: ${solved.pixelsPerStud.toFixed(2)} px per stud from ${solved.samples} ring${solved.samples === 1 ? '' : 's'}.`,
              'success',
              5200,
            );
        });
        setStatus(
          `Calibration complete: ${total}/${total} centers • ${solved.pixelsPerStud.toFixed(2)} px/stud from ${solved.samples} measured range ring${solved.samples === 1 ? '' : 's'}.`,
        );
      } else {
        setStatus(
          `Calibration centers complete: ${total}/${total}. No range ring could be measured, so the scale was left unchanged.`,
        );
        toast(
          'No range ring was detected around the marked centers. Re-capture with the tower selected so its range circle is visible.',
          'warn',
          6000,
        );
      }
      window.setTimeout(() => openCalibration(), 300);
      return;
    }

    const nextSlot = firstUnmarkedCalibrationSlot(slot + 1 <= total ? slot + 1 : 1);
    state.calibration.activeSlot = nextSlot;
    els.calibrationTowerSelect.value = String(nextSlot);
    renderCalibrationMarkHud();
    renderCalibrationSidebar();
    const nextTower = state.doc.requiredTowers[nextSlot - 1] || `Slot ${nextSlot}`;
    const scaleNote = mark.scale ? ` • range ring ${ringRadiusPx}px = ${mark.scale.toFixed(2)} px/stud` : '';
    setStatus(`Recorded ${tower} at client-local (${x}, ${y})${scaleNote}. Next: ${nextTower}.`);
  }

  function renderCalibrationMarks() {
    els.calibrationLayer.replaceChildren();
    els.calibrationRows.replaceChildren();

    state.calibration.marks.forEach((mark, index) => {
      const marker = document.createElement('div');
      marker.className = 'calibration-mark';
      marker.style.left = `${mark.x}px`;
      marker.style.top = `${mark.y}px`;
      marker.textContent = String(index + 1);
      marker.title = `${mark.tower} • Slot ${mark.slot} • ${mark.x}, ${mark.y}`;
      els.calibrationLayer.appendChild(marker);

      const tr = document.createElement('tr');
      tr.appendChild(cell(String(index + 1), 'c-idx'));
      tr.appendChild(cell(mark.tower));
      tr.appendChild(cell(String(mark.slot), 'c-slot'));
      tr.appendChild(cell(String(mark.x), 'c-num'));
      tr.appendChild(cell(String(mark.y), 'c-num'));
      tr.appendChild(cell(mark.scale ? mark.scale.toFixed(2) : '—', 'c-num'));

      const action = document.createElement('td');
      action.className = 'c-act';
      const remove = document.createElement('button');
      remove.className = 'cal-remove';
      remove.type = 'button';
      remove.textContent = '×';
      remove.title = `Remove the ${mark.tower} mark`;
      remove.addEventListener('click', () => {
        state.calibration.marks = state.calibration.marks.filter((m) => m !== mark);
        state.calibration.activeSlot = Number(mark.slot) || 1;
        const resolved = solveCalibrationGeometry();
        state.calibration.solved = resolved;
        if (resolved) applySolvedGeometry(resolved);
        renderCalibrationMarks();
      });
      action.appendChild(remove);
      tr.appendChild(action);
      els.calibrationRows.appendChild(tr);
    });

    if (!state.calibration.marks.length) emptyRow(els.calibrationRows, 7, 'No tower centers marked yet.');
    updateCalibrationControls();
    if (state.calibration.marking) {
      renderCalibrationMarkHud();
      renderCalibrationSidebar();
    }
  }

  function undoLastCalibrationMark() {
    if (!state.calibration.marks.length) {
      toast('There are no calibration marks to undo.', 'info');
      return;
    }
    const removed = state.calibration.marks.pop();
    state.calibration.activeSlot = Number(removed.slot) || 1;
    els.calibrationTowerSelect.value = String(state.calibration.activeSlot);
    const solved = solveCalibrationGeometry();
    state.calibration.solved = solved;
    if (solved) applySolvedGeometry(solved);
    renderCalibrationMarks();
    setStatus(`Removed the ${removed.tower} mark. Mark Slot ${state.calibration.activeSlot} again.`);
  }

  function calibrationReplayText() {
    if (!state.doc) return '';
    const lines = replayHeaderLines(
      state.calibration.clientWidth || state.doc.strategyWidth || 1920,
      state.calibration.clientHeight || state.doc.strategyHeight || 1009,
    );
    const perTower = new Map();
    state.calibration.marks.forEach((mark) => {
      const key =
        String(mark.tower || `slot${mark.slot}`)
          .replace(/[^A-Za-z0-9]+/g, '')
          .toLowerCase() || `slot${mark.slot}`;
      const n = (perTower.get(key) || 0) + 1;
      perTower.set(key, n);
      lines.push(`SpawnTower(${mark.x}, ${mark.y}, ${mark.slot}, cal_${key}_${n})`);
    });
    return `${lines.join('\r\n')}\r\n`;
  }

  async function exportCalibrationStrat() {
    const done = busy(els.calibrationExportBtn, 'Exporting…');
    try {
      ensureHost();
      const path = await ahk.SaveCalibrationStrat(calibrationReplayText());
      if (path) {
        setStatus(`Calibration replay strategy exported: ${String(path)}`);
        toast('Calibration replay .strat exported.', 'success');
      } else {
        setStatus('Calibration replay export canceled.');
      }
    } catch (err) {
      setStatus(`Calibration export failed: ${err.message || err}`);
      toast(`Calibration export failed: ${err.message || err}`, 'error');
    } finally {
      done();
    }
  }

  async function replayCalibration() {
    const done = busy(els.calibrationReplayBtn, 'Launching…');
    try {
      ensureHost();
      const result = await ahk.ReplayCalibrationStrat(calibrationReplayText());
      if (result) {
        setStatus(
          'Calibration replay runner launched. It verifies the installed macro contract before placing anything.',
        );
        toast('Replay runner launched with the marked SpawnTower coordinates.', 'success', 4200);
      }
    } catch (err) {
      setStatus(`Calibration replay failed to start: ${err.message || err}`);
      toast(`Replay failed to start: ${err.message || err}`, 'error');
    } finally {
      done();
    }
  }

  async function openCalibrationFolder() {
    try {
      ensureHost();
      const path = await ahk.OpenCalibrationFolder();
      if (path) {
        state.calibration.sessionPath = String(path);
        updateCalibrationControls();
      }
    } catch (err) {
      toast(`Could not open the calibration folder: ${err.message || err}`, 'error');
    }
  }

  async function focusSandbox() {
    try {
      ensureHost();
      const ok = await ahk.FocusRoblox();
      if (!ok) {
        toast('Roblox was not found. Open Sandbox first.', 'warn', 4000);
        return;
      }
      setStatus('Sandbox focused. Place the five test towers, then return to Strategy Lab.');
    } catch (err) {
      toast(`Could not focus Roblox: ${err.message || err}`, 'error');
    }
  }

  function renderCommandReference(query = '') {
    const q = String(query || '')
      .trim()
      .toLowerCase();
    const matches = COMMAND_REFERENCE.filter((cmd) => {
      if (!q) return true;
      const haystack = [cmd.name, cmd.signature, cmd.summary, cmd.note || '']
        .concat((cmd.params || []).map((pair) => `${pair[0]} ${pair[1]}`))
        .join(' ')
        .toLowerCase();
      return haystack.includes(q);
    });

    if (!matches.length) {
      const empty = document.createElement('div');
      empty.className = 'cmd-empty';
      empty.textContent = 'No command matches that filter.';
      els.codeRefList.replaceChildren(empty);
      return;
    }

    els.codeRefList.replaceChildren(
      ...matches.map((cmd) => {
        const box = document.createElement('details');
        box.className = 'cmd';
        if (q) box.open = true;

        const head = document.createElement('summary');
        head.textContent = cmd.signature;
        box.append(head);

        const body = document.createElement('div');
        body.className = 'cmd-body';

        const summary = document.createElement('p');
        summary.textContent = cmd.summary;
        body.append(summary);

        if (cmd.params && cmd.params.length) {
          const list = document.createElement('dl');
          list.className = 'cmd-params';
          for (const [name, description] of cmd.params) {
            const term = document.createElement('dt');
            term.textContent = name;
            const detail = document.createElement('dd');
            detail.textContent = description;
            list.append(term, detail);
          }
          body.append(list);
        }

        if (cmd.note) {
          const note = document.createElement('p');
          note.className = 'cmd-note';
          note.textContent = cmd.note;
          body.append(note);
        }

        if (cmd.example) {
          const example = document.createElement('pre');
          example.className = 'cmd-eg';
          example.textContent = cmd.example;
          body.append(example);
        }

        box.append(body);
        return box;
      }),
    );
  }

  function showCodeIssue(message) {
    els.codeIssue.textContent = message || '';
    els.codeIssue.title = message || '';
    els.codeIssue.hidden = !message;
  }

  function updateCodeGutter() {
    const lines = els.codeArea.value.split('\n').length;
    if (Number(els.codeGutter.dataset.lines || 0) !== lines) {
      const numbers = new Array(lines);
      for (let i = 0; i < lines; i += 1) numbers[i] = String(i + 1);
      els.codeGutter.textContent = numbers.join('\n');
      els.codeGutter.dataset.lines = String(lines);
    }
    els.codeGutter.scrollTop = els.codeArea.scrollTop;
  }

  function codeEditorText() {
    return els.codeArea.value.replace(/\r?\n/g, state.doc?.newline || '\r\n');
  }

  function syncCodeEditor() {
    if (!state.doc) {
      els.codeArea.value = '';
      els.codeFileName.textContent = '—';
      els.codeFileName.title = '';
    } else {
      els.codeArea.value = renderText();
      els.codeFileName.textContent = state.doc.path || state.doc.name || '—';
      els.codeFileName.title = state.doc.path || '';
    }
    state.codeEdited = false;
    showCodeIssue('');
    updateCodeGutter();
  }

  function onCodeInput() {
    if (!state.doc) return;
    state.codeEdited = true;
    setDirty(true);
    showCodeIssue('');
    updateCodeGutter();
  }

  function applyParsedDocument(payload) {
    if (typeof payload === 'string') payload = JSON.parse(payload);
    if (!Array.isArray(payload.placements)) payload.placements = [];
    if (!Array.isArray(payload.requiredTowers)) payload.requiredTowers = [];
    payload.spatialActions = spatialActionsFromText(payload.text || '');

    const previous = state.doc;
    const sameSize =
      previous &&
      previous.strategyWidth === payload.strategyWidth &&
      previous.strategyHeight === payload.strategyHeight;
    const previousMap = String(previous?.mapName || '');

    stopReplayPolling();
    state.doc = payload;
    state.selectedIndex = -1;
    state.selectedActionIndex = -1;
    state.undo = [];
    state.redo = [];
    state.collisionSet = new Set();
    state.collisionPairs = new Set();
    state.replay.state = '';
    state.replay.failedIds = new Set();
    state.replay.steps = new Map();
    state.replay.announced = new Map();
    payload.placements.forEach((p) => {
      p.replayFailed = false;
    });

    els.world.style.width = `${payload.strategyWidth}px`;
    els.world.style.height = `${payload.strategyHeight}px`;
    els.resolutionInfo.textContent = `${payload.strategyWidth} × ${payload.strategyHeight}${payload.hasExplicitDimensions === false ? ' • legacy fallback' : ''}`;
    els.mapInfo.textContent = payload.mapName || '—';
    els.encodingInfo.textContent = payload.encoding || '—';
    els.fileInfo.textContent = payload.path ? pathTail(payload.path) : '—';
    els.fileInfo.title = payload.path || '';
    renderGeometryInfo(payload);

    buildLayerOptions();
    buildRanges();
    buildFootprints();
    buildMarkers();
    buildActionLayer();
    buildRows();
    buildActionRows();
    recomputeCollisions();
    renderCalibrationMarks();
    updateCalibrationControls();
    clearSelection();
    renderDocBar();
    refreshPortraitStatus().then(updateHealth);
    populateCalibrationTowerOptions();

    if (String(payload.mapName || '') !== previousMap) {
      state.selectedMap = String(payload.mapCanonical || payload.mapName || '');
      state.mapAutoCaptureTried = new Set();
      clearMapVisual();
      refreshMapCatalog(documentMapName()).then(() => ensureMapBackground(selectedMapName()));
    }
    if (sameSize) applyWorldTransform();
    else requestAnimationFrame(() => fitWorld(true));
  }

  async function applyCodeEdits({ silent = false } = {}) {
    if (!state.doc || !state.codeEdited) return true;

    const done = busy(els.codeApplyBtn, 'Checking…');
    try {
      ensureHost();
      const raw = await ahk.ParseStrategyText(codeEditorText());
      const result = typeof raw === 'string' ? JSON.parse(raw) : raw;
      if (!result || !result.ok) throw new Error(result?.error || 'The strategy text could not be read.');

      applyParsedDocument(result.doc);
      state.codeEdited = false;
      showCodeIssue('');
      if (!silent) {
        setStatus(
          `Code applied: ${state.doc.placements.length} placement${state.doc.placements.length === 1 ? '' : 's'}.`,
        );
        toast('Code applied. The visual editor now matches the text.', 'success');
      }
      return true;
    } catch (err) {
      const message = err.message || String(err);
      showCodeIssue(message);
      setStatus(`Code not applied: ${message}`);
      if (!silent) toast(`Code not applied: ${message}`, 'error', 5600);
      return false;
    } finally {
      done();
    }
  }

  function revertCodeEdits() {
    if (!state.doc) return;
    syncCodeEditor();
    setStatus('Raw text reloaded from the strategy that is currently open.');
  }

  function paintEditorMode() {
    const code = state.codeMode;
    els.codeView.hidden = !code;
    els.viewport.hidden = code;
    els.modeCodeBtn.classList.toggle('is-on', code);
    els.modeVisualBtn.classList.toggle('is-on', !code);
    els.modeCodeBtn.setAttribute('aria-pressed', String(code));
    els.modeVisualBtn.setAttribute('aria-pressed', String(!code));
    document.body.classList.toggle('code-mode', code);
    els.stageHint.textContent = code
      ? 'Ctrl+E switches back · Apply parses the text · Save writes it to a .strat'
      : 'Wheel zoom  ·  Drag tower/action to move  ·  Right-click to place selected destination';
  }

  function resetEditorMode() {
    state.codeMode = false;
    state.codeEdited = false;
    showCodeIssue('');
    paintEditorMode();
  }

  async function setEditorMode(mode) {
    const wantCode = mode === 'code';
    if (wantCode && !state.doc) return;
    if (state.codeMode === wantCode) return;

    if (!wantCode && !(await applyCodeEdits())) return;

    state.codeMode = wantCode;
    paintEditorMode();

    if (wantCode) {
      clearSelection();
      if (state.calibration.open || state.calibration.marking) closeCalibration();
      syncCodeEditor();
      els.codeArea.focus();
      setStatus('Raw editor. Edit the .strat text, then Apply or switch back to Visual.');
    } else {
      requestAnimationFrame(() => fitWorld(state.scale <= state.fitScale * 1.02));
      setStatus('Visual editor.');
    }
    syncControls();
  }

  function showRailPanel(which) {
    const placements = which === 'placements';
    const actions = which === 'actions';
    const strategy = !placements && !actions;
    els.panelPlacements.hidden = !placements;
    els.panelActions.hidden = !actions;
    els.panelStrategy.hidden = !strategy;
    els.tabPlacements.classList.toggle('is-active', placements);
    els.tabActions.classList.toggle('is-active', actions);
    els.tabStrategy.classList.toggle('is-active', strategy);
    els.tabPlacements.setAttribute('aria-selected', String(placements));
    els.tabActions.setAttribute('aria-selected', String(actions));
    els.tabStrategy.setAttribute('aria-selected', String(strategy));
  }

  function syncControls() {
    const loaded = Boolean(state.doc);
    const selected = loaded && (state.selectedIndex >= 0 || state.selectedActionIndex >= 0);
    const mapName = selectedMapName();

    const visual = loaded && !state.codeMode;

    els.saveCopyBtn.disabled = !loaded;
    els.overwriteBtn.disabled = !loaded;
    els.undoBtn.disabled = !visual || !state.undo.length;
    els.redoBtn.disabled = !visual || !state.redo.length;
    els.replayStrategyBtn.disabled = !loaded || !state.doc.placements.length;
    els.fitBtn.disabled = !visual;
    els.rangeBtn.disabled = !visual;
    els.footprintBtn.disabled = !visual;
    els.layerSelect.disabled = !visual;
    els.modeVisualBtn.disabled = !loaded;
    els.modeCodeBtn.disabled = !loaded;
    els.codeApplyBtn.disabled = !loaded;
    els.codeRevertBtn.disabled = !loaded;
    els.importMapBtn.disabled = !mapName;
    els.captureMapBtn.disabled = !mapName;
    els.calibrationBtn.disabled = !loaded;
    els.calibrationBtn.title = loaded
      ? 'Open the Sandbox coordinate and scale calibration lab'
      : 'Open a strategy first. Calibration measures the range circles of that strategy’s towers.';
    els.syncPortraitsBtn.disabled = !loaded;

    els.xInput.disabled = !selected;
    els.yInput.disabled = !selected;
    els.applyXYBtn.disabled = !selected;
    els.refreshSelectedBtn.disabled = state.selectedIndex < 0 || !state.doc.placements[state.selectedIndex]?.towerName;
  }

  els.openBtn.addEventListener('click', openStrategy);
  els.emptyOpenBtn.addEventListener('click', openStrategy);
  els.saveCopyBtn.addEventListener('click', saveCopy);
  els.overwriteBtn.addEventListener('click', overwrite);
  els.undoBtn.addEventListener('click', undo);
  els.redoBtn.addEventListener('click', redo);
  els.replayStrategyBtn.addEventListener('click', replayStrategyInSandbox);
  els.modeVisualBtn.addEventListener('click', () => setEditorMode('visual'));
  els.modeCodeBtn.addEventListener('click', () => setEditorMode('code'));
  els.codeApplyBtn.addEventListener('click', () => applyCodeEdits());
  els.codeRevertBtn.addEventListener('click', revertCodeEdits);
  els.codeRefBtn.addEventListener('click', () => {
    const off = els.codeView.classList.toggle('ref-off');
    els.codeRefBtn.classList.toggle('is-on', !off);
  });
  els.codeArea.addEventListener('input', onCodeInput);
  els.codeArea.addEventListener('scroll', () => {
    els.codeGutter.scrollTop = els.codeArea.scrollTop;
  });
  els.codeRefSearch.addEventListener('input', () => renderCommandReference(els.codeRefSearch.value));
  els.calibrationBtn.addEventListener('click', () => openCalibration());

  els.mapPickerBtn.addEventListener('click', (ev) => {
    ev.stopPropagation();
    toggleMapMenu();
  });
  els.mapSearch.addEventListener('input', () => renderMapMenu(els.mapSearch.value));
  els.mapSearch.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') {
      ev.preventDefault();
      toggleMapMenu(false);
      els.mapPickerBtn.focus();
    }
  });
  document.addEventListener('pointerdown', (ev) => {
    if (!els.mapPicker.contains(ev.target)) toggleMapMenu(false);
  });
  els.importMapBtn.addEventListener('click', importSelectedMap);
  els.captureMapBtn.addEventListener('click', captureRoblox);
  els.macroRootBtn.addEventListener('click', chooseMacroRoot);

  els.layerSelect.addEventListener('change', () => {
    state.activeSlot = Number(els.layerSelect.value) || 0;
    applyLayerFilter();
    setStatus(
      `Layer: ${els.layerSelect.selectedOptions[0]?.textContent || 'All placements'} • ${els.placementCount.textContent} shown.`,
    );
  });
  els.fitBtn.addEventListener('click', () => fitWorld(true));
  els.footprintBtn.addEventListener('click', () => {
    state.footprintsVisible = !state.footprintsVisible;
    els.footprintLayer.classList.toggle('off', !state.footprintsVisible);
    els.footprintBtn.classList.toggle('is-on', state.footprintsVisible);
    setStatus(
      state.footprintsVisible
        ? 'Placement footprints visible. Red marks a real hitbox overlap.'
        : 'Placement footprints hidden.',
    );
  });
  els.rangeBtn.addEventListener('click', () => {
    state.rangesVisible = !state.rangesVisible;
    els.rangeBtn.classList.toggle('is-on', state.rangesVisible);
    updateRangeVisibility();
    setStatus(
      state.rangesVisible
        ? 'Every attack range shown. Ranges never trigger overlap warnings.'
        : 'Only the selected tower shows its attack range.',
    );
  });

  els.applyXYBtn.addEventListener('click', applyCoordinateInputs);
  for (const input of [els.xInput, els.yInput]) {
    input.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter') {
        ev.preventDefault();
        applyCoordinateInputs();
      }
    });
  }

  els.footprintInput.addEventListener('input', () => {
    if (state.selectedIndex >= 0) setFootprint(state.selectedIndex, els.footprintInput.value);
  });
  els.syncFootprintBtn.addEventListener('click', syncFootprintAcrossTower);
  els.resetFootprintBtn.addEventListener('click', () => {
    if (state.selectedIndex >= 0) setFootprint(state.selectedIndex, 0, true);
  });
  els.refreshSelectedBtn.addEventListener('click', refreshSelectedPortrait);
  els.syncPortraitsBtn.addEventListener('click', syncLoadoutPortraits);

  els.tabPlacements.addEventListener('click', () => showRailPanel('placements'));
  els.tabActions.addEventListener('click', () => showRailPanel('actions'));
  els.tabStrategy.addEventListener('click', () => showRailPanel('strategy'));

  els.confirmOkBtn.addEventListener('click', () => settleConfirm(true));
  els.confirmCancelBtn.addEventListener('click', () => settleConfirm(false));
  els.confirmModal.addEventListener('pointerdown', (ev) => {
    if (ev.target === els.confirmModal) settleConfirm(false);
  });

  els.calibrationCloseBtn.addEventListener('click', closeCalibration);
  els.calibrationModal.addEventListener('pointerdown', (ev) => {
    if (ev.target === els.calibrationModal) closeCalibration();
  });
  els.calibrationBaselineBtn.addEventListener('click', () => captureCalibration('baseline'));
  els.calibrationManualBtn.addEventListener('click', () => captureCalibration('manual'));
  els.calibrationGoSandboxBtn.addEventListener('click', focusSandbox);
  els.calibrationMarkBtn.addEventListener('click', toggleCalibrationMarking);
  els.calibrationTowerSelect.addEventListener('change', () => {
    state.calibration.activeSlot = Number(els.calibrationTowerSelect.value) || 1;
    renderCalibrationMarkHud();
  });
  els.calibrationExportBtn.addEventListener('click', exportCalibrationStrat);
  els.calibrationReplayBtn.addEventListener('click', replayCalibration);
  els.calibrationFolderBtn.addEventListener('click', openCalibrationFolder);
  els.calibrationReturnBtn.addEventListener('click', pauseGuidedMarkingAndReturn);
  els.calibrationUndoMarkBtn.addEventListener('click', undoLastCalibrationMark);

  let resizeTimer = 0;
  window.addEventListener('resize', () => {
    if (!state.doc) return;
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(() => fitWorld(state.scale <= state.fitScale * 1.02), 90);
  });

  window.addEventListener('keydown', (ev) => {
    if (pendingConfirm) {
      if (ev.key === 'Escape') {
        ev.preventDefault();
        settleConfirm(false);
      } else if (ev.key === 'Enter') {
        ev.preventDefault();
        settleConfirm(true);
      }
      return;
    }
    if (ev.key === 'Escape') {
      if (state.calibration.marking) {
        ev.preventDefault();
        pauseGuidedMarkingAndReturn();
        return;
      }
      if (state.calibration.open) {
        ev.preventDefault();
        closeCalibration();
        return;
      }
      if (!els.mapMenu.hidden) {
        ev.preventDefault();
        toggleMapMenu(false);
        els.mapPickerBtn.focus();
        return;
      }
    }
    const inField =
      ev.target instanceof HTMLInputElement ||
      ev.target instanceof HTMLSelectElement ||
      ev.target instanceof HTMLTextAreaElement;
    const key = ev.key.toLowerCase();
    if (ev.ctrlKey && key === 'e') {
      ev.preventDefault();
      setEditorMode(state.codeMode ? 'visual' : 'code');
    } else if (ev.ctrlKey && key === 'o') {
      ev.preventDefault();
      openStrategy();
    } else if (ev.ctrlKey && key === 's') {
      ev.preventDefault();
      saveCopy();
    } else if (ev.ctrlKey && key === 'z' && !inField) {
      ev.preventDefault();
      undo();
    } else if (ev.ctrlKey && key === 'y' && !inField) {
      ev.preventDefault();
      redo();
    } else if (key === '0' && state.doc && !ev.ctrlKey && !inField) {
      ev.preventDefault();
      fitWorld(true);
    }
  });

  window.strategyLab = { loadStrategy, setMapPayload, notify };

  async function loadBrandIcon() {
    try {
      const data = await ahk.GetBrandIcon();
      if (!data) return;
      els.brandIcon.src = String(data);
      els.brandIcon.hidden = false;
      els.brandFallback.hidden = true;
    } catch { }
  }

  async function ready() {
    showRailPanel('placements');
    renderCommandReference();
    paintEditorMode();
    syncControls();
    setDirty(false);
    renderDocBar();
    try {
      await loadBrandIcon();
      await refreshMapCatalog('');
      if (window.ahk?.AppReady) await ahk.AppReady();
      setStatus(state.macroRoot ? `Ready. Macro detected: ${state.macroRoot}` : 'Ready. Open a .strat to begin.');
    } catch (err) {
      setStatus(`Host initialization warning: ${err.message || err}`);
    }
  }
  ready();
})();