from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"patch anchor not found: {label}")
    return text.replace(old, new, 1)


# ---------- index.html ----------
path = Path("_app/ui/index.html")
text = path.read_text(encoding="utf-8-sig")
text = replace_once(
    text,
    '  <link rel="stylesheet" href="styles.css" />',
    '  <link rel="stylesheet" href="styles.css" />\n  <link rel="stylesheet" href="spatial-actions.css" />',
    "spatial css",
)
text = replace_once(
    text,
    '          <div id="markerLayer" class="marker-layer"></div>\n          <div id="calibrationLayer" class="calibration-layer"></div>',
    '          <div id="markerLayer" class="marker-layer"></div>\n          <svg id="actionLayer" class="action-layer" aria-label="Spatial strategy actions"></svg>\n          <div id="calibrationLayer" class="calibration-layer"></div>',
    "action layer",
)
text = replace_once(
    text,
    '''        <button class="rail-tab" id="tabStrategy" type="button" role="tab" aria-selected="false"
          aria-controls="panelStrategy">
          Strategy
        </button>''',
    '''        <button class="rail-tab" id="tabActions" type="button" role="tab" aria-selected="false"
          aria-controls="panelActions">
          Actions <span id="actionCount" class="tab-count">0</span>
        </button>
        <button class="rail-tab" id="tabStrategy" type="button" role="tab" aria-selected="false"
          aria-controls="panelStrategy">
          Strategy
        </button>''',
    "actions tab",
)
text = replace_once(
    text,
    '''        <section class="rail-panel" id="panelStrategy" role="tabpanel" aria-labelledby="tabStrategy" hidden>
          <dl class="info">''',
    '''        <section class="rail-panel" id="panelActions" role="tabpanel" aria-labelledby="tabActions" hidden>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th class="c-idx">#</th>
                  <th>Action</th>
                  <th>Unit</th>
                  <th class="c-num">X</th>
                  <th class="c-num">Y</th>
                </tr>
              </thead>
              <tbody id="actionRows"></tbody>
            </table>
          </div>
        </section>
        <section class="rail-panel" id="panelStrategy" role="tabpanel" aria-labelledby="tabStrategy" hidden>
          <dl class="info">''',
    "actions panel",
)
text = text.replace("Strategy Lab v4.3 · pizzaroles24", "Strategy Lab v4.4 · pizzaroles24")
text = replace_once(
    text,
    '  <script src="app.js"></script>',
    '  <script src="spatial-actions.js"></script>\n  <script src="app.js"></script>',
    "spatial js",
)
path.write_text(text, encoding="utf-8")


# ---------- app.js ----------
path = Path("_app/ui/app.js")
text = path.read_text(encoding="utf-8-sig")
text = replace_once(
    text,
    "    calibrationLayer: $('calibrationLayer'),",
    "    calibrationLayer: $('calibrationLayer'),\n    actionLayer: $('actionLayer'),",
    "action layer ref",
)
text = replace_once(
    text,
    "    tabPlacements: $('tabPlacements'),\n    tabStrategy: $('tabStrategy'),\n    placementHeading: $('placementHeading'),\n    placementCount: $('placementCount'),\n    panelPlacements: $('panelPlacements'),\n    panelStrategy: $('panelStrategy'),",
    "    tabPlacements: $('tabPlacements'),\n    tabActions: $('tabActions'),\n    tabStrategy: $('tabStrategy'),\n    placementHeading: $('placementHeading'),\n    placementCount: $('placementCount'),\n    actionCount: $('actionCount'),\n    panelPlacements: $('panelPlacements'),\n    panelActions: $('panelActions'),\n    panelStrategy: $('panelStrategy'),\n    actionRows: $('actionRows'),",
    "action refs",
)
text = replace_once(
    text,
    "    selectedIndex: -1,\n    scale: 1,",
    "    selectedIndex: -1,\n    selectedActionIndex: -1,\n    scale: 1,",
    "selected action state",
)
text = replace_once(
    text,
    "    rowEls: [],\n    collisionSet: new Set(),",
    "    rowEls: [],\n    actionEls: [],\n    actionRowEls: [],\n    actionDragging: null,\n    collisionSet: new Set(),",
    "action state arrays",
)

