'use strict';
// Courriers du mercato (docs/gdd/calendrier-mutations.md § 3 ter ; native/engine/club-mail.cjs + club-mail.json) :
//   - « Échos du mercato » hors période des mutations : routine, liste courte (6 lignes puis « et N autres »), une fois par
//     semaine et seulement s'il y a du neuf ;
//   - « Point mercato » pendant la période : un seul courrier d'information qui regroupe les offres reçues (aucun courrier
//     « offre_transfert » individuel pendant la période), les accords du club et les trois plus gros accords du Monde ;
//   - « Ouverture du mercato » et « Dernière semaine du mercato » : une fois par saison ;
//   - après la période, une offre déjà annoncée n'est pas redonnée seule ; une offre nouvelle l'est ;
//   - rejeu identique sur une copie de la carrière.
// Carrière Monde (`world-champ`, club 102). L'état du mercato (S.calendrierMutations.mercato, offres, accords) est posé
// directement : le test ne dépend pas du moteur qui l'écrit (calendrier-mutations.cjs).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const DATA = require('../native/engine/club-mail.json');
const M = require('./helpers/carriere-monde.cjs');

const TYPES = ['echos_mercato', 'point_mercato', 'mercato_ouverture', 'mercato_derniere'];

test('Données : quatre courriers du mercato, natures et catégorie', () => {
  for (const k of TYPES) {
    const t = DATA.types[k];
    assert.ok(t && t.declencheur === k && t.categorie === 'transferts' && DATA.categories[t.categorie], k);
    assert.ok(t.formulations.length >= 2 && t.liste === true, k + ' : formulations en liste');
    for (const f of t.formulations) assert.doesNotMatch(f.sujet + f.corps, /imm[ée]diat|effectif le 1er mai/i, k);
  }
  assert.equal(DATA.types.echos_mercato.nature, 'routine');
  for (const k of ['point_mercato', 'mercato_ouverture', 'mercato_derniere']) assert.equal(DATA.types[k].nature, 'info', k);
  for (const k of ['point_mercato', 'mercato_ouverture', 'mercato_derniere']) assert.equal(DATA.types[k].ecran, 'ventes', k + ' : lien « Offres reçues »');
  assert.ok(DATA.types.mercato_ouverture.priorite < DATA.types.point_mercato.priorite, 'temps forts en priorité haute');
});

// Étapes du scénario : date, semaine du Monde, état posé avant la réception (X = carrière visée).
const ETAPES = [
  { nom: 'echos', d: '2027-02-10', wk: 30, pose: `const cm=X.calendrierMutations&&typeof X.calendrierMutations==='object'?X.calendrierMutations:(X.calendrierMutations={version:1,seq:0,supplementaires:{saison:X.season,ids:[]},preContrats:[]});
      cm.mercato={saison:X.season,ouverture:null,derniere:null,semaines:{30:[{type:'precontrat',texte:'Bordeaux a signé Jean Dupont, talonneur de Dax, pour la saison prochaine',montant:0},
        ...[1,2,3,4,5,6,7].map(i=>({type:'rumeur',texte:'Rumeur numéro '+i+' : un club suit un joueur en fin de contrat',montant:0}))]}};` },
  { nom: 'echos-rejeu', d: '2027-02-11', wk: 30, pose: '' },
  { nom: 'echos-suivant', d: '2027-02-17', wk: 31, pose: `X.calendrierMutations.mercato.semaines[31]=[{type:'accord',texte:'Toulon s’est mis d’accord avec Pau pour Paul Martin (ailier) : il arrivera le 1er juillet',montant:900000}];` },
  { nom: 'hors-periode', d: '2027-03-03', wk: 33, pose: `X.economy.offers=OFFRES(X,'mars',2);` },
  { nom: 'ouverture', d: '2027-05-03', wk: 40, pose: `X.economy.offers=[];X.venteJoueurs={version:1,seq:1,accords:[{id:'accord-1',clubId:X.club,playerId:X.clubs[X.club].players[5].id,joueur:X.clubs[X.club].players[5].name,buyer:AUTRES(X)[0],acheteur:'',fee:750000,date:'2027-07-01',conclu:'2027-03-01'}],evenements:[]};` },
  { nom: 'point', d: '2027-05-12', wk: 41, pose: `X.economy.offers=OFFRES(X,'mai',3);X.calendrierMutations.mercato.semaines[41]=[1,2,3,4,5].map(i=>({type:'achat',texte:'Accord numéro '+i+' pour '+(i*100000)+' €',montant:i*100000}));` },
  { nom: 'point-rejeu', d: '2027-05-13', wk: 41, pose: '' },
  { nom: 'point-vide', d: '2027-05-19', wk: 42, pose: '' },
  { nom: 'derniere', d: '2027-06-25', wk: 48, pose: '' },
  { nom: 'derniere-rejeu', d: '2027-06-26', wk: 48, pose: '' },
  { nom: 'apres', d: '2027-07-05', wk: 49, pose: `X.economy.offers.push(...OFFRES(X,'juillet',1));` },
];
const OUTILS = `const AUTRES=X=>X.clubs.filter(c=>c&&c.id!==X.club).slice(0,4).map(c=>c.id);
  const OFFRES=(X,nom,n)=>Array.from({length:n},(_,i)=>({id:'offre-'+nom+'-'+i,playerId:X.clubs[X.club].players[10+i].id,buyer:AUTRES(X)[i%4],fee:400000+i*50000,expires:X.economy.week+20}));`;

