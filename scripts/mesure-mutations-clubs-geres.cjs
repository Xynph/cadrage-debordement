'use strict';
// Mesure multi-saisons des clubs GÉRÉS par l'ordinateur (tous sauf le club joué) en carrière Monde, cadence hebdomadaire,
// pour comparer AVANT / APRÈS le chantier « clubs gérés au même calendrier des mutations » (docs/gdd/calendrier-mutations.md § 3 bis-3 quater).
// Graine fixe (helper : 4242) : résultat reproductible. N'utilise que l'API publique du worker et des lectures tolérantes de S.
// Les variables d'environnement lues par le moteur (CD_CLUBS_GERES_CALENDRIER=semaines|mutations, CD_PLANCHER_CLUBS_GERES=0)
// sont simplement recopiées dans le rapport.
// Usage : node scripts/mesure-mutations-clubs-geres.cjs [--saisons 3] [--sortie fichier.json]
//   JSON sur stdout (ou dans --sortie), résumé lisible en français sur stderr.
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 600000) });
const fs = require('node:fs'), path = require('node:path');
const { ouvrir, jouerLeMatch } = require('../tests/helpers/carriere-monde.cjs');

const args = process.argv.slice(2);
const opt = (nom, defaut) => { const i = args.indexOf(nom); return i >= 0 && args[i + 1] !== undefined ? args[i + 1] : defaut; };
const SAISONS = Number(opt('--saisons', 3)), SORTIE = opt('--sortie', null);
const CLUB = 102, SEMAINE_AUTOMNE = 14, SEMAINE_FIN = 45;
const t0 = Date.now();
const log = (...x) => process.stderr.write(x.join(' ') + '\n');

const jeu = ouvrir({ testVm: true, hebdomadaire: true });
const run = src => jeu.bridge.vm.run(src);
let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: CLUB, start: 'premiers-clubs', varyCurrent: true }));

// Relevé instantané des clubs gérés, calculé dans la VM (lectures tolérantes).
const INSTANT = `(()=>{
 const med=v=>{const s=v.slice().sort((a,b)=>a-b);return s.length?s[s.length>>1]:null;};
 const sd=v=>{if(v.length<2)return null;const m=v.reduce((a,b)=>a+b,0)/v.length;return Math.sqrt(v.reduce((a,b)=>a+(b-m)**2,0)/v.length);};
 const r1=x=>x==null?null:Math.round(x*10)/10;
 const leagues=S.worldMode?.leagues||{};
 const ligueDe=id=>{for(const [k,l] of Object.entries(leagues))if(Array.isArray(l.members)&&l.members.includes(id))return k;return 'autre';};
 const aNote=typeof roleNote==='function', aLim=typeof aiRosterWageLimit==='function';
 let notesEchecs=0;
 const note=p=>{if(aNote){try{const n=roleNote(p);if(Number.isFinite(n))return n;}catch(e){notesEchecs++;}}return p.rating;};
 const groupes={};
 for(const c of Object.values(S.clubs||{})){ if(!c||c.id===S.club)continue;
  const g=ligueDe(c.id); const L=groupes[g]||(groupes[g]={eff:[],niv:[],cash:[],masse:[],depth:[],plafond:0,mesures:0,dessus:0});
  const ps=c.players||[]; L.eff.push(ps.length);
  const top=ps.map(note).filter(Number.isFinite).sort((a,b)=>b-a).slice(0,23); if(top.length)L.niv.push(top.reduce((a,b)=>a+b,0)/top.length);
  L.cash.push(c.cash||0);
  const masse=ps.reduce((n,p)=>n+(p.salary||0),0); L.masse.push(masse);
  if(aLim){try{const lim=aiRosterWageLimit(c);if(Number.isFinite(lim)){L.mesures++;if(masse>lim)L.dessus++;}}catch(e){}}
  L.depth.push(ps.filter(p=>typeof p.id==='string'&&p.id.startsWith('depth-')).length);
 }
 const resume=L=>({clubs:L.eff.length,
  effectif:{min:Math.min(...L.eff),med:med(L.eff),max:Math.max(...L.eff),sous30:L.eff.filter(n=>n<30).length,sous37:L.eff.filter(n=>n<37).length},
  niveau:{med:r1(med(L.niv)),ecartType:r1(sd(L.niv))},
  caisse:{med:med(L.cash),negatifs:L.cash.filter(x=>x<0).length},
  masseHebdo:{med:med(L.masse),auDessusLimite:aLim?L.dessus:null,limiteMesuree:aLim?L.mesures:null},
  complement:{total:L.depth.reduce((a,b)=>a+b,0),med:med(L.depth),max:Math.max(...L.depth)}});
 const tout={eff:[],niv:[],cash:[],masse:[],depth:[],dessus:0,mesures:0};
 for(const L of Object.values(groupes)){for(const k of ['eff','niv','cash','masse','depth'])tout[k].push(...L[k]);tout.dessus+=L.dessus;tout.mesures+=L.mesures;}
 const own=S.clubs?.[S.club];
 return JSON.stringify({saison:S.season,semaine:S.worldMode?.week,
  parLigue:Object.fromEntries(Object.entries(groupes).map(([k,L])=>[k,resume(L)])),total:tout.eff.length?resume(tout):null,
  clubJoue:own?{effectif:own.players?.length,caisse:own.cash}:null,
  disponibilite:{roleNote:aNote,aiRosterWageLimit:aLim,notesEnEchec:notesEchecs}});
})()`;