# Initial load must parse actions too.
text = replace_once(
    text,
    '''  function loadStrategy(payload) {
    if (typeof payload === 'string') payload = JSON.parse(payload);
    if (!Array.isArray(payload.placements)) payload.placements = [];
    if (!Array.isArray(payload.requiredTowers)) payload.requiredTowers = [];
''',
    '''  function loadStrategy(payload) {
    if (typeof payload === 'string') payload = JSON.parse(payload);
    if (!Array.isArray(payload.placements)) payload.placements = [];
    if (!Array.isArray(payload.requiredTowers)) payload.requiredTowers = [];
    payload.spatialActions = spatialActionsFromText(payload.text || '');
''',
    "initial spatial parse",
)
text = replace_once(
    text,
    '''    state.doc = payload;
    state.activeSlot = 0;
    state.selectedIndex = -1;
    state.undo = [];''',
    '''    state.doc = payload;
    state.activeSlot = 0;
    state.selectedIndex = -1;
    state.selectedActionIndex = -1;
    state.undo = [];''',
    "initial action selection reset",
)
text = replace_once(
    text,
    '''    buildFootprints();
    buildMarkers();
    buildRows();
    recomputeCollisions();''',
    '''    buildFootprints();
    buildMarkers();
    buildActionLayer();
    buildRows();
    buildActionRows();
    recomputeCollisions();''',
    "initial action build",
)

ACTION_BLOCK = r'''
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
'''
text = replace_once(text, "  function buildRows() {", ACTION_BLOCK + "\n  function buildRows() {", "action helpers")

text = replace_once(
    text,
    '''  async function selectPlacement(index, center = false) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return;
    if (state.selectedIndex >= 0) {''',
    '''  async function selectPlacement(index, center = false) {
    if (!state.doc || index < 0 || index >= state.doc.placements.length) return;
    clearActionSelection();
    if (state.selectedIndex >= 0) {''',
    "placement clears action",
)
text = replace_once(
    text,
    '''  function clearSelection() {
    if (state.selectedIndex >= 0) {''',
    '''  function clearSelection() {
    clearActionSelection();
    if (state.selectedIndex >= 0) {''',
    "clear action selection",
)
text = replace_once(
    text,
    '''    if (record) {
      state.undo.push({ index, oldX, oldY, newX: nextX, newY: nextY });''',
    '''    if (record) {
      state.undo.push({ kind: 'placement', index, oldX, oldY, newX: nextX, newY: nextY });''',
    "placement undo kind",
)
text = replace_once(
    text,
    '''    updateRow(index);
    recomputeCollisions();''',
    '''    updateRow(index);
    refreshActionGeometry();
    recomputeCollisions();''',
    "placement source refresh",
)

old_apply = '''  function applyCoordinateInputs() {
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
'''
new_apply = '''  function applyCoordinateInputs() {
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
'''
text = replace_once(text, old_apply, new_apply, "coordinate actions")

old_undo = '''  function undo() {
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
'''
new_undo = '''  function undo() {
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
'''
text = replace_once(text, old_undo, new_undo, "undo redo actions")

