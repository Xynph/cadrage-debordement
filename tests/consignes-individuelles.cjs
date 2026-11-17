'use strict';
// Consignes individuelles (buteur, buteur de secours, lanceur en touche, jeu au pied d'occupation) en carrière
// Monde (world-champ, club 102) : commande et projection, délégation au staff identique au calcul d'avant,
// effets sur la réussite au pied, la touche et la longueur du jeu au pied, aucun tirage, déterminisme,
// compatibilité des rencontres commencées avant. Conception : docs/consignes-individuelles-20261116.md.
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);
const roles = h => h.command('snapshot').tactics.roles;
// Rendez-vous du club coupés (comme le harnais) : ils bloqueraient les commandes de gestion.
const tactic = (h, extra) => (h.run('delete S.clubMeetings'), h.command('set_tactics', {attack: h.run('S.tactic'), defense: h.run("S.defence||'equilibre'"), ...extra}));

// Affiches IA contre IA de la semaine (hors club du manager), jouées à graine fixe, conditions rétablies
// après chaque match (les joueurs ne sortent pas fatigués d'un match de mesure).
const SIMULER = `var simuler=(n,choix,seedBase=1)=>{const fx=CDWorldCareer.fixtures(S).filter(f=>f.homeId!==S.club&&f.awayId!==S.club),rng=Math.random,acc={tentatives:0,reussis:0,transfos:0,transfosReussies:0,touches:0,touchesGagnees:0,points:0,matchs:0,signature:[]};
 try{for(let k=0;k<n;k++){const f=fx[k%fx.length];let x=(k*2654435761+seedBase)>>>0;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
  for(const id of [f.homeId,f.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);
  const snap=[f.homeId,f.awayId].flatMap(id=>S.clubs[id].players.map(p=>[p,p.condition,p.injury]));
  const l=createRugbyMatch([f.homeId,f.awayId],null,true);if(choix)l.playerRoles[0]=choix(l);
  for(let g=0;!l.finished&&g<600;g++){l.paused=false;advanceRugby(l)}for(const [p,c,i] of snap){p.condition=c;p.injury=i}
  const st=l.stats[0];acc.tentatives+=st.goalAttempts;acc.reussis+=st.goals;acc.transfos+=st.conversionAttempts;acc.transfosReussies+=st.conversions;acc.touches+=st.lineouts;acc.touchesGagnees+=st.lineoutsWon;acc.points+=l.score[0];acc.matchs++;
  acc.signature.push(l.score.join('-')+':'+l.events.length)}}finally{Math.random=rng}
 return acc};
 var faible=(l,k,exclure)=>[...activePlayers(l,0)].filter(p=>p.fam>=4&&p.id!==exclure).sort((a,b)=>skill(a,k,true)-skill(b,k,true)||String(a.id).localeCompare(String(b.id)))[0];`;

test('Commande set_tactics : désignation, retour au staff, refus et sauvegarde', () => {
  const h = setup();
  let view = roles(h);
  assert.deepEqual(view.roles.map(r => r.id), ['buteur', 'secours', 'lanceur', 'pied']);
  assert.equal(view.editable, true);
  for (const r of view.roles) {
    assert.equal(r.chosen, null, `${r.id} : choix du staff par défaut`);
    assert.ok(r.staff && r.staff.id, `${r.id} : le staff propose un joueur`);
    assert.equal(r.candidates.length, 15, 'candidats : le XV de départ');
  }
  const buteur = view.roles[0];
  // Jugement du staff (docs/jugement-staff-20261116.md) : le staff choisit celui qu'il juge le meilleur, au plus
  // à quelques points du meilleur réel.
  assert.ok(buteur.candidates.some(p => p.id === buteur.staff.id) && buteur.candidates[0].value - buteur.staff.value <= 10, 'le staff choisit un des meilleurs buteurs du XV');
  assert.equal(view.roles[2].staff.pos, 'Talonneur', 'le talonneur lance en touche');
  assert.equal(view.alerte, null);
  // Désigner le moins bon buteur du XV : alerte (Gabi la relaie à l'écran Composition).
  const pire = buteur.candidates.at(-1);
  view = tactic(h, {roles: {buteur: pire.id, secours: buteur.staff.id}}).tactics.roles;
  assert.equal(view.roles[0].chosen.id, pire.id);
  assert.equal(view.roles[1].chosen.id, buteur.staff.id);
  assert.equal(view.alerte?.playerId, pire.id);
  assert.ok(view.alerte.staffValue - view.alerte.value >= 8);
  h.run('validateCareer(S)');
  assert.equal(h.run('!!createSaveDocument()'), true, 'sauvegarde valide');
  // Rendre le rôle au staff.
  view = tactic(h, {roles: {buteur: null, secours: null}}).tactics.roles;
  assert.equal(view.roles[0].chosen, null);
  assert.equal(h.run('S.playerRoles===undefined'), true, 'aucune désignation : rien n’est stocké');
  // Refus : rôle inconnu, joueur d'un autre club ; l'état reste celui d'avant.
  assert.throws(() => tactic(h, {roles: {capitaine: pire.id}}), /Rôle inconnu/);
  const autre = h.run('CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club).homeId');
  assert.throws(() => tactic(h, {roles: {buteur: h.run(`S.clubs[${autre}].players[0].id`)}}), /joueur absent/);
  assert.equal(h.run('S.playerRoles===undefined'), true);
  // Le même joueur ne peut être buteur et buteur de secours.
  view = tactic(h, {roles: {buteur: pire.id, secours: pire.id}}).tactics.roles;
  assert.equal(view.roles[1].chosen, null);
  // Sauvegarde : rôle inconnu refusé.
  assert.throws(() => h.run('S.playerRoles={capitaine:"x"};validateCareer(S)'));
});