// Mouvements lisibles chaque semaine (les fils sont plafonnés, donc dédoublonnés côté Node).
const MOUVEMENTS = `(()=>{
 const own=S.clubs?.[S.club];const mine=new Set((own?.players||[]).map(p=>p.id));
 const ev=(S.aiRoster?.events||[]).filter(e=>e.kind==='sell'&&e.fee>0&&e.clubId!==S.club&&!mine.has(e.playerId)).map(e=>[e.season,e.clubId,e.playerId,e.fee]);
 const tr=(S.economy?.transfers||[]).filter(t=>/ achète /.test(t.text||'')&&!(own&&((t.text||'').startsWith(own.name+' achète')||(t.text||'').includes(' à '+own.name+' pour')))).map(t=>[t.season,t.round,t.text]);
 const ia=S.calendrierMutations?.ia;let preContrats=null;
 if(ia&&typeof ia==='object'){preContrats={};for(const [k,v] of Object.entries(ia))preContrats[k]=Array.isArray(v)?v.length:(typeof v==='number'?v:(v&&typeof v==='object'?Object.keys(v).length:null));}
 const mails=S.clubMail?.mails||S.clubMail?.items||S.clubMail?.inbox||[];
 return JSON.stringify({ev,tr,preContrats,mailIds:mails.map(m=>String(m.id??(m.date+'|'+m.type)))});
})()`;

const med = v => { const s = v.slice().sort((a, b) => a - b); return s.length ? s[s.length >> 1] : null; };
const saisonsReleves = [];
let cour = null, vus = { ev: new Set(), tr: new Set(), mail: new Set() };
const dureeSaison = [];

function nouvelleSaison(n) {
  cour = { saison: n, releves: {}, achatsParSemaine: {}, indemnites: [], achatsTotal: 0, achatsTexte: 0, achatsTexteParSemaine: {}, preContrats: null, courriersParSemaine: {}, relevesManquants: [] };
  vus = { ev: new Set(), tr: new Set(), mail: new Set() };
}
function echantillon(semaine) {
  const m = JSON.parse(run(MOUVEMENTS));
  for (const [s, club, joueur, fee] of m.ev) {
    const k = s + '|' + club + '|' + joueur; if (vus.ev.has(k)) continue; vus.ev.add(k);
    cour.achatsTotal++; cour.indemnites.push(fee); cour.achatsParSemaine[semaine] = (cour.achatsParSemaine[semaine] || 0) + 1;
  }
  for (const [s, r, t] of m.tr) {
    const k = s + '|' + r + '|' + t; if (vus.tr.has(k)) continue; vus.tr.add(k);
    cour.achatsTexte++; cour.achatsTexteParSemaine[semaine] = (cour.achatsTexteParSemaine[semaine] || 0) + 1;
  }
  if (m.preContrats) cour.preContrats = m.preContrats;
  let nouveaux = 0; for (const id of m.mailIds) if (!vus.mail.has(id)) { vus.mail.add(id); nouveaux++; }
  if (nouveaux) cour.courriersParSemaine[semaine] = (cour.courriersParSemaine[semaine] || 0) + nouveaux;
}
function releve(nom) { cour.releves[nom] = JSON.parse(run(INSTANT)); }