text = replace_once(
    text,
    '''    for (const p of state.doc.placements) {
      const idx = Number(p.lineNo) - 1;
      if (idx < 0 || idx >= lines.length) continue;
      lines[idx] = lines[idx].replace(/^(\\s*SpawnTower\\(\\s*)-?\\d+(\\s*,\\s*)-?\\d+(.*)$/i, `$1${p.x}$2${p.y}$3`);
    }
    return lines.join(state.doc.newline || '\\r\\n');''',
    '''    for (const p of state.doc.placements) {
      const idx = Number(p.lineNo) - 1;
      if (idx < 0 || idx >= lines.length) continue;
      lines[idx] = lines[idx].replace(/^(\\s*SpawnTower\\(\\s*)-?\\d+(\\s*,\\s*)-?\\d+(.*)$/i, `$1${p.x}$2${p.y}$3`);
    }
    for (const action of state.doc.spatialActions || []) {
      const idx = Number(action.lineNo) - 1;
      if (idx < 0 || idx >= lines.length || !window.StrategySpatial?.rewriteLine) continue;
      lines[idx] = window.StrategySpatial.rewriteLine(lines[idx], action);
    }
    return lines.join(state.doc.newline || '\\r\\n');''',
    "render action text",
)

text = replace_once(
    text,
    '''  function placeSelectedAtPointer(clientX, clientY) {
    if (!state.doc) return;
    if (state.selectedIndex < 0) {
      setStatus('Select a placement first, then right-click the map to move it there.');
      toast('Select a placement first, then right-click the map.', 'info', 2600);
      return;
    }
    const index = state.selectedIndex;
    const p = state.doc.placements[index];
    const target = worldToStrategy(clientX, clientY);''',
    '''  function placeSelectedAtPointer(clientX, clientY) {
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
    const p = state.doc.placements[index];''',
    "right click action destination",
)
text = replace_once(
    text,
    "    updateRangePosition(index);\n    updateRow(index);\n    recomputeCollisions(index);",
    "    updateRangePosition(index);\n    updateRow(index);\n    refreshActionGeometry();\n    recomputeCollisions(index);",
    "drag source refresh",
)
text = replace_once(
    text,
    "    state.undo.push({ index: drag.index, oldX: drag.oldX, oldY: drag.oldY, newX: p.x, newY: p.y });",
    "    state.undo.push({ kind: 'placement', index: drag.index, oldX: drag.oldX, oldY: drag.oldY, newX: p.x, newY: p.y });",
    "drag undo kind",
)

ACTION_DRAG = r'''
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
'''
text = replace_once(text, "  for (const layer of [els.markerLayer, els.footprintLayer]) {", ACTION_DRAG + "\n  for (const layer of [els.markerLayer, els.footprintLayer]) {", "action dragging")

text = replace_once(
    text,
    "    const marker = ev.target.closest('.marker');\n    if (marker) {",
    "    const actionHandle = ev.target.closest('.action-handle');\n    if (actionHandle) {\n      const index = Number(actionHandle.dataset.index);\n      if (Number.isInteger(index)) {\n        selectAction(index, false);\n        setStatus('Action selected. Right-click an empty map position to move its destination there.');\n      }\n      return;\n    }\n    const marker = ev.target.closest('.marker');\n    if (marker) {",
    "context action select",
)
text = replace_once(
    text,
    "    if (!state.doc || ev.button !== 0 || ev.target.closest('.marker, .footprint')) return;",
    "    if (!state.doc || ev.button !== 0 || ev.target.closest('.marker, .footprint, .action-handle')) return;",
    "pan ignores action",
)
text = replace_once(
    text,
    "    if (tapped && state.selectedIndex >= 0 && !state.calibration.marking) {",
    "    if (tapped && (state.selectedIndex >= 0 || state.selectedActionIndex >= 0) && !state.calibration.marking) {",
    "tap clears action",
)

