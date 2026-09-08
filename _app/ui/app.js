(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);

  const els = {
    titlebar: $('titlebar'), brandIcon: $('brandIcon'), brandFallback: $('brandFallback'),
    docName: $('docName'), docDirty: $('docDirty'), docMap: $('docMap'),
    winMinBtn: $('winMinBtn'), winMaxBtn: $('winMaxBtn'), winCloseBtn: $('winCloseBtn'),

    openBtn: $('openBtn'), emptyOpenBtn: $('emptyOpenBtn'),
    saveCopyBtn: $('saveCopyBtn'), overwriteBtn: $('overwriteBtn'),
    undoBtn: $('undoBtn'), redoBtn: $('redoBtn'),
    replayStrategyBtn: $('replayStrategyBtn'), calibrationBtn: $('calibrationBtn'),

    mapPicker: $('mapPicker'), mapPickerBtn: $('mapPickerBtn'), mapPickerText: $('mapPickerText'),
    mapMenu: $('mapMenu'), mapSearch: $('mapSearch'), mapMenuList: $('mapMenuList'),
    importMapBtn: $('importMapBtn'), captureMapBtn: $('captureMapBtn'),

    layerSelect: $('layerSelect'), fitBtn: $('fitBtn'), footprintBtn: $('footprintBtn'),
    zoomLabel: $('zoomLabel'), macroRootBtn: $('macroRootBtn'), macroStatus: $('macroStatus'),

    viewport: $('viewport'), emptyState: $('emptyState'), world: $('world'), mapImage: $('mapImage'),
    footprintLayer: $('footprintLayer'), markerLayer: $('markerLayer'), calibrationLayer: $('calibrationLayer'),
    viewportLoader: $('viewportLoader'), viewportLoaderText: $('viewportLoaderText'),

    xInput: $('xInput'), yInput: $('yInput'), applyXYBtn: $('applyXYBtn'),

    portrait: $('portrait'), portraitSkeleton: $('portraitSkeleton'), portraitFallback: $('portraitFallback'),
    selectedName: $('selectedName'),
    metaSlot: $('metaSlot'), metaId: $('metaId'), metaPos: $('metaPos'),
    metaPlane: $('metaPlane'), metaRing: $('metaRing'), metaStatus: $('metaStatus'),

    footprintValue: $('footprintValue'), footprintInput: $('footprintInput'),
    syncFootprintBtn: $('syncFootprintBtn'), resetFootprintBtn: $('resetFootprintBtn'),
    portraitStatusBadge: $('portraitStatusBadge'), refreshSelectedBtn: $('refreshSelectedBtn'),
    syncPortraitsBtn: $('syncPortraitsBtn'),

    tabPlacements: $('tabPlacements'), tabStrategy: $('tabStrategy'),
    placementHeading: $('placementHeading'), placementCount: $('placementCount'),
    panelPlacements: $('panelPlacements'), panelStrategy: $('panelStrategy'),

    replayBar: $('replayBar'), replayPlacedCount: $('replayPlacedCount'),
    replayUpgradingCount: $('replayUpgradingCount'), replayUpgradedCount: $('replayUpgradedCount'),
    replayFailedCount: $('replayFailedCount'), placementRows: $('placementRows'),

    resolutionInfo: $('resolutionInfo'), mapInfo: $('mapInfo'), mapImageInfo: $('mapImageInfo'),
    geometryInfo: $('geometryInfo'), geometryConfidenceInfo: $('geometryConfidenceInfo'),
    healthInfo: $('healthInfo'), encodingInfo: $('encodingInfo'), fileInfo: $('fileInfo'),

    statusText: $('statusText'), summaryText: $('summaryText'), toastStack: $('toastStack'),

    calibrationMarkHud: $('calibrationMarkHud'), calibrationMarkProgress: $('calibrationMarkProgress'),
    calibrationMarkTower: $('calibrationMarkTower'), calibrationMarkInstruction: $('calibrationMarkInstruction'),
    calibrationUndoMarkBtn: $('calibrationUndoMarkBtn'), calibrationReturnBtn: $('calibrationReturnBtn'),

    confirmModal: $('confirmModal'), confirmTitle: $('confirmTitle'), confirmBody: $('confirmBody'),
    confirmOkBtn: $('confirmOkBtn'), confirmCancelBtn: $('confirmCancelBtn'),

    calibrationModal: $('calibrationModal'), calibrationCloseBtn: $('calibrationCloseBtn'),
    calibrationBaselineBtn: $('calibrationBaselineBtn'), calibrationGoSandboxBtn: $('calibrationGoSandboxBtn'),
    calibrationManualBtn: $('calibrationManualBtn'), calibrationTowerSelect: $('calibrationTowerSelect'),
    calibrationMarkBtn: $('calibrationMarkBtn'), calibrationExportBtn: $('calibrationExportBtn'),
    calibrationReplayBtn: $('calibrationReplayBtn'), calibrationFolderBtn: $('calibrationFolderBtn'),
    calibrationSessionInfo: $('calibrationSessionInfo'), calibrationBaselineInfo: $('calibrationBaselineInfo'),
    calibrationManualInfo: $('calibrationManualInfo'), calibrationMarkCount: $('calibrationMarkCount'),
    calibrationMacroInfo: $('calibrationMacroInfo'), calibrationRows: $('calibrationRows')
  };

  const state = {
    doc: null,
    activeSlot: 0,
    selectedIndex: -1,
    scale: 1,
    fitScale: 1,
    offsetX: 0,
    offsetY: 0,
    panning: null,
    dragging: null,
    undo: [],
    redo: [],
    dirty: false,
    map: null,
    mapCatalog: [],
    selectedMap: '',
    macroRoot: '',
    portraitCache: new Map(),
    mapPayloadCache: new Map(),
    portraitStatus: { total: 0, available: 0, missing: [] },
    markerEls: [],
    footprintEls: [],
    rowEls: [],
    collisionSet: new Set(),
    collisionPairs: new Set(),
    footprintsVisible: true,
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
      cameraContract: ''
    },
    replay: { state: '', epoch: 0, failedIds: new Set(), steps: new Map(), announced: new Map(), pollTimer: 0 }
  };

  const SLOT_COLORS = ['#5a616b', '#3a86ff', '#e09334', '#3dd68c', '#9b8cff', '#e5484d', '#2fb6c4', '#c8752f', '#6e7bd9', '#c05c94'];

  const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
  const slotColor = (slot) => SLOT_COLORS[Math.abs(Number(slot) || 0) % SLOT_COLORS.length];

  function setStatus(text) { els.statusText.textContent = text; }

  const SEPARATORS = /[\\/]+/;

  function pathTail(path, segments = 2) {
    const text = String(path || '');
    const parts = text.split(SEPARATORS).filter(Boolean);
    if (parts.length <= segments) return text;
    return '…\\' + parts.slice(-segments).join('\\');
  }

  function folderName(path) {
    const parts = String(path || '').split(SEPARATORS).filter(Boolean);
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
    return new Promise((resolve) => { pendingConfirm = resolve; });
  }

  function settleConfirm(answer) {
    if (!pendingConfirm) return;
    const resolve = pendingConfirm;
    pendingConfirm = null;
    els.confirmModal.hidden = true;
    resolve(answer);
  }

  function busy(button, text) {
    if (!button) return () => {};
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


  els.winMinBtn.addEventListener('click', () => { try { ahk.MinimizeWindow(); } catch {} });
  els.winMaxBtn.addEventListener('click', toggleMaximize);
  els.winCloseBtn.addEventListener('click', requestClose);

  async function requestClose() {
    if (state.dirty) {
      const confirmed = await askConfirm({
        title: 'Close Strategy Lab?',
        body: 'This strategy has unsaved placement changes. They are lost unless you save a copy first.',
        confirmLabel: 'Close anyway',
        danger: true
      });
      if (!confirmed) return;
    }
    try { ahk.CloseWindow(); } catch {}
  }

  function toggleMaximize() { try { ahk.ToggleMaximize(); } catch {} }

  els.titlebar.addEventListener('pointerdown', (ev) => {
    if (ev.button !== 0 || ev.target.closest('.win-btn')) return;
    try { ahk.BeginWindowDrag(); } catch {}
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


  function selectedMapName() {
    return String(state.selectedMap || state.doc?.mapName || '').trim();
  }

  function selectedMapEntry() {
    const name = selectedMapName();
    if (!name) return null;
    return state.mapCatalog.find((m) => String(m.name) === name) || { name, cached: false, supported: false, difficulty: '' };
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

    if (state.doc?.mapName && !byName.has(state.doc.mapName)) {
      const synthetic = { name: state.doc.mapName, category: 'Strategy', difficulty: '', supported: false, cached: false };
      state.mapCatalog.unshift(synthetic);
      byName.set(synthetic.name, synthetic);
    }

    if (preferred && byName.has(preferred)) state.selectedMap = preferred;
    else if (state.doc?.mapName && byName.has(state.doc.mapName)) state.selectedMap = state.doc.mapName;
    else if (state.selectedMap && !byName.has(state.selectedMap)) state.selectedMap = '';

    renderMapMenu(els.mapSearch.value);
    renderMapPickerLabel();
    syncControls();
  }

  function renderMapMenu(query = '') {
    const q = String(query || '').trim().toLowerCase();
    const matches = state.mapCatalog.filter((m) => !q || `${m.name} ${m.category || ''} ${m.difficulty || ''}`.toLowerCase().includes(q));
    const groups = [
      ['Verified by installed macro', matches.filter((m) => m.supported)],
      ['Cached map library', matches.filter((m) => !m.supported && m.cached)],
      ['Known TDS maps', matches.filter((m) => !m.supported && !m.cached)]
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
        if (m.supported) tags.appendChild(mapTag('verified', 'verified', m.supportEvidence ? `Installed macro evidence: ${m.supportEvidence}` : 'Verified by the installed macro'));
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
  }

  function clearMapVisual() {
    state.map = null;
    els.mapImage.removeAttribute('src');
    els.mapImage.hidden = true;
    els.world.classList.add('no-map');
    els.mapImageInfo.textContent = 'Not cached';
  }

  async function loadSelectedMap({ silent = false } = {}) {
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

      if (!silent) setStatus(`Loading ${mapName} from the local map library…`);
      setViewportLoading(true, `Loading ${mapName}…`);
      const data = await ahk.LoadCachedMap(mapName);
      if (data) {
        const text = String(data);
        state.mapPayloadCache.set(mapName, text);
        setMapPayload(text);
        return true;
      }
      clearMapVisual();
      if (!silent) setStatus(`No cached screenshot for ${mapName}. Use Capture or Import.`);
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

  async function importSelectedMap() {
    const mapName = selectedMapName();
    if (!mapName) { setStatus('Choose a map first.'); return; }
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
    if (!mapName) { setStatus('Choose a map first so the capture has a stable library name.'); return; }
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
    try { payload = typeof jsonText === 'string' ? JSON.parse(jsonText) : jsonText; } catch { return; }
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

    stopReplayPolling();
    state.doc = payload;
    state.activeSlot = 0;
    state.selectedIndex = -1;
    state.undo = [];
    state.redo = [];
    state.dirty = false;
    state.map = null;
    state.selectedMap = String(payload.mapName || '');
    state.collisionSet = new Set();
    state.collisionPairs = new Set();
    state.portraitCache.clear();
    state.replay.state = '';
    state.replay.failedIds = new Set();
    state.replay.steps = new Map();
    state.replay.announced = new Map();
    payload.placements.forEach((p) => { p.replayFailed = false; });

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
    buildFootprints();
    buildMarkers();
    buildRows();
    recomputeCollisions();
    renderCalibrationMarks();
    updateCalibrationControls();
    clearSelection();
    setDirty(false);
    renderDocBar();
    requestAnimationFrame(() => fitWorld(true));

    const loadout = new Set(payload.requiredTowers.filter(Boolean).map((x) => String(x).toLowerCase())).size;
    setStatus(`Loaded ${payload.placements.length} placement${payload.placements.length === 1 ? '' : 's'}.`);
    if (loadout > 5) toast(`This strategy declares ${loadout} required towers; normal TDS loadouts hold 5.`, 'warn', 5200);
    if (payload.hasExplicitDimensions === false) {
      toast('Strategy width/height metadata is missing. The macro falls back to 1920×1080, so alignment is approximate until it is re-recorded.', 'warn', 6500);
    }

    refreshPortraitStatus().then(updateHealth);
    populateCalibrationTowerOptions();
    refreshMapCatalog(payload.mapName || '').then(() => loadSelectedMap({ silent: true }));

    if (String(payload.strategyLabMode || '').toLowerCase() === 'sandbox-calibration') {
      window.setTimeout(() => openCalibration({ autoPrepare: true }), 220);
    }
  }

  function renderGeometryInfo(payload) {
    const offsetX = Number(payload.geometryOffsetX || 0);
    const offsetY = Number(payload.geometryOffsetY || 0);
    const projection = payload.geometryProjection || null;
    const affine = String(projection?.model || '').toLowerCase() === 'affine-v1';
    const fallback = Number(payload.pixelsPerUnit || 26);

    if (affine) {
      const px = Number(projection.ppuX0 || fallback).toFixed(2);
      const py = Number(projection.ppuY0 || fallback).toFixed(2);
      els.geometryInfo.textContent = `${px}×${py} px/u • projected`;
      els.geometryInfo.title = `Position-aware affine ring projection • ${Number(projection.samples || 0)} samples • RMSE X/Y ${Number(projection.rmseX || 0).toFixed(2)}/${Number(projection.rmseY || 0).toFixed(2)} px/u • visual offset ${offsetX.toFixed(2)}, ${offsetY.toFixed(2)}`;
    } else {
      els.geometryInfo.textContent = `${fallback.toFixed(2)} px/u`;
      els.geometryInfo.title = `Global ring scale fallback • visual offset ${offsetX.toFixed(2)}, ${offsetY.toFixed(2)} strategy px`;
    }

    const confidence = Number(payload.geometryConfidence || 0);
    const source = payload.geometrySource || 'visual-baseline';
    els.geometryConfidenceInfo.textContent = confidence > 0 ? `${source} • ${Math.round(confidence * 100)}%` : `${source} • experimental`;
  }

  function renderDocBar() {
    const doc = state.doc;
    els.docName.textContent = doc?.name || 'No strategy loaded';
    els.docName.title = doc?.path || '';
    const map = selectedMapName();
    els.docMap.textContent = doc ? (map || 'no map') : '';
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
    els.layerSelect.replaceChildren(...options.map((o) => {
      const el = document.createElement('option');
      el.value = String(o.value);
      el.textContent = o.label;
      return el;
    }));
    els.layerSelect.value = '0';
  }


  function displayPoint(p) {
    return {
      x: Number(p.x) + Number(state.doc?.geometryOffsetX || 0),
      y: Number(p.y) + Number(state.doc?.geometryOffsetY || 0)
    };
  }

  function canonicalPoint(p) {
    return {
      x: Number(p.x) * 1920 / Math.max(1, Number(state.doc.strategyWidth)),
      y: Number(p.y) * 1009 / Math.max(1, Number(state.doc.strategyHeight))
    };
  }

  function projectionAt(p) {
    const fallback = Number(state.doc?.pixelsPerUnit || 26);
    const model = state.doc?.geometryProjection || null;
    if (!model || String(model.model || '').toLowerCase() !== 'affine-v1') {
      return { ppuX: fallback, ppuY: fallback, model: 'global-v1' };
    }

    const point = canonicalPoint(p);
    const nx = point.x / 1920 - 0.5;
    const ny = point.y / 1009 - 0.5;
    const ppuX = Number(model.ppuX0) + Number(model.ppuXX || 0) * nx + Number(model.ppuXY || 0) * ny;
    const ppuY = Number(model.ppuY0) + Number(model.ppuYX || 0) * nx + Number(model.ppuYY || 0) * ny;
    if (!Number.isFinite(ppuX) || !Number.isFinite(ppuY) || ppuX < 8 || ppuX > 60 || ppuY < 8 || ppuY > 60) {
      return { ppuX: fallback, ppuY: fallback, model: 'global-v1' };
    }
    return { ppuX, ppuY, model: 'affine-v1' };
  }

  function catalogFootprint(p) { return clamp(Number(p?.footprint) || 1.5, 0.5, 4); }
  function effectiveFootprint(p) { return clamp(Number(p?.footprintOverride ?? catalogFootprint(p)), 0.5, 4); }

  function footprintSize(p) {
    const projection = projectionAt(p);
    const footprint = effectiveFootprint(p);
    return {
      w: footprint * projection.ppuX * 2 * Number(state.doc.strategyWidth) / 1920,
      h: footprint * projection.ppuY * 2 * Number(state.doc.strategyHeight) / 1009
    };
  }

  function placementPlanesOverlap(a, b) {
    const ta = String(a?.placementType || 'unknown').toLowerCase();
    const tb = String(b?.placementType || 'unknown').toLowerCase();
    return !((ta === 'ground' && tb === 'cliff') || (ta === 'cliff' && tb === 'ground'));
  }

  function pairCollides(a, b) {
    if (a.replayFailed || b.replayFailed) return false;
    if (!placementPlanesOverlap(a, b)) return false;
    const pa = canonicalPoint(a), pb = canonicalPoint(b);
    const ga = projectionAt(a), gb = projectionAt(b);
    const ppuX = Math.max(8, (ga.ppuX + gb.ppuX) / 2);
    const ppuY = Math.max(8, (ga.ppuY + gb.ppuY) / 2);
    const dxUnits = (pa.x - pb.x) / ppuX;
    const dyUnits = (pa.y - pb.y) / ppuY;
    const radiusA = effectiveFootprint(a);
    const radiusB = effectiveFootprint(b);
    const distanceUnits = Math.sqrt(dxUnits * dxUnits + dyUnits * dyUnits);
    return distanceUnits > Math.abs(radiusA - radiusB) && distanceUnits < radiusA + radiusB;
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
    el.title = `${p.towerName || `Slot ${p.slot}`} • ring ${effectiveFootprint(p).toFixed(2)} • ${Object.hasOwn(p, 'footprintOverride') ? 'custom' : (p.footprintStatus || 'estimated')} • drag to move`;
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
      el.textContent = String(p.towerId || index + 1).replace(/[^0-9]+/g, '').slice(-2) || String(index + 1);
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
    els.placementCount.textContent = String(visible);
    if (state.selectedIndex >= 0) {
      const p = state.doc.placements[state.selectedIndex];
      if (state.activeSlot !== 0 && Number(p.slot) !== state.activeSlot) clearSelection();
    }
    updateSummary();
  }

  function updateSummary() {
    if (!state.doc) { els.summaryText.textContent = ''; return; }
    const total = state.doc.placements.length;
    const overlaps = state.collisionPairs.size;
    els.summaryText.textContent = `${total} placement${total === 1 ? '' : 's'} · ${overlaps} overlap${overlaps === 1 ? '' : 's'}`;
    els.summaryText.title = overlaps ? 'Projected placement rings that intersect on the same plane.' : '';
  }

  function updateHealth() {
    if (!state.doc) { els.healthInfo.textContent = '—'; return; }
    const placements = state.doc.placements;
    const verified = placements.filter((p) => Boolean(p.footprintKnown)).length;
    const portraits = `${state.portraitStatus.available}/${state.portraitStatus.total}`;
    const pairs = state.collisionPairs.size;
    els.healthInfo.textContent = `${portraits} art • ${verified}/${placements.length} verified • ${pairs} overlap${pairs === 1 ? '' : 's'}`;
    els.healthInfo.title = `Portraits ${portraits}; verified footprint data ${verified}/${placements.length}; projected overlapping pairs ${pairs}.`;
  }


  async function selectPlacement(index, center = false) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return;
    if (state.selectedIndex >= 0) {
      state.markerEls[state.selectedIndex]?.classList.remove('selected');
      state.rowEls[state.selectedIndex]?.classList.remove('selected');
    }
    state.selectedIndex = index;
    state.markerEls[index]?.classList.add('selected');
    state.rowEls[index]?.classList.add('selected');
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
    els.metaRing.textContent = `${effectiveFootprint(p).toFixed(2)} ${Object.hasOwn(p, 'footprintOverride') ? 'custom' : (p.footprintStatus || 'estimated')}${overlapping ? ' · overlap' : ''}`;
    els.metaRing.className = overlapping ? 'bad' : '';
    els.metaStatus.textContent = replayStatusLabel(p, index);
    els.metaStatus.className = status === 'failed' || status === 'upgrade_failed' ? 'bad'
      : status === 'upgraded' ? 'ok'
        : status === 'placed' || status === 'upgrading' ? 'warn' : '';
  }

  function clearSelection() {
    if (state.selectedIndex >= 0) {
      state.markerEls[state.selectedIndex]?.classList.remove('selected');
      state.rowEls[state.selectedIndex]?.classList.remove('selected');
    }
    state.selectedIndex = -1;
    els.selectedName.textContent = 'Nothing selected';
    els.selectedName.title = '';
    for (const el of [els.metaSlot, els.metaId, els.metaPos, els.metaPlane, els.metaRing, els.metaStatus]) {
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
    if (!name) { els.portraitSkeleton.hidden = true; return; }

    els.portraitSkeleton.hidden = false;
    if (!state.portraitCache.has(name)) {
      try {
        ensureHost();
        const data = await ahk.GetPortrait(name);
        state.portraitCache.set(name, data ? String(data) : '');
      } catch { state.portraitCache.set(name, ''); }
    }
    els.portraitSkeleton.hidden = true;

    const stillSelected = state.selectedIndex >= 0 && (state.doc.placements[state.selectedIndex].towerName || '') === name;
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
    els.portraitStatusBadge.title = missing.length ? `Missing: ${missing.join(', ')}` : (total ? 'All loadout portraits are cached' : 'No strategy loaded');
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
      toast(data ? `${name} portrait refreshed.` : `${name} portrait could not be refreshed.`, data ? 'success' : 'warn');
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
      try { payload = raw ? JSON.parse(String(raw)) : null; } catch { payload = null; }
      if (payload) applyPortraitStatus(payload);
      else await refreshPortraitStatus();
      if (state.selectedIndex >= 0) await updatePortrait(state.doc.placements[state.selectedIndex].towerName || '');
      updateHealth();
      const missing = state.portraitStatus.missing;
      const ready = `${state.portraitStatus.available}/${state.portraitStatus.total}`;
      setStatus(missing.length ? `Portrait sync finished • ${ready} ready • missing: ${missing.join(', ')}.` : `Portraits ready • ${ready}.`);
      toast(missing.length ? `Portrait repair finished: ${ready} ready.` : `All ${state.portraitStatus.total} loadout portraits are ready.`, missing.length ? 'warn' : 'success');
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
    els.resetFootprintBtn.title = enabled ? `Reset to the catalog size (${catalogFootprint(selected).toFixed(2)})` : 'Select a placement first';
  }

  function setFootprint(index, value, reset = false) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return;
    const p = state.doc.placements[index];
    if (reset) delete p.footprintOverride;
    else p.footprintOverride = Math.round(clamp(Number(value) || catalogFootprint(p), 0.5, 4) * 100) / 100;

    updateFootprintPosition(index);
    recomputeCollisions();
    updateFootprintControls(p);
    if (state.selectedIndex === index) renderSelectedMeta();
    updateHealth();
    setStatus(`${p.towerName || `Slot ${p.slot}`} ring size set to ${effectiveFootprint(p).toFixed(2)} for this editor session.`);
  }

  function syncFootprintAcrossTower() {
    if (!state.doc || state.selectedIndex < 0) return;
    const selected = state.doc.placements[state.selectedIndex];
    const targetName = String(selected.towerName || '').trim().toLowerCase();
    const targetSlot = Number(selected.slot) || 0;
    const value = effectiveFootprint(selected);
    let count = 0;

    state.doc.placements.forEach((placement, index) => {
      const sameTower = targetName
        ? String(placement.towerName || '').trim().toLowerCase() === targetName
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
    setStatus(`Synced ring size ${value.toFixed(2)} to ${count} ${selected.towerName || `slot ${selected.slot}`} placement${count === 1 ? '' : 's'}.`);
  }


  function movePlacement(index, x, y, record = true, markDirty = true) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return false;
    const p = state.doc.placements[index];
    const nextX = Math.round(clamp(Number(x) || 0, 0, state.doc.strategyWidth));
    const nextY = Math.round(clamp(Number(y) || 0, 0, state.doc.strategyHeight));
    if (p.x === nextX && p.y === nextY) return false;

    const oldX = p.x, oldY = p.y;
    p.x = nextX;
    p.y = nextY;
    if (record) {
      state.undo.push({ index, oldX, oldY, newX: nextX, newY: nextY });
      state.redo = [];
    }

    updateMarkerPosition(index);
    updateFootprintPosition(index);
    updateRow(index);
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
    if (state.selectedIndex < 0) return;
    const rawX = els.xInput.value.trim();
    const rawY = els.yInput.value.trim();
    if (rawX === '' || rawY === '' || !Number.isFinite(Number(rawX)) || !Number.isFinite(Number(rawY))) {
      const p = state.doc.placements[state.selectedIndex];
      els.xInput.value = p.x;
      els.yInput.value = p.y;
      toast('X and Y must both be numbers.', 'warn');
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
    movePlacement(item.index, item.oldX, item.oldY, false, false);
    state.redo.push(item);
    selectPlacement(item.index, true);
    setDirty(state.undo.length > 0);
    syncControls();
  }

  function redo() {
    const item = state.redo.pop();
    if (!item) return;
    movePlacement(item.index, item.newX, item.newY, false, false);
    state.undo.push(item);
    selectPlacement(item.index, true);
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
    return lines.join(state.doc.newline || '\r\n');
  }

  async function saveCopy() {
    if (!state.doc) return;
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
    const confirmed = await askConfirm({
      title: 'Overwrite the original strategy?',
      body: `${state.doc.name} is rewritten in place. A timestamped backup of the current file is created first.`,
      confirmLabel: 'Overwrite',
      danger: true
    });
    if (!confirmed) { setStatus('Overwrite canceled.'); return; }

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
    if (!state.doc) return;
    const rect = els.viewport.getBoundingClientRect();
    if (rect.width < 2 || rect.height < 2) return;
    const margin = 16;
    state.fitScale = Math.max(0.01, Math.min(
      (rect.width - margin * 2) / state.doc.strategyWidth,
      (rect.height - margin * 2) / state.doc.strategyHeight
    ));
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
      y: (clientY - rect.top - state.offsetY) / state.scale
    };
  }

  function worldToStrategy(clientX, clientY) {
    const pt = screenToWorld(clientX, clientY);
    return {
      x: Math.round(clamp(pt.x - Number(state.doc.geometryOffsetX || 0), 0, state.doc.strategyWidth)),
      y: Math.round(clamp(pt.y - Number(state.doc.geometryOffsetY || 0), 0, state.doc.strategyHeight))
    };
  }

  function placeSelectedAtPointer(clientX, clientY) {
    if (!state.doc) return;
    if (state.selectedIndex < 0) {
      setStatus('Select a placement first, then right-click the map to move it there.');
      toast('Select a placement first, then right-click the map.', 'info', 2600);
      return;
    }
    const index = state.selectedIndex;
    const p = state.doc.placements[index];
    const target = worldToStrategy(clientX, clientY);
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
    updateRow(index);
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

    state.undo.push({ index: drag.index, oldX: drag.oldX, oldY: drag.oldY, newX: p.x, newY: p.y });
    state.redo = [];
    setDirty(true);
    syncControls();
    recomputeCollisions();
    const overlap = state.collisionSet.has(drag.index) ? ' • projected overlap' : '';
    setStatus(`Moved ${p.towerName || `Slot ${p.slot}`} to (${p.x}, ${p.y})${overlap}.`);
  }

  for (const layer of [els.markerLayer, els.footprintLayer]) {
    layer.addEventListener('pointermove', markerPointerMove);
    layer.addEventListener('pointerup', finishMarkerDrag);
    layer.addEventListener('pointercancel', finishMarkerDrag);
  }

  els.viewport.addEventListener('contextmenu', (ev) => {
    if (!state.doc || state.calibration.marking) return;
    ev.preventDefault();
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
    if (!state.doc || ev.button !== 0 || ev.target.closest('.marker, .footprint')) return;
    ev.preventDefault();
    els.viewport.setPointerCapture(ev.pointerId);
    state.panning = { pointerId: ev.pointerId, startX: ev.clientX, startY: ev.clientY, ox: state.offsetX, oy: state.offsetY };
    els.viewport.classList.add('panning');
  });

  els.viewport.addEventListener('pointermove', (ev) => {
    if (!state.panning || ev.pointerId !== state.panning.pointerId) return;
    state.offsetX = state.panning.ox + (ev.clientX - state.panning.startX);
    state.offsetY = state.panning.oy + (ev.clientY - state.panning.startY);
    applyWorldTransform();
  });

  function finishPan(ev) {
    if (!state.panning || ev.pointerId !== state.panning.pointerId) return;
    state.panning = null;
    els.viewport.classList.remove('panning');
  }
  els.viewport.addEventListener('pointerup', finishPan);
  els.viewport.addEventListener('pointercancel', finishPan);

  els.viewport.addEventListener('wheel', (ev) => {
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
  }, { passive: false });


  function replayStatus(p, index) {
    if (p.replayFailed) return 'failed';
    return state.replay.steps.get(String(p.towerId || `tower_${index + 1}`)) || 'pending';
  }

  function replayStatusLabel(p, index) {
    switch (replayStatus(p, index)) {
      case 'upgraded': return 'Placed + upgraded';
      case 'upgrading': return 'Upgrading…';
      case 'upgrade_failed': return 'Placed • upgrade failed';
      case 'placed': return 'Placed';
      case 'failed': return 'Placement failed';
      default: return state.replay.state === 'running' ? 'Waiting' : 'Ready';
    }
  }

  function updateReplaySummary() {
    if (!state.doc) return;
    const counts = { placed: 0, upgrading: 0, upgraded: 0, upgrade_failed: 0, failed: 0 };
    state.doc.placements.forEach((p, index) => {
      const status = replayStatus(p, index);
      if (Object.hasOwn(counts, status)) counts[status]++;
    });
    els.replayPlacedCount.textContent = String(counts.placed + counts.upgrading + counts.upgraded + counts.upgrade_failed);
    els.replayUpgradingCount.textContent = String(counts.upgrading);
    els.replayUpgradedCount.textContent = String(counts.upgraded);
    els.replayFailedCount.textContent = String(counts.failed + counts.upgrade_failed);
    els.replayBar.hidden = !state.replay.state;
  }

  function strategyReplayText() {
    if (!state.doc || !state.doc.placements.length) return { text: '', used: 0, skipped: 0 };
    const lines = replayHeaderLines(state.doc.strategyWidth || 1920, state.doc.strategyHeight || 1009);
    let used = 0;
    let skipped = 0;
    state.doc.placements.forEach((placement, index) => {
      const slot = Number(placement.slot) || 0;
      if (slot < 1 || slot > 5) { skipped++; return; }
      const id = String(placement.towerId || `tower_${index + 1}`).replace(/[\r\n)]/g, '');
      lines.push(`SpawnTower(${Math.round(Number(placement.x) || 0)}, ${Math.round(Number(placement.y) || 0)}, ${slot}, ${id})`);
      used++;
    });
    return { text: used ? `${lines.join('\r\n')}\r\n` : '', used, skipped };
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
      '[Steps]'
    ];
  }

  async function replayStrategyInSandbox() {
    if (!state.doc) return;
    const payload = strategyReplayText();
    if (!payload.text) {
      toast('This strategy has no placements in loadout slots 1-5 to replay.', 'warn', 3600);
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
        state.doc.placements.forEach((p) => { p.replayFailed = false; });
        state.rowEls.forEach((row, index) => updateRow(index, row));
        updateReplaySummary();
        pollReplayStatus(state.replay.epoch);
        setStatus(`Sandbox replay runner launched for ${payload.used} placement${payload.used === 1 ? '' : 's'}.`);
        toast(payload.skipped
          ? `Replay launched • ${payload.skipped} placement${payload.skipped === 1 ? '' : 's'} outside slots 1-5 were skipped.`
          : 'Replay launched. Keep the Sandbox match open and clear existing towers first.', payload.skipped ? 'warn' : 'success', 4800);
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
    } catch {}
    if (complete || epoch !== state.replay.epoch) return;
    state.replay.pollTimer = window.setTimeout(() => pollReplayStatus(epoch), 700);
  }

  function applyReplayStatus(payload) {
    state.replay.state = String(payload.state || '');
    state.replay.failedIds = new Set(Array.isArray(payload.failed) ? payload.failed.map(String) : []);
    state.replay.steps = new Map(Array.isArray(payload.steps) ? payload.steps.map((s) => [String(s.id), String(s.status || 'pending')]) : []);

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
    setStatus(failed
      ? `Sandbox replay complete • ${failed} tower${failed === 1 ? '' : 's'} unconfirmed.`
      : `Sandbox replay complete • ${upgraded} tower${upgraded === 1 ? '' : 's'} placed and upgraded.`);
    return true;
  }

  function announceReplayStep(placement, index, status) {
    const name = placement.towerName || `Tower ${index + 1}`;
    switch (status) {
      case 'placed': return toast(`${name} placed. Preparing upgrade…`, 'success');
      case 'upgrading': return toast(`${name} placed. Checking upgrade…`, 'success');
      case 'upgraded': return toast(`${name} placed and upgraded.`, 'success');
      case 'upgrade_failed': return toast(`${name} was placed, but the upgrade was not confirmed.`, 'warn');
      case 'failed': return toast(`${name} could not be placed.`, 'warn');
      default: return undefined;
    }
  }


  function openCalibration(options = {}) {
    state.calibration.open = true;
    els.calibrationModal.hidden = false;
    populateCalibrationTowerOptions();
    renderCalibrationMarks();
    updateCalibrationControls();
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

    els.calibrationGoSandboxBtn.disabled = !hasDoc || !cal.baselinePath;
    els.calibrationGoSandboxBtn.title = cal.baselinePath ? 'Focus Roblox so you can place the calibration towers.' : 'Capture the clean baseline first.';

    els.calibrationMarkBtn.disabled = !hasDoc || !cal.manualPath;
    els.calibrationMarkBtn.textContent = cal.marking
      ? 'Pause marking'
      : (markCount > 0 && markCount < expected ? `Continue marking (${markCount}/${expected})` : (complete ? 'Review marks' : 'Start guided marking'));

    els.calibrationExportBtn.disabled = !complete;
    els.calibrationExportBtn.title = complete ? 'Export the complete calibration replay .strat.' : `Mark all ${expected || 5} tower centers first.`;
    els.calibrationReplayBtn.disabled = !complete;
    els.calibrationReplayBtn.title = complete ? 'Replay every calibrated placement in the open Sandbox match.' : `Mark all ${expected || 5} tower centers first.`;

    els.calibrationMarkCount.textContent = expected ? `${markCount}/${expected}` : String(markCount);
    els.calibrationSessionInfo.textContent = cal.sessionPath ? pathTail(cal.sessionPath) : 'Not started';
    els.calibrationSessionInfo.title = cal.sessionPath;
    els.calibrationBaselineInfo.textContent = cal.baselinePath ? pathTail(cal.baselinePath) : '—';
    els.calibrationBaselineInfo.title = cal.baselinePath;
    els.calibrationManualInfo.textContent = cal.manualPath ? pathTail(cal.manualPath) : '—';
    els.calibrationManualInfo.title = cal.manualPath;
    els.calibrationMacroInfo.textContent = cal.macroVersion ? `${cal.macroVersion} • ${cal.cameraContract || 'verified'}` : 'Not verified';
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
      setViewportLoading(true, stage === 'baseline' ? 'Aligning the Roblox camera…' : 'Capturing the manual tower sample…');
      setStatus(stage === 'baseline'
        ? 'Calibration: aligning the camera and capturing a clean baseline…'
        : 'Calibration: re-aligning the same camera and capturing your manual placements…');

      const raw = await ahk.CalibrationCapture(stage, state.doc?.mapName || 'Sandbox', options.silentHost === true);
      if (!raw) {
        setStatus(options.auto ? 'Sandbox is not ready for automatic camera preparation yet.' : 'Calibration capture canceled or unavailable.');
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
      toast(stage === 'baseline'
        ? 'Baseline captured. Place your towers manually in Sandbox next.'
        : 'Manual tower sample captured after automatic camera re-alignment.', 'success', 3800);

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
    if (!state.doc) { toast('Open a calibration .strat first.', 'warn'); return; }
    if (!state.calibration.manualPath) { toast('Capture the placed towers first so marking can use that exact screenshot.', 'warn', 4300); return; }
    const total = calibrationTowerCount();
    if (!total) { toast('This calibration strategy does not declare any loadout towers.', 'warn'); return; }

    state.calibration.activeSlot = options.restart === true && !state.calibration.marks.length
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
    toast('Click the CENTER of each cyan ring; its size is measured and synced.', 'info', 4400);
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
    if (!state.calibration.marking) { els.calibrationMarkHud.hidden = true; return; }
    const total = calibrationTowerCount();
    const slot = clamp(Number(state.calibration.activeSlot) || 1, 1, Math.max(1, total));
    const tower = state.doc?.requiredTowers?.[slot - 1] || `Slot ${slot}`;
    els.calibrationMarkHud.hidden = false;
    els.calibrationMarkProgress.textContent = `MARK ${Math.min(state.calibration.marks.length + 1, total)}/${total}`;
    els.calibrationMarkTower.textContent = `Slot ${slot} — ${tower}`;
    els.calibrationMarkInstruction.textContent = 'Click the center of the cyan placement ring; its size is synced to the editor.';
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
    els.metaRing.textContent = 'measured on click';
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

    const search = 112;
    const left = Math.max(0, Math.floor(x - search));
    const top = Math.max(0, Math.floor(y - search));
    const right = Math.min(canvas.width - 1, Math.ceil(x + search));
    const bottom = Math.min(canvas.height - 1, Math.ceil(y + search));
    if (right <= left || bottom <= top) return 0;
    const width = right - left + 1;
    const pixels = context.getImageData(left, top, width, bottom - top + 1).data;

    let best = { r: 0, score: 0 };
    for (let r = 8; r <= search; r++) {
      let cyan = 0;
      let total = 0;
      for (let angle = 0; angle < Math.PI * 2; angle += Math.PI / 36) {
        const px = Math.round(x + Math.cos(angle) * r);
        const py = Math.round(y + Math.sin(angle) * r);
        if (px < left || px > right || py < top || py > bottom) continue;
        const offset = ((py - top) * width + px - left) * 4;
        const red = pixels[offset], green = pixels[offset + 1], blue = pixels[offset + 2];
        total++;
        if (green >= 125 && blue >= 135 && blue > red * 1.25 && green > red * 1.15) cyan++;
      }
      const score = total ? cyan / total : 0;
      if (score > best.score) best = { r, score };
    }
    return best.score >= 0.18 ? best.r : 0;
  }

  function applyMeasuredRingToPlacements(slot, radiusPx) {
    if (!state.doc || !radiusPx) return 0;
    const sample = state.doc.placements.find((p) => Number(p.slot) === Number(slot));
    if (!sample) return 0;
    const projection = projectionAt(sample);
    const scaleX = Number(state.doc.strategyWidth || 1920) / 1920;
    const scaleY = Number(state.doc.strategyHeight || 1009) / 1009;
    const ppu = Math.max(8, (projection.ppuX * scaleX + projection.ppuY * scaleY) / 2);
    const footprint = Math.round(clamp(radiusPx / ppu, 0.5, 4) * 100) / 100;

    let count = 0;
    state.doc.placements.forEach((placement, index) => {
      if (Number(placement.slot) !== Number(slot)) return;
      placement.footprintOverride = footprint;
      placement.footprintStatus = 'sandbox-measured';
      placement.footprintKnown = true;
      styleFootprint(index, state.footprintEls[index], placement);
      count++;
    });
    return count;
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
    const existing = state.calibration.marks.findIndex((m) => Number(m.slot) === slot);
    if (existing >= 0) state.calibration.marks[existing] = mark;
    else state.calibration.marks.push(mark);
    state.calibration.marks.sort((a, b) => Number(a.slot) - Number(b.slot));

    renderCalibrationMarks();
    if (applyMeasuredRingToPlacements(slot, ringRadiusPx)) {
      recomputeCollisions();
      updateHealth();
    }

    const total = calibrationTowerCount();
    if (state.calibration.marks.length >= total) {
      state.calibration.marking = false;
      document.body.classList.remove('marking');
      els.calibrationMarkHud.hidden = true;
      renderCalibrationSidebar();
      setStatus(`Calibration centers complete: ${total}/${total}. Review them before replay.`);
      toast(`All ${total} centers recorded.`, 'success', 4000);
      window.setTimeout(() => openCalibration(), 300);
      return;
    }

    const nextSlot = firstUnmarkedCalibrationSlot(slot + 1 <= total ? slot + 1 : 1);
    state.calibration.activeSlot = nextSlot;
    els.calibrationTowerSelect.value = String(nextSlot);
    renderCalibrationMarkHud();
    renderCalibrationSidebar();
    const nextTower = state.doc.requiredTowers[nextSlot - 1] || `Slot ${nextSlot}`;
    setStatus(`Recorded ${tower} at client-local (${x}, ${y})${ringRadiusPx ? ` • ring ${ringRadiusPx}px synced` : ''}. Next: ${nextTower}.`);
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
        renderCalibrationMarks();
      });
      action.appendChild(remove);
      tr.appendChild(action);
      els.calibrationRows.appendChild(tr);
    });

    if (!state.calibration.marks.length) emptyRow(els.calibrationRows, 6, 'No tower centers marked yet.');
    updateCalibrationControls();
    if (state.calibration.marking) {
      renderCalibrationMarkHud();
      renderCalibrationSidebar();
    }
  }

  function undoLastCalibrationMark() {
    if (!state.calibration.marks.length) { toast('There are no calibration marks to undo.', 'info'); return; }
    const removed = state.calibration.marks.pop();
    state.calibration.activeSlot = Number(removed.slot) || 1;
    els.calibrationTowerSelect.value = String(state.calibration.activeSlot);
    renderCalibrationMarks();
    setStatus(`Removed the ${removed.tower} mark. Mark Slot ${state.calibration.activeSlot} again.`);
  }

  function calibrationReplayText() {
    if (!state.doc) return '';
    const lines = replayHeaderLines(
      state.calibration.clientWidth || state.doc.strategyWidth || 1920,
      state.calibration.clientHeight || state.doc.strategyHeight || 1009
    );
    const perTower = new Map();
    state.calibration.marks.forEach((mark) => {
      const key = String(mark.tower || `slot${mark.slot}`).replace(/[^A-Za-z0-9]+/g, '').toLowerCase() || `slot${mark.slot}`;
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
        setStatus('Calibration replay runner launched. It verifies the installed macro contract before placing anything.');
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
      if (!ok) { toast('Roblox was not found. Open Sandbox first.', 'warn', 4000); return; }
      setStatus('Sandbox focused. Place the five test towers, then return to Strategy Lab.');
    } catch (err) {
      toast(`Could not focus Roblox: ${err.message || err}`, 'error');
    }
  }


  function showRailPanel(which) {
    const placements = which === 'placements';
    els.panelPlacements.hidden = !placements;
    els.panelStrategy.hidden = placements;
    els.tabPlacements.classList.toggle('is-active', placements);
    els.tabStrategy.classList.toggle('is-active', !placements);
    els.tabPlacements.setAttribute('aria-selected', String(placements));
    els.tabStrategy.setAttribute('aria-selected', String(!placements));
  }


  function syncControls() {
    const loaded = Boolean(state.doc);
    const selected = loaded && state.selectedIndex >= 0;
    const mapName = selectedMapName();

    els.saveCopyBtn.disabled = !loaded;
    els.overwriteBtn.disabled = !loaded;
    els.undoBtn.disabled = !loaded || !state.undo.length;
    els.redoBtn.disabled = !loaded || !state.redo.length;
    els.replayStrategyBtn.disabled = !loaded || !state.doc.placements.length;
    els.fitBtn.disabled = !loaded;
    els.layerSelect.disabled = !loaded;
    els.importMapBtn.disabled = !mapName;
    els.captureMapBtn.disabled = !mapName;
    els.syncPortraitsBtn.disabled = !loaded;

    els.xInput.disabled = !selected;
    els.yInput.disabled = !selected;
    els.applyXYBtn.disabled = !selected;
    els.refreshSelectedBtn.disabled = !selected || !state.doc.placements[state.selectedIndex]?.towerName;
  }


  els.openBtn.addEventListener('click', openStrategy);
  els.emptyOpenBtn.addEventListener('click', openStrategy);
  els.saveCopyBtn.addEventListener('click', saveCopy);
  els.overwriteBtn.addEventListener('click', overwrite);
  els.undoBtn.addEventListener('click', undo);
  els.redoBtn.addEventListener('click', redo);
  els.replayStrategyBtn.addEventListener('click', replayStrategyInSandbox);
  els.calibrationBtn.addEventListener('click', () => openCalibration());

  els.mapPickerBtn.addEventListener('click', (ev) => { ev.stopPropagation(); toggleMapMenu(); });
  els.mapSearch.addEventListener('input', () => renderMapMenu(els.mapSearch.value));
  els.mapSearch.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') { ev.preventDefault(); toggleMapMenu(false); els.mapPickerBtn.focus(); }
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
    setStatus(`Layer: ${els.layerSelect.selectedOptions[0]?.textContent || 'All placements'} • ${els.placementCount.textContent} shown.`);
  });
  els.fitBtn.addEventListener('click', () => fitWorld(true));
  els.footprintBtn.addEventListener('click', () => {
    state.footprintsVisible = !state.footprintsVisible;
    els.footprintLayer.classList.toggle('off', !state.footprintsVisible);
    els.footprintBtn.classList.toggle('is-on', state.footprintsVisible);
    setStatus(state.footprintsVisible ? 'Placement rings visible. Red marks a projected overlap.' : 'Placement rings hidden.');
  });

  els.applyXYBtn.addEventListener('click', applyCoordinateInputs);
  for (const input of [els.xInput, els.yInput]) {
    input.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); applyCoordinateInputs(); } });
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
  els.tabStrategy.addEventListener('click', () => showRailPanel('strategy'));

  els.confirmOkBtn.addEventListener('click', () => settleConfirm(true));
  els.confirmCancelBtn.addEventListener('click', () => settleConfirm(false));
  els.confirmModal.addEventListener('pointerdown', (ev) => { if (ev.target === els.confirmModal) settleConfirm(false); });

  els.calibrationCloseBtn.addEventListener('click', closeCalibration);
  els.calibrationModal.addEventListener('pointerdown', (ev) => { if (ev.target === els.calibrationModal) closeCalibration(); });
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
      if (ev.key === 'Escape') { ev.preventDefault(); settleConfirm(false); }
      else if (ev.key === 'Enter') { ev.preventDefault(); settleConfirm(true); }
      return;
    }
    if (ev.key === 'Escape') {
      if (state.calibration.marking) { ev.preventDefault(); pauseGuidedMarkingAndReturn(); return; }
      if (state.calibration.open) { ev.preventDefault(); closeCalibration(); return; }
      if (!els.mapMenu.hidden) { ev.preventDefault(); toggleMapMenu(false); els.mapPickerBtn.focus(); return; }
    }
    const inField = ev.target instanceof HTMLInputElement || ev.target instanceof HTMLSelectElement;
    const key = ev.key.toLowerCase();
    if (ev.ctrlKey && key === 'o') { ev.preventDefault(); openStrategy(); }
    else if (ev.ctrlKey && key === 's') { ev.preventDefault(); saveCopy(); }
    else if (ev.ctrlKey && key === 'z' && !inField) { ev.preventDefault(); undo(); }
    else if (ev.ctrlKey && key === 'y' && !inField) { ev.preventDefault(); redo(); }
    else if (key === '0' && state.doc && !ev.ctrlKey && !inField) { ev.preventDefault(); fitWorld(true); }
  });

  window.strategyLab = { loadStrategy, setMapPayload, notify };

  async function loadBrandIcon() {
    try {
      const data = await ahk.GetBrandIcon();
      if (!data) return;
      els.brandIcon.src = String(data);
      els.brandIcon.hidden = false;
      els.brandFallback.hidden = true;
    } catch {}
  }

  async function ready() {
    showRailPanel('placements');
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
