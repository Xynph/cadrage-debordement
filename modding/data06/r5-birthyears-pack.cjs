'use strict';
// Raccordement explicite DATA-06 -> R5. Rien n'est installé ou sélectionné implicitement.
const data = require('./consolidated-birthyears-1592-2026-11-01.json');
function createRugbyRealBirthyearPack() {
  if (!data || !Array.isArray(data.players) || data.players.length !== 1592) throw Error('DATA-06 incomplet');
  const seen = new Set();
  const players = data.players.map(p => {
    if (!/^lnr:[0-9]+$/.test(p.id) || seen.has(p.id)) throw Error('ID LNR absent ou dupliqué');
    seen.add(p.id);
    if (!Number.isInteger(p.birthYear) || p.birthYear < 1900 || p.birthYear > 2010) throw Error('Année invalide : '+p.id);
    return {id:p.id,name:p.name,clubId:p.club,birthYear:p.birthYear,
      ...(p.birthDate ? {birthDate:p.birthDate} : {}),
      provenance:p.provenance, historicalConflictRetained:!!p.previousConflictRetained};
  });
  return {manifest:{schema:1,id:'rugby-real-birthyears-2026',version:'1.0.0',kind:'dataset',
      title:'Rugby Réel 2026–2027 — années de naissance'},
    records:{players}};
}
function installRugbyRealBirthyears(world) {
  if (!world || typeof world.install !== 'function') throw Error('Univers R5 requis');
  // Ne modifie pas l'univers actif ; la sélection doit être volontaire.
  return world.install(createRugbyRealBirthyearPack());
}
module.exports={createRugbyRealBirthyearPack,installRugbyRealBirthyears};
