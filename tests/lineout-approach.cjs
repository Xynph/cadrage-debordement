'use strict';
// Scène qui précède une touche (« Sortie en touche », ou « Avantage » entre la sortie et la touche) :
// les avants des deux équipes sont déjà en marche vers leur place d'alignement, à mi-chemin entre
// leur place habituelle dans cette scène et leur place dans la touche qui suit. Les arrières ne
// bougent pas. Une sortie qui ne mène pas à une touche (mêlée après avantage, mi-temps…) est inchangée.
// La touche est lue dans le journal, sans le modifier ni tirer au sort.
const assert = require('node:assert/strict');
const { context } = require('./harness.cjs');

const EPS = 1e-9;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
function reseed(run, seed) {
  run(`(function(){let s=${seed}*7919+13;Math.random=()=>{s=(Math.imul(s,1664525)+1013904223)>>>0;return s/4294967296};})()`);
}

let approaches = 0, plain = 0, viaAdvantage = 0, forwards = 0, longest = 0;
for (const seed of [1, 2, 3, 4]) {
  for (const club of [0, 3, 7]) {
    const { run } = context();
    reseed(run, seed);
    run(`start(${club}); S.tactic="${seed % 2 ? 'conquete' : 'large'}"; beginMatch(); continueMatch();`);
    const keys = new Set();
    for (let i = 0; i < 4000 && !run('S.live.finished'); i++) {
      run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
      const kind = run('matchScene(S.live).kind');
      if (!['touch', 'advantage'].includes(kind)) continue;
      const key = run('JSON.stringify(matchScene(S.live).key)');
      if (keys.has(key)) continue;
      keys.add(key);
      const before = run('JSON.stringify(S.live,(k,v)=>k==="visualSource"?undefined:v)');
      // Scène affichée, puis la même scène sans la suite du journal (place habituelle), puis la touche qui suit.
      const [scene, generic, lineout, between] = JSON.parse(run(`(function(){
        const l=S.live,events=l.events,at=playback(l).cursor;
        const scene=matchScene(l);
        l.events=events.slice(0,at+1);const generic=matchScene(l);l.events=events;
        let next=null,between=0;for(let i=at+1;i<events.length&&i<=at+2;i++){const k=events[i].scene?.kind;if(k==='lineout'){next=i;break}if(k!=='advantage')break;between++}
        let lineout=null;if(next!==null){const p=playback(l),saved=p.cursor;p.cursor=next;lineout=matchScene(l);p.cursor=saved}
        return JSON.stringify([scene,generic,lineout,between]);})()`));
      assert.equal(run('JSON.stringify(S.live,(k,v)=>k==="visualSource"?undefined:v)'), before, 'lecture du journal sans modification');
      assert.equal(JSON.stringify(scene.ball), JSON.stringify(generic.ball), 'le ballon de la scène reste celui du fait enregistré');
      if (!lineout) {
        assert.deepEqual(scene.players, generic.players, `${kind} sans touche à suivre : scène inchangée`);
        plain++;
        continue;
      }
      approaches++;
      if (kind === 'touch' && between) viaAdvantage++;
      for (const p of scene.players) {
        const g = generic.players.find(q => q.id === p.id && q.side === p.side);
        assert.ok(g, `joueur ${p.id} présent dans les deux lectures`);
        if (p.slot >= 8) {
          assert.ok(p.x === g.x && p.y === g.y, `arrière ${p.id} inchangé`);
          continue;
        }
        const spot = lineout.players.find(q => q.id === p.id && q.side === p.side);
        assert.ok(spot, `avant ${p.id} présent dans la touche qui suit`);
        // Repère de la place d'alignement : celle de la scène de touche (lanceur sur la touche compris).
        // Place habituelle lue après bornage (1,5–98,5 × 2–68) : sur une borne, elle peut être au-delà ; on vérifie alors l'encadrement.
        const half = (g0, s0, lo, hi) => clamp(g0 + (s0 - g0) * 0.5, lo, hi);
        const fits = (v, g0, s0, lo, hi) => g0 > lo && g0 < hi ? Math.abs(v - half(g0, s0, lo, hi)) < EPS
          : v >= Math.min(half(g0, s0, lo, hi), g0 === lo ? lo : hi) - EPS && v <= Math.max(half(g0, s0, lo, hi), g0 === lo ? lo : hi) + EPS;
        assert.ok(fits(p.x, g.x, spot.x, 1.5, 98.5) && fits(p.y, g.y, spot.y, 2, 68), `${kind} : avant ${p.id} à mi-chemin de sa place d'alignement (${p.x}, ${p.y}) depuis (${g.x}, ${g.y}) vers (${spot.x}, ${spot.y})`);
        const whole = Math.hypot(spot.x - g.x, spot.y - g.y), left = Math.hypot(spot.x - p.x, spot.y - p.y);
        const inside = g.x > 1.5 && g.x < 98.5 && g.y > 2 && g.y < 68;
        if (whole > 1 && inside) assert.ok(left > 0.25 * whole && left < 0.75 * whole + 1, `${kind} : avant ${p.id} en marche, pas encore aligné (${left.toFixed(1)} m sur ${whole.toFixed(1)})`);
        longest = Math.max(longest, left);
        forwards++;
      }
    }
  }
}
assert.ok(approaches >= 40, `trop peu de sorties suivies d'une touche : ${approaches}`);
assert.ok(plain >= 3, `trop peu de sorties sans touche à suivre : ${plain}`);
console.log(JSON.stringify({ passed: true, scenesAvantTouche: approaches, dontSortieAvantAvantage: viaAdvantage, scenesSansTouche: plain, avantsVerifies: forwards, resteLePlusLong: +longest.toFixed(1) }));