function scenario(vm, cible) {
  const recus = {};
  for (const e of ETAPES) {
    const veille = new Date(Date.parse(e.d + 'T00:00:00Z') - 86400000).toISOString().slice(0, 10);
    recus[e.nom] = JSON.parse(vm.run(`(()=>{const X=${cible};${OUTILS}X.worldMode.week=${e.wk};${e.pose}
      X.clubMail.last='${veille}';const n=X.clubMail.mails.length;nativeSystems.domain('clubMail').recevoir(X,'${e.d}');
      return JSON.stringify(X.clubMail.mails.slice(n).map(m=>({id:m.id,type:m.type,date:m.date,f:m.f,vars:m.vars,status:m.status})));})()`));
  }
  return recus;
}

test('Carrière Monde : échos en routine, point mercato regroupé, temps forts une fois, rejeu identique', { timeout: 600000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-courrier-mercato-'));
  const jeu = M.ouvrir({ dataDir: dir, deferredCommits: true, testVm: true, mandatoryPress: false, journal: true, savePolicy: 'semaine' });
  try {
    jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    const vm = jeu.bridge.vm;
    // Plafond du jour relevé le temps du test : les autres courriers du club (temps de jeu, agent…) ne prennent pas la place
    // des courriers vérifiés ici (en jeu, un courrier repoussé sort un jour suivant de la même semaine).
    vm.run(`(()=>{nativeClubMailData.cadence.maxParJour=12;if(typeof setupEconomy==='function')setupEconomy();if(!S.clubMail||S.clubMail.last===null)nativeSystems.domain('clubMail').recevoir(S,CDWorldCareer.calendarToday(S));globalThis.__copieMercato=JSON.parse(JSON.stringify(S));return 1})()`);
    const R = scenario(vm, 'S');
    const vue = JSON.parse(vm.run(`JSON.stringify(nativeSystems.domain('clubMail').project().mails)`));
    const rendu = id => vue.find(m => m.id === id);
    const deType = (etape, type) => R[etape].filter(m => m.type === type);

    // Échos : routine, liste de 6 lignes puis « et 2 autres », rien de neuf → rien, semaine suivante : le seul fait nouveau.
    const [echo] = deType('echos', 'echos_mercato');
    assert.ok(echo, 'échos du mercato reçus');
    const e = rendu(echo.id);
    assert.equal(e.nature, 'routine'); assert.equal(e.arret, false);
    assert.match(e.corps, /• Bordeaux a signé Jean Dupont, talonneur de Dax, pour la saison prochaine/);
    assert.equal((e.corps.match(/^• /gm) || []).length, 6, e.corps);
    assert.match(e.corps, /\net 2 autres\n/);
    assert.doesNotMatch(e.corps, /\n{3,}/);
    assert.equal(deType('echos-rejeu', 'echos_mercato').length, 0, 'pas deux échos la même semaine');
    const [suivant] = deType('echos-suivant', 'echos_mercato');
    assert.ok(suivant, 'échos de la semaine suivante');
    const s2 = rendu(suivant.id).corps;
    assert.match(s2, /Toulon s’est mis d’accord avec Pau/); assert.doesNotMatch(s2, /Bordeaux|Rumeur/);

    // Hors période : offres en courriers individuels, pas de point mercato.
    assert.equal(deType('hors-periode', 'offre_transfert').length, 2, 'offres individuelles hors période');
    assert.equal(deType('hors-periode', 'point_mercato').length, 0);

    // Ouverture : une fois, avec l'accord déjà conclu.
    const [ouv] = deType('ouverture', 'mercato_ouverture');
    assert.ok(ouv, 'ouverture du mercato');
    const o = rendu(ouv.id);
    assert.equal(o.nature, 'info'); assert.equal(o.ecran, 'ventes');
    assert.match(o.corps, /jusqu’au 30 juin 2027/); assert.match(o.corps, /1er juillet 2027/);
    assert.match(o.corps, /Nos accords déjà conclus[^\n]*\n• [^\n]+ part à [^\n]+ pour 750/);
    for (const k of ['point', 'point-rejeu', 'point-vide', 'derniere', 'derniere-rejeu', 'apres']) assert.equal(deType(k, 'mercato_ouverture').length, 0, 'ouverture une seule fois (' + k + ')');

    // Point mercato : un seul courrier d'information pour trois offres, aucun courrier individuel pendant la période.
    const points = deType('point', 'point_mercato');
    assert.equal(points.length, 1, 'un point mercato');
    for (const k of ['ouverture', 'point', 'point-rejeu', 'point-vide', 'derniere', 'derniere-rejeu']) assert.equal(deType(k, 'offre_transfert').length, 0, 'aucune offre individuelle en période (' + k + ')');
    const p = rendu(points[0].id);
    assert.equal(p.nature, 'info'); assert.equal(p.ecran, 'ventes'); assert.equal(p.arret, false);
    assert.match(p.corps, /Offres reçues pour nos joueurs :/);
    assert.equal((p.corps.match(/ propose [^\n]+ pour /g) || []).length, 3, p.corps);
    assert.match(p.corps, /Accord numéro 5/); assert.match(p.corps, /Accord numéro 4/); assert.match(p.corps, /Accord numéro 3/);
    assert.doesNotMatch(p.corps, /Accord numéro [12] /);
    assert.equal(deType('point-rejeu', 'point_mercato').length, 0, 'un seul point par semaine');
    assert.equal(deType('point-vide', 'point_mercato').length, 0, 'rien de neuf : pas de point');

    // Dernière semaine : une fois, rappel des offres en attente et plus gros accords.
    const [der] = deType('derniere', 'mercato_derniere');
    assert.ok(der, 'dernière semaine du mercato');
    const dc = rendu(der.id).corps;
    assert.match(dc, /se ferme le 30 juin 2027|ferme le 30 juin 2027/);
    assert.match(dc, /Offres encore en attente pour nos joueurs :/);
    // Plus gros accords de la saison (celui de l'hiver compris), déjà annoncés ou non.
    assert.match(dc, /Les plus gros accords du mercato :\n• Toulon s’est mis d’accord[^\n]*\n• Accord numéro 5[^\n]*\n• Accord numéro 4/);
    assert.equal(deType('derniere-rejeu', 'mercato_derniere').length, 0, 'dernière semaine une seule fois');
    assert.equal(deType('derniere', 'point_mercato').length, 0, 'pas de point la dernière semaine');

    // Après la période : les offres déjà annoncées ne reviennent pas seules, la nouvelle oui ; échos de nouveau possibles.
    const apres = deType('apres', 'offre_transfert');
    assert.equal(apres.length, 1, 'seule l’offre nouvelle en courrier individuel');
    assert.match(rendu(apres[0].id).sujet, /./);
    assert.equal(R.apres.filter(m => TYPES.includes(m.type) && m.type !== 'echos_mercato').length, 0);

    // Rejeu sur la copie prise avant le scénario : mêmes courriers.
    const R2 = scenario(vm, 'globalThis.__copieMercato');
    assert.deepEqual(R2, R, 'rejeu identique');
  } finally {
    jeu.fermer?.();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
