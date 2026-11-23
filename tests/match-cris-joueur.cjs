'use strict';
// Cris du banc à un joueur et « Permuter les ailes » (idée FM27 n° 34, choix de Léo du 23/11/2026) en carrière Monde :
// - un cri individuel (Bien joué, Hausse le niveau, Réveille-toi) agit vraiment, avec du hasard : bien ou mal pris,
//   réaction découverte après coup seulement (sens ▲ / ▼), usure si on interpelle trop le même joueur ou trop souvent ;
// - permuter les ailes passe par la file du prochain arrêt de jeu (native/engine/match-arrets.cjs) : nos ailiers n° 11
//   et 14 échangent leurs côtés, une seconde demande avant l'arrêt s'annule, une seconde après l'arrêt les remet ;
// - mesures sur des lots de matchs depuis le coup d'envoi (mêmes graines, banc adverse figé) : les cris individuels ne
//   déséquilibrent pas le jeu (écart de victoires négligeable, même en criant sans arrêt), la permutation suit les duels.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
const vm = jeu.bridge.vm;
const J = code => JSON.parse(vm.run(`JSON.stringify((()=>{${code}})())`, 1200000));
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  const scene = m.clubLife?.matchTalks?.scene;
  if (scene) m = jeu.call('match_talk_continue', { key: scene.key, phase: scene.phase, skip: true });
  vm.run('globalThis.__depart=JSON.stringify(S.live);');
  const ind = m.live.pilotage.cris.individuels;
  assert.deepEqual(ind.options.map(o => o.id), ['bravo', 'niveau', 'reveil'], 'trois cris à un joueur');
  assert.deepEqual(ind.joueurs, {}, 'aucun cri au coup d’envoi');

  // --- Cris à un joueur : refus, réaction après coup, usure ---
  m = jeu.call('tick', { steps: 3 });
  const on = J('return S.live.sheets[S.live.userSide].on');
  assert.equal(jeu.brut('cri', { id: 'hurler', joueur: on[0] }).ok, false, 'cri inconnu refusé');
  assert.equal(jeu.brut('cri', { id: 'bravo', joueur: 'personne' }).ok, false, 'joueur absent refusé');
  assert.equal(jeu.brut('cri', { id: 'bravo', joueur: 12 }).ok, false, 'identifiant invalide refusé');
  let r = jeu.brut('cri', { id: 'niveau', joueur: on[9] });
  assert.equal(r.ok, true, r.error);
  assert.ok([1, -1].includes(r.model.meta.criJoueur.sens), 'premier cri : bien ou mal pris');
  const vu = r.model.live.pilotage.cris.individuels.joueurs[on[9]];
  assert.equal(vu.cri, 'niveau');
  assert.equal(vu.sens, r.model.meta.criJoueur.sens, 'réaction projetée après coup');
  assert.ok(vu.enCours);
  assert.deepEqual(Object.keys(vu).sort(), ['cri', 'enCours', 'label', 'minute', 'sens'], 'aucun chiffre d’effet projeté');
  const mod = J(`const l=S.live,p=activePlayers(l,l.userSide).find(x=>x.id===${JSON.stringify(on[9])});return criJoueurMod(l,p,'pass')`);
  assert.ok(vu.sens > 0 ? mod > 0 : mod < 0, 'le cri agit sur le joueur : ' + mod);
  jeu.call('cri', { id: 'bravo', joueur: on[9] });
  r = jeu.call('cri', { id: 'reveil', joueur: on[9] });
  assert.equal(r.live.pilotage.cris.individuels.joueurs[on[9]].sens, 0, 'troisième cri au même joueur : il n’écoute plus');
  // Le banc s'use : six cris en quelques minutes, le suivant ne porte plus.
  for (const s of [1, 2, 3]) jeu.call('cri', { id: 'bravo', joueur: on[s] });
  r = jeu.call('cri', { id: 'bravo', joueur: on[4] });
  assert.equal(r.live.pilotage.cris.individuels.joueurs[on[4]].sens, 0, 'le banc qui crie sans arrêt n’est plus écouté');
  // Copie de sauvegarde : les cris individuels se relisent.
  assert.equal(J('const t=JSON.parse(JSON.stringify(S));validateCareer(t);return Object.keys(t.live.pilotage.crisJoueurs).length>0'), true);

  // --- Permuter les ailes : file du prochain arrêt de jeu ---
  const [g, d] = [on[10], on[13]];
  r = jeu.call('file_arret', { action: 'ajouter', change: { type: 'ailes' } });
  const fa = r.meta.fileArret;
  if (fa.enAttente) {
    assert.ok(r.live.pilotage.arrets.ailes.attente, 'permutation en attente du prochain arrêt');
    r = jeu.call('file_arret', { action: 'ajouter', change: { type: 'ailes' } });
    assert.ok(r.meta.fileArret.annule && !r.live.pilotage.arrets.ailes.attente, 'seconde demande avant l’arrêt : annulée');
    r = jeu.call('file_arret', { action: 'ajouter', change: { type: 'ailes' } });
    for (let i = 0; i < 40 && r.live.pilotage.arrets.ailes.attente; i++) r = jeu.call('tick');
  }
  let ailes = J('const sh=S.live.sheets[S.live.userSide];return [sh.on[10],sh.on[13]]');
  assert.deepEqual(ailes, [d, g], 'les deux ailiers ont échangé leurs côtés');
  assert.equal(r.live.pilotage.arrets.ailes.permutees, true);
  assert.ok(r.live.pilotage.arrets.appliques.some(x => x.type === 'ailes' && x.ok && /^Ailes permutées : /.test(x.texte)), 'journal des arrêts');
  assert.equal(J('const t=JSON.parse(JSON.stringify(S));validateCareer(t);return t.live.pilotage.ailes.ids.length'), 2, 'sauvegarde relue');
  r = jeu.call('file_arret', { action: 'ajouter', change: { type: 'ailes' } });
  for (let i = 0; i < 40 && r.live.pilotage.arrets.ailes.attente; i++) r = jeu.call('tick');
  ailes = J('const sh=S.live.sheets[S.live.userSide];return [sh.on[10],sh.on[13]]');
  assert.deepEqual(ailes, [g, d], 'redemandée : chacun reprend son côté');
  assert.equal(r.live.pilotage.arrets.ailes.permutees, false);

  // --- Mesures : lots de matchs depuis le coup d'envoi, mêmes graines, banc adverse figé ---
  // Match rendu serré (« ligue » d'adversaires de même niveau) : nos joueurs perdent `H` points de niveau, l'issue n'est
  // plus jouée d'avance et la moindre différence de victoires se voit.
  const seed = 'Math.random=(()=>{let x=(i*7919+17)>>>0;return()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}})();';
  // `avant` : réglage posé au coup d'envoi ; `pendant` : joué avant chaque minute du moteur (l, u, o, sh, i).
  const mesurer = ({ avant = '', pendant = '', H = 0 }, n) => J(`const acc={victoires:0,ecart:0,metres:0,cris:0,matchs:0};
    for(let i=0;i<${n};i++){S.live=JSON.parse(__depart);const l=S.live;delete l.pilotage.consignesAdverses;delete l.pilotage.adversaire;
     const u=l.userSide,o=1-u,sh=l.sheets[u],tous=[...S.clubs[l.pair[u]].players,...S.clubs[l.pair[o]].players];
     const snap=tous.map(p=>[p,p.condition,p.rating,{...p.skills}]);
     for(const p of S.clubs[l.pair[u]].players)p.rating-=${H};
     ${avant}${seed}let k=0;while(!l.finished&&k++<400){l.paused=false;${pendant}advanceRugby(l)}
     acc.victoires+=l.score[u]>l.score[o]?1:l.score[u]===l.score[o]?.5:0;acc.ecart+=l.score[u]-l.score[o];acc.metres+=l.tacticalStats?.[u]?.metres||0;
     acc.cris+=(l.pilotage.crisJoueursLog||[]).length;
     for(const [p,c,r,s] of snap){p.condition=c;p.rating=r;p.skills=s}acc.matchs++}
    for(const k of Object.keys(acc))if(k!=='matchs')acc[k]/=acc.matchs;return acc`);
  const H = Number(process.env.CD_CRIS_HANDICAP || 2), N = 300;
  const base = mesurer({ H }, N);
  // Manager attentif : toutes les 5 minutes, le bon mot au bon joueur (moral le plus bas : « Bien joué » ; un relâché :
  // « Réveille-toi » ; sinon « Hausse le niveau » au plus confiant).
  const attentif = `if(l.minute>0&&Math.floor(l.minute)%5===0&&l.__cri!==Math.floor(l.minute)){l.__cri=Math.floor(l.minute);
    const js=activePlayers(l,u),M=l.pilotage.moral?.joueurs||{},v=p=>M[p.id]?.v??50;
    const rel=js.find(p=>['relache','indifferent'].includes(l.pilotage.etats?.[p.id]?.etat)&&!(l.pilotage.crisJoueursLog||[]).some(x=>x.id===p.id));
    if(rel)crierJoueur(l,rel.id,'reveil');else{const bas=js.reduce((a,p)=>v(p)<v(a)?p:a,js[0]),haut=js.reduce((a,p)=>v(p)>v(a)?p:a,js[0]);
     crierJoueur(l,v(bas)<48?bas.id:haut.id,v(bas)<48?'bravo':'niveau')}}`;
  // Banc qui crie sans arrêt : toutes les 2 minutes, un cri au hasard à un joueur au hasard (tirage hors du flux du match).
  const bavard = `if(l.minute>0&&Math.floor(l.minute)%2===0&&l.__cri!==Math.floor(l.minute)){l.__cri=Math.floor(l.minute);
    const js=activePlayers(l,u),h=pilotageHash('bavard|'+i+'|'+l.minute);crierJoueur(l,js[h%js.length].id,['bravo','niveau','reveil'][(h>>>8)%3])}`;
  const sage = mesurer({ H, pendant: attentif }, N), fou = mesurer({ H, pendant: bavard }, N);
  // Permutation des ailes : notre n° 11 rapide, notre n° 14 lent ; leur n° 14 (même touche que notre 11) rapide et bon
  // plaqueur, leur n° 11 lent. Permutés, notre rapide affronte leur lent, mais leur rapide trouve notre lent en défense.
  const poser = `const P=(s,slot,vitesse,plaquage)=>{const p=matchPlayer(l,s,l.sheets[s].on[slot]);ensureSkills(p);p.skills.speed+=vitesse-skill(p,'speed');p.skills.tackle+=plaquage-skill(p,'tackle')};
    P(u,10,90,62);P(u,13,66,62);P(o,13,90,72);P(o,10,62,58);`;
  const permuter = 'const a=sh.on[10];sh.on[10]=sh.on[13];sh.on[13]=a;l.pilotage.ailes={ids:[sh.on[10],sh.on[13]],minute:0};';
  const sonde = J(`S.live=JSON.parse(__depart);const l=S.live,u=l.userSide,o=1-u,sh=l.sheets[u],tous=[...S.clubs[l.pair[u]].players,...S.clubs[l.pair[o]].players],snap=tous.map(p=>[p,{...p.skills}]);
    ${poser}${permuter}const e=CDMatchArrets.effets.edge(l,u),d=CDMatchArrets.effets.edge(l,o);for(const [p,s] of snap)p.skills=s;S.live=JSON.parse(__depart);return {e,d}`);
  const NA = 300;
  const ailesBase = mesurer({ H, avant: poser }, NA), ailesPerm = mesurer({ H, avant: poser + permuter }, NA);
  const pc = x => Math.round(x * 1000) / 10, r2 = x => Math.round(x * 100) / 100;
  console.log(`victoires sur ${N} matchs serrés (niveau −${H}) : sans cri individuel ${pc(base.victoires)} % (écart ${r2(base.ecart)}) · manager attentif ${pc(sage.victoires)} % (écart ${r2(sage.ecart)}, ${r2(sage.cris)} cris) · banc bavard ${pc(fou.victoires)} % (écart ${r2(fou.ecart)}, ${r2(fou.cris)} cris)`);
  console.log(`ailes permutées (réussite en attaque ${r2(sonde.e * 100)} pts, en défense ${r2(sonde.d * 100)} pts au coup d'envoi), ${NA} matchs : écart ${r2(ailesBase.ecart)} → ${r2(ailesPerm.ecart)} · mètres ${r2(ailesBase.metres)} → ${r2(ailesPerm.metres)} · victoires ${pc(ailesBase.victoires)} % → ${pc(ailesPerm.victoires)} %`);
  assert.ok(base.victoires > .2 && base.victoires < .8, 'matchs serrés : ' + pc(base.victoires) + ' %');
  // Négligeable : moins de 4 points de pourcentage de victoires et 2 points d'écart moyen, même pour le banc bavard.
  for (const [nom, x] of [['attentif', sage], ['bavard', fou]]) {
    assert.ok(Math.abs(x.victoires - base.victoires) < .04, `cris individuels (${nom}) : victoires ${pc(base.victoires)} → ${pc(x.victoires)} %`);
    assert.ok(Math.abs(x.ecart - base.ecart) < 2, `cris individuels (${nom}) : écart ${r2(base.ecart)} → ${r2(x.ecart)}`);
  }
  assert.ok(sage.cris > 10 && fou.cris > 20, 'les cris ont bien été poussés');
  assert.ok(sonde.e > 0 && sonde.d > 0, 'permutation : gain en attaque, prix à payer en défense');
  assert.ok(ailesPerm.ecart > ailesBase.ecart, 'notre ailier rapide face à leur ailier lent : ça rapporte');
  assert.ok(ailesPerm.ecart - ailesBase.ecart < 6, 'effet modéré');
  console.log('Cris à un joueur et permutation des ailes PASS');
} finally { jeu.fermer?.(); }
process.exit(0);