for (let saison = 1; saison <= SAISONS; saison++) {
  const debut = Date.now();
  nouvelleSaison(saison);
  const pris = { automne: false, mai: false, fin: false };
  let derniereSemaine = -1;
  for (let garde = 0; garde < 120; garde++) {
    model = jeu.regler(model);
    const semaine = Number(run('S.worldMode.week')), phase = run('S.phase');
    const date = String(model.meta.calendarToday || '');
    if (semaine !== derniereSemaine) { derniereSemaine = semaine; echantillon(semaine); }
    if (!pris.automne && semaine >= SEMAINE_AUTOMNE) { releve('semaine14'); pris.automne = true; }
    if (!pris.mai && /^\d{4}-05-/.test(date) && semaine > SEMAINE_AUTOMNE) { releve('premiereSemaineMai'); cour.semaineMai = semaine; cour.dateMai = date; pris.mai = true; }
    if (!pris.fin && (semaine >= SEMAINE_FIN || phase === 'ended')) { releve('finSaison'); cour.semaineFin = semaine; pris.fin = true; }
    if (phase === 'ended' || run("S.phase==='ended'")) break;
    if (model.next) model = jouerLeMatch(jeu, model); else model = jeu.regler(jeu.call('finish_round'));
  }
  if (!pris.mai) cour.relevesManquants.push('premiereSemaineMai : aucune date de mai atteinte avant la fin de saison');
  if (!pris.fin) { releve('finSaison'); cour.relevesManquants.push('finSaison : prise en phase ended'); }
  cour.indemnitesStats = { total: cour.indemnites.reduce((a, b) => a + b, 0), mediane: med(cour.indemnites) };
  delete cour.indemnites;
  cour.dureeSecondes = Math.round((Date.now() - debut) / 1000);
  dureeSaison.push(cour.dureeSecondes);
  saisonsReleves.push(cour);
  log('Saison ' + saison + ' mesurée en ' + cour.dureeSecondes + ' s');
  if (saison < SAISONS) model = jeu.regler(jeu.call('next_season', { confirmed: true }));
}
jeu.fermer();

const rapport = {
  club: CLUB, saisons: SAISONS, dureeTotaleSecondes: Math.round((Date.now() - t0) / 1000), dureeParSaison: dureeSaison,
  environnement: { CD_CLUBS_GERES_CALENDRIER: process.env.CD_CLUBS_GERES_CALENDRIER ?? null, CD_PLANCHER_CLUBS_GERES: process.env.CD_PLANCHER_CLUBS_GERES ?? null },
  notes: ['Achats entre clubs gérés = événements « sell » avec indemnité > 0 des clubs gérés, hors joueurs arrivés chez le club joué (achatsTexte = fil S.economy.transfers, plafonné à 80 lignes, relu chaque semaine).',
    'Caisses et salaires en euros ; masseHebdo = somme des salaires hebdomadaires ; niveau = moyenne des 23 meilleurs (roleNote si disponible).'],
  saisonsReleves,
};
const json = JSON.stringify(rapport, null, 1);
if (SORTIE) { fs.mkdirSync(path.dirname(path.resolve(SORTIE)), { recursive: true }); fs.writeFileSync(SORTIE, json); } else process.stdout.write(json + '\n');

// Résumé lisible.
const M = x => x == null ? 'n/d' : (Math.round(x / 1e5) / 10) + ' M';
log('\n=== Résumé (' + SAISONS + ' saisons, ' + rapport.dureeTotaleSecondes + ' s) ===');
for (const s of saisonsReleves) {
  log('\n-- Saison ' + s.saison + ' (' + s.dureeSecondes + ' s) ; achats gérés : ' + s.achatsTotal + ' (fil texte : ' + s.achatsTexte + '), indemnités total ' + M(s.indemnitesStats.total) + ', médiane ' + M(s.indemnitesStats.mediane));
  log('   achats par semaine : ' + JSON.stringify(s.achatsParSemaine));
  log('   pré-contrats (S.calendrierMutations.ia) : ' + JSON.stringify(s.preContrats));
  log('   courriers par semaine : ' + JSON.stringify(s.courriersParSemaine));
  for (const [nom, r] of Object.entries(s.releves)) {
    log('   [' + nom + ' - sem. ' + r.semaine + '] club joué : effectif ' + r.clubJoue?.effectif + ', caisse ' + M(r.clubJoue?.caisse));
    for (const [lg, v] of Object.entries({ ...r.parLigue, TOTAL: r.total }))
      if (v) log('     ' + lg.padEnd(10) + ' eff ' + v.effectif.min + '/' + v.effectif.med + '/' + v.effectif.max + ' (<30:' + v.effectif.sous30 + ' <37:' + v.effectif.sous37 + ') niv ' + v.niveau.med + ' ±' + v.niveau.ecartType + ' caisse méd ' + M(v.caisse.med) + ' (neg ' + v.caisse.negatifs + ') masse hebdo méd ' + Math.round(v.masseHebdo.med) + ' (>limite ' + v.masseHebdo.auDessusLimite + '/' + v.masseHebdo.limiteMesuree + ') compl. ' + v.complement.total);
  }
  for (const m of s.relevesManquants) log('   RELEVÉ MANQUANT : ' + m);
}