# Parsed code path must rebuild actions too.
text = replace_once(
    text,
    '''    if (!Array.isArray(payload.placements)) payload.placements = [];
    if (!Array.isArray(payload.requiredTowers)) payload.requiredTowers = [];

    const previous = state.doc;''',
    '''    if (!Array.isArray(payload.placements)) payload.placements = [];
    if (!Array.isArray(payload.requiredTowers)) payload.requiredTowers = [];
    payload.spatialActions = spatialActionsFromText(payload.text || '');

    const previous = state.doc;''',
    "code spatial parse",
)
text = replace_once(
    text,
    '''    state.doc = payload;
    state.selectedIndex = -1;
    state.undo = [];''',
    '''    state.doc = payload;
    state.selectedIndex = -1;
    state.selectedActionIndex = -1;
    state.undo = [];''',
    "code action selection reset",
)
text = replace_once(
    text,
    '''    buildFootprints();
    buildMarkers();
    buildRows();
    recomputeCollisions();''',
    '''    buildFootprints();
    buildMarkers();
    buildActionLayer();
    buildRows();
    buildActionRows();
    recomputeCollisions();''',
    "code action build",
)
text = replace_once(
    text,
    "    state.doc.placements.forEach((p, index) => updateMarkerPosition(index, state.markerEls[index], p));",
    "    state.doc.placements.forEach((p, index) => updateMarkerPosition(index, state.markerEls[index], p));\n    refreshActionGeometry();",
    "geometry actions",
)
text = replace_once(
    text,
    '''    const total = state.doc.placements.length;
    const overlaps = state.collisionPairs.size;
    els.summaryText.textContent = `${total} placement${total === 1 ? '' : 's'} · ${overlaps} overlap${overlaps === 1 ? '' : 's'}`;''',
    '''    const total = state.doc.placements.length;
    const actionTotal = state.doc.spatialActions?.length || 0;
    const overlaps = state.collisionPairs.size;
    els.summaryText.textContent = `${total} placement${total === 1 ? '' : 's'} · ${actionTotal} action${actionTotal === 1 ? '' : 's'} · ${overlaps} overlap${overlaps === 1 ? '' : 's'}`;''',
    "action summary",
)

old_show = '''  function showRailPanel(which) {
    const placements = which === 'placements';
    els.panelPlacements.hidden = !placements;
    els.panelStrategy.hidden = placements;
    els.tabPlacements.classList.toggle('is-active', placements);
    els.tabStrategy.classList.toggle('is-active', !placements);
    els.tabPlacements.setAttribute('aria-selected', String(placements));
    els.tabStrategy.setAttribute('aria-selected', String(!placements));
  }
'''
new_show = '''  function showRailPanel(which) {
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
'''
text = replace_once(text, old_show, new_show, "actions rail tab")
text = replace_once(
    text,
    "    const selected = loaded && state.selectedIndex >= 0;",
    "    const selected = loaded && (state.selectedIndex >= 0 || state.selectedActionIndex >= 0);",
    "action controls selected",
)
text = replace_once(
    text,
    "    els.refreshSelectedBtn.disabled = !selected || !state.doc.placements[state.selectedIndex]?.towerName;",
    "    els.refreshSelectedBtn.disabled = state.selectedIndex < 0 || !state.doc.placements[state.selectedIndex]?.towerName;",
    "portrait only placement",
)
text = replace_once(
    text,
    "  els.tabPlacements.addEventListener('click', () => showRailPanel('placements'));\n  els.tabStrategy.addEventListener('click', () => showRailPanel('strategy'));",
    "  els.tabPlacements.addEventListener('click', () => showRailPanel('placements'));\n  els.tabActions.addEventListener('click', () => showRailPanel('actions'));\n  els.tabStrategy.addEventListener('click', () => showRailPanel('strategy'));",
    "actions tab listener",
)
text = replace_once(
    text,
    "      : 'Wheel zoom  ·  Drag map to pan  ·  Drag tower to move  ·  Right-click to place selected';",
    "      : 'Wheel zoom  ·  Drag tower/action to move  ·  Right-click to place selected destination';",
    "visual hint",
)
path.write_text(text, encoding="utf-8")