test('Coup d’envoi : les désignations du manager sont copiées, l’IA garde le choix du staff', () => {
  const h = setup();
  const view = roles(h), pire = view.roles[0].candidates.at(-1);
  tactic(h, {roles: {buteur: pire.id, lanceur: view.roles[2].candidates.at(-1).id}});
  h.run('var pair=nextMatch();var l=createRugbyMatch(pair,null,false);var moi=l.pair.indexOf(S.club)');
  assert.equal(h.run('l.playerRolesVersion'), 1);
  assert.equal(h.run('l.playerRoles[moi].buteur'), pire.id);
  assert.equal(h.run('Object.keys(l.playerRoles[1-moi]).length'), 0, 'club adverse : délégation au staff');
  assert.equal(h.run('goalKicker(l,moi).id'), pire.id);
  assert.equal(h.run('goalKicker(l,1-moi).id===staffRolePlayer(l,1-moi,"buteur").id'), true);
  assert.ok(h.run('lineoutThrowEdge(l,moi)') < 0, 'lanceur désigné moins précis que le talonneur');
  assert.equal(h.run('lineoutThrowEdge(l,1-moi)'), 0);
  // Changement après le coup d'envoi : refusé.
  h.run('S.live=l');
  assert.throws(() => tactic(h, {roles: {buteur: null}}), /avant le coup d’envoi/);
  h.run('S.live=null');
  // Rencontre commencée avant les consignes individuelles : règles d'origine.
  h.run('delete l.playerRolesVersion;delete l.staffJudgementVersion');
  assert.equal(h.run('goalKicker(l,moi).id===chooseScorer(S.clubs[l.pair[moi]],activePlayers(l,moi).map(p=>p.id)).id'), true);
  assert.equal(h.run('lineoutThrowEdge(l,moi)'), 0);
  // Option coupée : la rencontre ne connaît pas les rôles.
  h.run('PLAYER_ROLES_RULES=0;var l0=createRugbyMatch(pair,null,false);PLAYER_ROLES_RULES=1');
  assert.equal(h.run('l0.playerRolesVersion===undefined&&l0.playerRoles===undefined'), true);
});

test('Buteur de secours : il prend les tirs quand le buteur désigné n’est plus sur le terrain', () => {
  const h = setup();
  h.run(SIMULER);
  h.run(`var f=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);var l=createRugbyMatch([f.homeId,f.awayId],null,true);
    var on=activePlayers(l,0),a=faible(l,'goal'),b=faible(l,'goal',a.id);l.playerRoles[0]={buteur:a.id,secours:b.id}`);
  assert.equal(h.run('goalKicker(l,0).id===a.id'), true);
  h.run('var slot=l.sheets[0].on.indexOf(a.id);l.sheets[0].on[slot]=l.sheets[0].bench[0]');
  assert.equal(h.run('goalKicker(l,0).id===b.id'), true, 'le buteur de secours tire');
  h.run('l.sheets[0].on[l.sheets[0].on.indexOf(b.id)]=l.sheets[0].bench[1]');
  assert.equal(h.run('goalKicker(l,0).id===staffRolePlayer(l,0,"buteur").id'), true, 'puis le choix du staff');
});

