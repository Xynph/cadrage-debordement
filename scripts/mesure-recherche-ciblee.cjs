'use strict';
// Mesure de la recherche ciblée (native/engine/recherche-ciblee.cjs, idée FM27 n° 26) sur une saison Monde simulée :
// un manager qui envoie le recruteur dès que possible (une recherche continue en fond, une prioritaire toutes les
// 8 semaines, une standard sinon, maillots en rotation, rôles du poste en rotation). Relève le débit de 5 000 € à
// chaque envoi, le nombre de pistes par mission (nouvelles / déjà connues), libres ou sous contrat, et la taille de
// la liste des joueurs observés. Usage : node scripts/mesure-recherche-ciblee.cjs [matchs=26]
const { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante } = require('../tests/helpers/carriere-monde.cjs');
const { factory } = require('../native/engine/recherche-ciblee.cjs');
const ROLES = factory().ROLES;
const FAMILLES = [0, 1, 0, 2, 2, 3, 3, 3, 4, 5, 6, 7, 7, 6, 8];
const FAMILLE_ROLE = ['pilier', 'talonneur', 'pilier', 'deuxieme', 'deuxieme', 'aile', 'aile', 'huit', 'demi', 'ouvreur', 'ailier', 'centre', 'centre', 'ailier', 'arriere'];
const matchs = Number(process.argv[2] || 26);
const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
const etat = () => JSON.parse(jeu.call('export').meta.exportText).state;
// Rapports relevés à chaque match : le moteur n'en garde que 40.
const vus = new Map();
const relever = st => { for (const r of st.manager.reports) if (r.cible) vus.set(r.id, r); return st; };
let m = creer(jeu), envois = 0, debitsJustes = 0, k = 0, continueLancee = false;
const t0 = Date.now();
for (let n = 0; n < matchs; n++) {
  const rc = m.clubLife.rechercheCiblee;
  if (rc?.disponible) {
    const maillot = [1, 2, 4, 6, 8, 9, 10, 11, 12, 15][k % 10], roles = ROLES.filter(r => r[1] === FAMILLE_ROLE[maillot - 1]);
    const priority = !continueLancee ? 'continue' : n % 8 === 0 ? 'prioritaire' : 'standard';
    const s = etat(), avant = s.clubs[s.club].cash;
    m = jeu.call('scout_mission', { family: FAMILLES[maillot - 1], maxAge: 30, budget: 1000000, maxWage: 100000, confirmed: true, position: maillot,
      role: roles[k % roles.length][0], minNote: 55, minPotential: 0, minAge: 20, priority, scouts: (rc.recruteurs || []).slice(0, 1 + (k % 2)).map(x => x.id) });
    const apres = etat().clubs[s.club].cash;
    envois++; if (avant - apres === 5000) debitsJustes++; else console.log('débit inattendu', avant - apres);
    if (priority === 'continue') continueLancee = true;
    k++;
  }
  m = jusquALaSemaineSuivante(jeu, jouerLeMatch(jeu, jusquAuMatch(jeu, m)));
  relever(etat());
}
const s = relever(etat()), missions = s.manager.missions.filter(j => j.cible), rapports = [...vus.values()];
const parMission = missions.filter(j => j.status === 'done').map(j => { const r = rapports.filter(x => x.mission === j.id); return { id: j.id, priorite: j.cible.priority, cycle: j.cible.cycle, maillot: j.cible.position, recruteurs: j.cible.scouts.length, nouveaux: r.filter(x => !x.cible.connu).length, connus: r.filter(x => x.cible.connu).length }; });
console.log(JSON.stringify({ matchs, minutes: Math.round((Date.now() - t0) / 600) / 100, envois, debitsJustes, coutTotal: envois * 5000,
  missionsTerminees: parMission.length, relances: missions.filter(j => j.cible.cycle > 1).length,
  pistesNouvelles: parMission.reduce((a, x) => a + x.nouveaux, 0), pistesConnues: parMission.reduce((a, x) => a + x.connus, 0),
  rapports: rapports.length, sousContrat: rapports.filter(r => r.cible.club !== null).length, libres: rapports.filter(r => r.cible.club === null).length,
  observes: m.clubLife.rechercheCiblee.connus.length, parMission }, null, 1));
jeu.fermer();