# ---------- packaging / validation contracts ----------
path = Path("_app/run_editor.ps1")
text = path.read_text(encoding="utf-8-sig")
text = replace_once(
    text,
    "'StrategyEditorHost.ahk', 'ui\\index.html', 'ui\\styles.css', 'ui\\app.js',",
    "'StrategyEditorHost.ahk', 'ui\\index.html', 'ui\\styles.css', 'ui\\spatial-actions.css', 'ui\\app.js', 'ui\\spatial-actions.js',",
    "run editor assets",
)
path.write_text(text, encoding="utf-8")

path = Path("submacros/safe_update.ps1")
text = path.read_text(encoding="utf-8-sig")
text = replace_once(
    text,
    "    '_app\\ui\\styles.css',\n    '_app\\ui\\app.js',",
    "    '_app\\ui\\styles.css',\n    '_app\\ui\\spatial-actions.css',\n    '_app\\ui\\app.js',\n    '_app\\ui\\spatial-actions.js',",
    "safe update assets",
)
path.write_text(text, encoding="utf-8")

path = Path("_app/self_test.ps1")
text = path.read_text(encoding="utf-8-sig")
text = replace_once(
    text,
    "  'StrategyEditorHost.ahk', 'ui\\index.html', 'ui\\styles.css', 'ui\\app.js',",
    "  'StrategyEditorHost.ahk', 'ui\\index.html', 'ui\\styles.css', 'ui\\spatial-actions.css', 'ui\\app.js', 'ui\\spatial-actions.js',",
    "self test assets",
)
SPATIAL_CONTRACTS = r'''
$spatialPath = Join-Path $Root 'ui\spatial-actions.js'
$spatialText = if (Test-Path -LiteralPath $spatialPath) { [IO.File]::ReadAllText($spatialPath) } else { '' }
if ($spatialText -notmatch 'CloneTower' -or $spatialText -notmatch 'BrawlerReposition' -or $spatialText -notmatch 'EnforcerReposition' -or $spatialText -notmatch 'rewriteLine') { Fail 'Strategy Lab spatial-action parser/rewriter is incomplete' } else { Pass 'Strategy Lab spatial-action parser/rewriter' }
if ($html -notmatch 'id="actionLayer"' -or $html -notmatch 'id="tabActions"' -or $html -notmatch 'id="actionRows"' -or $html -notmatch 'spatial-actions\.js' -or $html -notmatch 'Strategy Lab v4\.4') { Fail 'Strategy Lab v4.4 spatial-action UI shell is incomplete' } else { Pass 'Strategy Lab v4.4 spatial-action UI shell' }
if ($js -notmatch 'buildActionLayer' -or $js -notmatch 'selectAction' -or $js -notmatch 'moveAction' -or $js -notmatch 'StrategySpatial\.rewriteLine') { Fail 'Strategy Lab spatial-action visual editing is incomplete' } else { Pass 'Strategy Lab spatial-action visual editing' }
'''
text = replace_once(
    text,
    "if ($mainText -notmatch 'ApplyRuntimePlacementSafePitch'",
    SPATIAL_CONTRACTS + "\nif ($mainText -notmatch 'ApplyRuntimePlacementSafePitch'",
    "self test spatial contracts",
)
text = text.replace("Strategy Lab v4\\.3 · pizzaroles24", "Strategy Lab v4\\.4 · pizzaroles24")
path.write_text(text, encoding="utf-8")

path = Path("README.md")
text = path.read_text(encoding="utf-8-sig")
text = replace_once(
    text,
    "Strategy Lab, a separate safe visual editor for `.strat` files with published placement footprints, attack ranges, map backgrounds, calibration persistence, and split-path range tracking, opened straight",
    "Strategy Lab, a separate safe visual editor for `.strat` files with published placement footprints, attack ranges, map backgrounds, calibration persistence, split-path range tracking, and draggable Clone/Brawler/Enforcer action destinations, opened straight",
    "README Strategy Lab feature",
)
path.write_text(text, encoding="utf-8")

print("Strategy Lab v4.4 spatial action patch applied")