test('Effets sans tirage : réussite au pied, touche et longueur du jeu au pied suivent le joueur choisi', () => {
  const h = setup();
  h.run(SIMULER);
  h.run(`var f=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);var l=createRugbyMatch([f.homeId,f.awayId],null,true);
    var tirages=0,alea=Math.random;Math.random=function(){tirages++;return alea()};l.territory=70;l.possession=0`);
  const staff = h.run('goalChance(l,0)'), staffTransfo = h.run('goalChance(l,0,true,20)');
  h.run('l.playerRoles[0]={buteur:faible(l,"goal").id}');
  assert.ok(h.run('goalChance(l,0)') < staff - .05, 'pénalité : buteur faible nettement moins adroit');
  assert.ok(h.run('goalChance(l,0,true,20)') < staffTransfo - .05, 'transformation aussi');
  h.run('l.playerRoles[0]={lanceur:activePlayers(l,0).find(p=>p.fam===2).id}');
  const deuxiemeLigne = h.run('lineoutThrowEdge(l,0)');
  h.run('l.playerRoles[0]={lanceur:activePlayers(l,0).find(p=>p.fam===6).id}');
  const ailier = h.run('lineoutThrowEdge(l,0)');
  assert.ok(deuxiemeLigne < 0 && ailier < deuxiemeLigne, `touche : deuxième ligne ${deuxiemeLigne}, ailier ${ailier}`);
  h.run('l.playerRoles[0]={pied:faible(l,"kick",staffRolePlayer(l,0,"pied").id).id}');
  assert.ok(h.run('occupationKickEdge(l,0)') < -2, 'jeu au pied plus court avec un botteur moyen');
  assert.equal(h.run('occupationKicker(l,0).id===l.playerRoles[0].pied'), true, 'le botteur désigné est nommé');
  h.run('l.playerRoles[0]={buteur:staffRolePlayer(l,0,"buteur").id,lanceur:staffRolePlayer(l,0,"lanceur").id,pied:staffRolePlayer(l,0,"pied").id}');
  assert.equal(h.run('goalChance(l,0)'), staff, 'désigner le choix du staff ne change rien');
  // Avec le jugement du staff, le staff peut mal classer ses botteurs : l'écart au meilleur réel existe déjà sans
  // désignation (« jamais de gain sur le meilleur réel »). Désigner son choix ne doit donc rien changer à cet écart.
  const ecartStaff = h.run('l.playerRoles[0]={};lineoutThrowEdge(l,0)+occupationKickEdge(l,0)');
  h.run('l.playerRoles[0]={buteur:staffRolePlayer(l,0,"buteur").id,lanceur:staffRolePlayer(l,0,"lanceur").id,pied:staffRolePlayer(l,0,"pied").id}');
  assert.equal(h.run('lineoutThrowEdge(l,0)'), 0, 'lanceur du staff désigné : aucun écart');
  assert.equal(h.run('lineoutThrowEdge(l,0)+occupationKickEdge(l,0)'), ecartStaff, 'botteur du staff désigné : même écart que sans désignation');
  h.run('tirages=0;for(let i=0;i<20;i++){goalKicker(l,0);goalChance(l,0);lineoutThrowEdge(l,0);occupationKickEdge(l,0);occupationKicker(l,0);staffRolePlayer(l,0,"pied")}');
  assert.equal(h.run('tirages'), 0, 'aucun tirage consommé');
  h.run('Math.random=alea');
});

test('Délégation identique au calcul d’avant, déterminisme et stats IA contre IA', () => {
  const h = setup();
  h.run(SIMULER);
  const N = 42;
  h.run(`simuler(${N})`); // premières feuilles de l'IA composées (ensureAISheet) : état stable ensuite
  const staff = h.run(`JSON.stringify(simuler(${N}))`);
  assert.equal(h.run(`JSON.stringify(simuler(${N}))`), staff, 'même graine : même résultat');
  h.run('PLAYER_ROLES_RULES=0');
  const avant = h.run(`JSON.stringify(simuler(${N}))`);
  h.run('PLAYER_ROLES_RULES=1');
  assert.equal(avant, staff, 'sans désignation, les matchs sont ceux d’avant (scores, faits, statistiques)');
  const s = JSON.parse(staff);
  const buteur = h.run(`JSON.stringify(simuler(${N},l=>({buteur:faible(l,'goal',staffRolePlayer(l,0,'buteur').id).id})))`);
  const b = JSON.parse(buteur);
  const pct = (a, n) => a / n;
  assert.ok(pct(b.reussis + b.transfosReussies, b.tentatives + b.transfos) < pct(s.reussis + s.transfosReussies, s.tentatives + s.transfos) - .05,
    `buteur faible : ${b.reussis + b.transfosReussies}/${b.tentatives + b.transfos} contre ${s.reussis + s.transfosReussies}/${s.tentatives + s.transfos}`);
  const lanceur = JSON.parse(h.run(`JSON.stringify(simuler(${N},l=>({lanceur:(activePlayers(l,0).find(p=>p.fam===6)||activePlayers(l,0).find(p=>p.fam>=6)).id})))`));
  assert.ok(pct(lanceur.touchesGagnees, lanceur.touches) < pct(s.touchesGagnees, s.touches) - .05,
    `ailier au lancer : ${lanceur.touchesGagnees}/${lanceur.touches} contre ${s.touchesGagnees}/${s.touches}`);
  // Valeurs crédibles avec le choix du staff (élite : environ 70-80 % au pied, 80-90 % de touches conservées).
  assert.ok(pct(s.reussis + s.transfosReussies, s.tentatives + s.transfos) > .6);
  assert.ok(pct(s.touchesGagnees, s.touches) > .6);
});
