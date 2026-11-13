'use strict';

// Called in the native VM. Source facts are immutable and synthetic origins
// use the original catalogue club, never the player's current employer.
module.exports = function playerFacts(catalogue = {}, origins = {}, clubs = {}) {
  const nations = {
    FRA:['France','fr'], ENG:['Angleterre','gb-eng'], SCO:['Écosse','gb-sct'],
    WAL:['Pays de Galles','gb-wls'], IRE:['Irlande','ie'], ITA:['Italie','it'],
    NZL:['Nouvelle-Zélande','nz'], RSA:['Afrique du Sud','za'], AUS:['Australie','au'],
    ARG:['Argentine','ar'], JPN:['Japon','jp'], FIJ:['Fidji','fj'], SAM:['Samoa','ws'],
    TGA:['Tonga','to'], GEO:['Géorgie','ge'], ESP:['Espagne','es'], POR:['Portugal','pt'],
    ROU:['Roumanie','ro'], URU:['Uruguay','uy'], CHI:['Chili','cl'], USA:['États-Unis','us'],
    CAN:['Canada','ca'], ZIM:['Zimbabwe','zw'], HKG:['Hong Kong','hk'], NAM:['Namibie','na'],
    BRA:['Brésil','br'], BEL:['Belgique','be'], NED:['Pays-Bas','nl'], GER:['Allemagne','de'],
    SUI:['Suisse','ch'], KEN:['Kenya','ke'], UAE:['Émirats arabes unis','ae'],
    KOR:['Corée du Sud','kr'], RUS:['Russie','ru'], POL:['Pologne','pl'], SWE:['Suède','se'],
  };
  const byFlag = new Map(Object.entries(nations).map(([nation, [, flag]]) => [flag, nation]));
  const sources = catalogue.players ?? {};
  const variations = ['FRA','ENG','NZL','RSA','AUS','ARG','IRE','SCO','WAL','GEO','JPN','FIJ','SAM','TGA','ITA','ESP'];
  const source = id => Object.hasOwn(sources, id) ? sources[id] : {};
  const hashId = text => Array.from(text).reduce((n, letter) => Math.imul(n ^ letter.charCodeAt(0), 16777619), 2166136261) >>> 0;
  const builds = [
    ['pilier', 184, 116], ['talonneur', 182, 106], ['deuxième', 199, 116],
    ['troisième', 190, 105], ['numéro 8', 190, 108], ['demi de mêlée', 177, 82], ["demi d'ouverture", 183, 89],
    ['centre', 187, 97], ['ailier', 185, 93], ['arrière', 186, 92],
  ];

  function physicalProfile(id, player, record) {
    const position = String(player?.pos ?? '').toLowerCase().replace('’', "'");
    const [, typicalHeight, typicalWeight] = builds.find(([prefix]) => position.startsWith(prefix)) ?? ['', 185, 96];
    const hash = hashId(id + ':rugby-build');
    const youth = Math.max(0, 20 - (Number(player?.age) || 20));
    const heightCm = record.heightCm ?? typicalHeight + hash % 13 - 6 - youth;
    const weightKg = record.weightKg ?? Math.round(typicalWeight + (heightCm - typicalHeight) * 0.65 + (hash >>> 8) % 13 - 6 - 2 * youth);
    return { heightCm, weightKg, dimensionsSource: record.heightCm != null && record.weightKg != null ? 'documented' : 'estimated' };
  }

  // Jeunes générés (décision de Léo du 12/11/2026) : origine tirée selon le pays du club
  // formateur, avec la même table que youthHeritage() de dist/development.js. Un jeune
  // formé dans le pays de son club y a grandi : il est aussi sélectionnable pour ce pays
  // (naissance ou résidence de 60 mois), comme le prévoit la règle 8 de World Rugby.
  const heritage = {
    FRA:[['FRA',84],['FIJ',3],['GEO',3],['TGA',2],['RSA',2],['POR',2],['SAM',1],['ENG',1],['ARG',1],['NZL',1]],
    ENG:[['ENG',80],['RSA',4],['SAM',3],['TGA',3],['IRE',3],['FIJ',2],['SCO',2],['NZL',2],['WAL',1]],
    SCO:[['SCO',82],['ENG',8],['RSA',4],['NZL',3],['IRE',3]],
    WAL:[['WAL',85],['ENG',7],['SAM',3],['RSA',3],['IRE',2]],
    IRE:[['IRE',88],['ENG',4],['NZL',3],['RSA',3],['SAM',2]],
    ITA:[['ITA',84],['ARG',8],['RSA',4],['NZL',2],['ROU',2]],
    RSA:[['RSA',94],['NAM',3],['ZIM',3]],
    NZL:[['NZL',72],['SAM',12],['TGA',9],['FIJ',5],['ENG',2]],
    AUS:[['AUS',72],['TGA',8],['SAM',8],['FIJ',6],['NZL',6]],
    FIJ:[['FIJ',100]], GEO:[['GEO',100]],
    JPN:[['JPN',86],['TGA',6],['NZL',4],['SAM',2],['KOR',2]],
  };
  const youthAnchor = id => {
    const generated = /^youth-(\d+)-/.exec(id);
    return generated && !Object.hasOwn(origins, id) && Object.hasOwn(nations, clubs[generated[1]]) ? clubs[generated[1]] : null;
  };
  function youthHeritage(id, anchor) {
    const table = heritage[anchor];
    if (!table) return anchor;
    let roll = hashId(id + ':rugby-origin') % 100;
    for (const [nation, weight] of table) { if (roll < weight) return nation; roll -= weight; }
    return anchor;
  }

  function estimate(id) {
    const anchorYouth = youthAnchor(id);
    if (anchorYouth && heritage[anchorYouth]) return youthHeritage(id, anchorYouth);
    const generated = /^(?:depth-|youth-|p)(\d+)-/.exec(id);
    const anchor = origins[id] ?? (generated ? clubs[generated[1]] : null);
    const hash = hashId(id + ':rugby-origin');
    if (Object.hasOwn(nations, anchor) && (Object.hasOwn(origins, id) || hash % 100 < 78)) return anchor;
    return variations[(hash >>> 8) % variations.length];
  }

  function eligible(id, nation) {
    const record = source(id);
    if (record.seniorNation) return nation === record.seniorNation;
    if (record.eligibilityNations?.length) return record.eligibilityNations.includes(nation);
    const documented = byFlag.get(record.flagCode);
    if (documented) return nation === documented;
    const anchorYouth = youthAnchor(id);
    if (anchorYouth && heritage[anchorYouth]) return nation === anchorYouth || nation === youthHeritage(id, anchorYouth);
    return !Object.hasOwn(origins, id) && nation === estimate(id);
  }

  function project(id, appearance = null, player = null) {
    const record = source(id);
    const inferred = record.nationality ? null : estimate(id);
    const origin = nations[inferred];
    const seniorNation = appearance?.nation ?? record.seniorNation ?? null;
    const selection = nations[seniorNation];
    const observedCaps = Number.isInteger(record.seniorCaps) && record.seniorCaps >= 0;
    return {
      nationality: record.nationality ?? origin[0],
      flagCode: record.flagCode ?? origin?.[1] ?? null,
      nationalitySource: inferred ? 'simulated' : 'documented',
      ...physicalProfile(id, player, record),
      seniorNation,
      seniorNationName: selection?.[0] ?? seniorNation,
      seniorFlagCode: selection?.[1] ?? null,
      seniorCaps: (observedCaps ? record.seniorCaps : 0) + (appearance?.career ?? 0),
      capsSource: observedCaps ? 'documented' : 'game-default',
    };
  }

  // Code de la nation d'origine (documentée par le drapeau, sinon estimée) : sert à orienter les portraits.
  function origin(id) {
    const record = source(id);
    return (record.flagCode && byFlag.get(record.flagCode)) || estimate(id);
  }

  return { eligible, project, source, nations, origin };
};
