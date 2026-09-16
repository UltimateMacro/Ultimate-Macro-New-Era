(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.StrategySpatial = api;
})(typeof window !== 'undefined' ? window : globalThis, function () {
  'use strict';

  const NUMBER = '-?\\d+(?:\\.\\d+)?';

  function cleanId(value) {
    const text = String(value || '').trim();
    if (text.length >= 2) {
      const first = text[0];
      const last = text[text.length - 1];
      if ((first === '"' && last === '"') || (first === "'" && last === "'")) return text.slice(1, -1);
    }
    return text;
  }

  function toInt(value) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.round(number) : 0;
  }

  function parseLine(line, lineNo) {
    let match = line.match(new RegExp(`^\\s*CloneTower\\(\\s*([^,]+?)\\s*,\\s*(${NUMBER})\\s*,\\s*(${NUMBER})(?:\\s*,\\s*([^)]*?))?\\s*\\)\\s*(?:;.*)?$`, 'i'));
    if (match) {
      return {
        lineNo,
        kind: 'clone',
        command: 'CloneTower',
        label: 'Hologram / Clone',
        actorId: cleanId(match[1]),
        targetId: cleanId(match[1]),
        x: toInt(match[2]),
        y: toInt(match[3]),
        wait: String(match[4] || '').trim(),
      };
    }

    match = line.match(new RegExp(`^\\s*BrawlerReposition\\(\\s*([^,]+?)\\s*,\\s*(${NUMBER})\\s*,\\s*(${NUMBER})\\s*\\)\\s*(?:;.*)?$`, 'i'));
    if (match) {
      return {
        lineNo,
        kind: 'brawler-reposition',
        command: 'BrawlerReposition',
        label: 'Brawler Reposition',
        actorId: cleanId(match[1]),
        targetId: cleanId(match[1]),
        x: toInt(match[2]),
        y: toInt(match[3]),
      };
    }

    match = line.match(new RegExp(`^\\s*EnforcerReposition\\(\\s*([^,]+?)\\s*,\\s*([^,]+?)\\s*,\\s*(${NUMBER})\\s*,\\s*(${NUMBER})\\s*\\)\\s*(?:;.*)?$`, 'i'));
    if (match) {
      return {
        lineNo,
        kind: 'enforcer-reposition',
        command: 'EnforcerReposition',
        label: 'Enforcer Carry',
        actorId: cleanId(match[1]),
        targetId: cleanId(match[2]),
        x: toInt(match[3]),
        y: toInt(match[4]),
      };
    }

    return null;
  }

  function parse(text) {
    const actions = [];
    const lines = String(text || '').replace(/\r/g, '').split('\n');
    let section = '';
    lines.forEach((line, index) => {
      const heading = line.trim().match(/^\[([^\]]+)\]$/);
      if (heading) {
        section = heading[1].trim().toLowerCase();
        return;
      }
      if (section !== 'steps') return;
      const action = parseLine(line, index + 1);
      if (action) actions.push(action);
    });
    return actions;
  }

  function rewriteLine(line, action) {
    const x = toInt(action?.x);
    const y = toInt(action?.y);
    const kind = String(action?.kind || '');

    if (kind === 'clone') {
      return String(line).replace(
        /^(\s*CloneTower\(\s*[^,]+?\s*,\s*)-?\d+(?:\.\d+)?(\s*,\s*)-?\d+(?:\.\d+)?(\s*(?:,\s*[^)]*?)?\s*\)\s*(?:;.*)?)$/i,
        `$1${x}$2${y}$3`,
      );
    }

    if (kind === 'brawler-reposition') {
      return String(line).replace(
        /^(\s*BrawlerReposition\(\s*[^,]+?\s*,\s*)-?\d+(?:\.\d+)?(\s*,\s*)-?\d+(?:\.\d+)?(\s*\)\s*(?:;.*)?)$/i,
        `$1${x}$2${y}$3`,
      );
    }

    if (kind === 'enforcer-reposition') {
      return String(line).replace(
        /^(\s*EnforcerReposition\(\s*[^,]+?\s*,\s*[^,]+?\s*,\s*)-?\d+(?:\.\d+)?(\s*,\s*)-?\d+(?:\.\d+)?(\s*\)\s*(?:;.*)?)$/i,
        `$1${x}$2${y}$3`,
      );
    }

    return String(line);
  }

  return Object.freeze({ parse, parseLine, rewriteLine, cleanId });
});
