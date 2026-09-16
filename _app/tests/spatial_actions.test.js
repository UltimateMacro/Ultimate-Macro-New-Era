const assert = require('node:assert/strict');
const spatial = require('../ui/spatial-actions.js');

const source = `[Settings]\nrequiredTowers=Hacker, Brawler, Enforcer, Juggernaut\n\n[Steps]\nSpawnTower(100, 100, 1, Hack1)\nCloneTower(Hack1, 200, 210, 4000)\nBrawlerReposition(Brawl1, 300, 310) ; keep comment\nEnforcerReposition(Enf1, Jug1, 400, 410)\nSleep(1000)\n`;

const actions = spatial.parse(source);
assert.equal(actions.length, 3);
assert.deepEqual(
  actions.map((a) => [a.kind, a.actorId, a.targetId, a.x, a.y]),
  [
    ['clone', 'Hack1', 'Hack1', 200, 210],
    ['brawler-reposition', 'Brawl1', 'Brawl1', 300, 310],
    ['enforcer-reposition', 'Enf1', 'Jug1', 400, 410],
  ],
);
assert.equal(actions[0].wait, '4000');

const clone = spatial.rewriteLine('CloneTower(Hack1, 200, 210, 4000)', { ...actions[0], x: 222, y: 333 });
assert.equal(clone, 'CloneTower(Hack1, 222, 333, 4000)');

const brawler = spatial.rewriteLine('  BrawlerReposition(Brawl1, 300, 310) ; keep comment', {
  ...actions[1],
  x: 444,
  y: 555,
});
assert.equal(brawler, '  BrawlerReposition(Brawl1, 444, 555) ; keep comment');

const enforcer = spatial.rewriteLine('EnforcerReposition(Enf1, Jug1, 400, 410)', {
  ...actions[2],
  x: 666,
  y: 777,
});
assert.equal(enforcer, 'EnforcerReposition(Enf1, Jug1, 666, 777)');

assert.equal(spatial.parse('[Info]\ndesc=CloneTower(Hack1, 1, 2)\n').length, 0);
assert.equal(spatial.cleanId('"Jug1"'), 'Jug1');

console.log('spatial-actions tests: PASS');
