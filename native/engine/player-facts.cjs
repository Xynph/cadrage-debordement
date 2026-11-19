'use strict';

// Called in the native VM. Source facts are immutable and synthetic origins
// use the original catalogue club, never the player's current employer.
module.exports = function playerFacts(catalogue = {}, origins = {}, clubs = {}, angleterre = null) {
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

  // Éligibilité anglaise (EQP) des joueurs non documentés des clubs anglais (eqp_eligibilite.json, 18/11/2026) :
  // `angleterre` = {regles, homes: id -> club d'origine}. Sans elle, origine = pays du club (100 % d'EQP en Premiership,
  // contre ~70 % en vrai). Naissance tirée selon la part d'EQP visée par le club, puis, pour un joueur né ailleurs et pas
  // encore sélectionné par sa fédération, ascendance anglaise ou 60 mois de résidence (règlement 8 de World Rugby).
  const regles = angleterre?.regles ?? null, homes = angleterre?.homes ?? {};
  const pick = (table, roll) => { const total = table.reduce((t, [, w]) => t + w, 0); let r = roll % total; for (const [v, w] of table) { if (r < w) return v; r -= w; } return table[0][0]; };
  // Probabilité qu'un joueur né hors d'Angleterre soit quand même EQP (moyenne exacte sur les tables).
  const eqpEtranger = regles ? (() => {
    const nes = regles.naissances_etrangeres, total = nes.reduce((t, [, w]) => t + w, 0), res = regles.residence;
    const resTotal = res.annees_en_angleterre.reduce((t, [, w]) => t + w, 0);
    const pRes = res.annees_en_angleterre.filter(([a]) => a * 12 >= res.mois_requis).reduce((t, [, w]) => t + w, 0) / resTotal;
    const pAsc = nes.reduce((t, [n, w]) => t + w * (regles.ascendance[n] ?? regles.ascendance.autre), 0) / total;
    return (1 - regles.deja_selectionne) * (1 - (1 - pAsc) * (1 - pRes));
  })() : 0;
  const memoAngleterre = new Map();
  const documente = id => { const r = source(id); return !!(r.seniorNation || r.eligibilityNations?.length || byFlag.get(r.flagCode)); };
  // Club par club : les joueurs documentés comptent tels quels ; parmi les autres, rangés par tirage, les premiers sont
  // nés en Angleterre, en nombre calculé pour que l'effectif atteigne la cible en moyenne (les nés ailleurs peuvent
  // encore être EQP par ascendance ou résidence). Nombre exact par club : pas d'effectif à 45 % pour une cible à 57 %.
  let nesAngleterre = null;
  function clubsAngleterre() {
    if (nesAngleterre) return nesAngleterre;
    nesAngleterre = new Set();
    const parClub = new Map();
    for (const id of Object.keys(homes)) {
      if (origins[id] !== 'ENG' || typeof regles.cibles[String(homes[id])] !== 'number') continue;
      const k = String(homes[id]); if (!parClub.has(k)) parClub.set(k, { doc: 0, docEqp: 0, autres: [] });
      const c = parClub.get(k);
      if (documente(id)) { c.doc++; if (eligibleDocumente(id, 'ENG')) c.docEqp++; } else c.autres.push(id);
    }
    for (const [k, c] of parClub) {
      const n = c.doc + c.autres.length, m = c.autres.length; if (!m) continue;
      const besoin = Math.max(0, Math.min(m, regles.cibles[k] * n - c.docEqp));
      const nes = Math.round(Math.max(0, Math.min(m, (besoin - eqpEtranger * m) / (1 - eqpEtranger))));
      c.autres.sort((a, b) => hashId(a + ':eqp-naissance') - hashId(b + ':eqp-naissance') || (a < b ? -1 : 1));
      for (const id of c.autres.slice(0, nes)) nesAngleterre.add(id);
    }
    return nesAngleterre;
  }
  function angleterreProfil(id) {
    if (!regles || origins[id] !== 'ENG' || !Object.hasOwn(homes, id) || documente(id)) return null;
    const cible = regles.cibles[String(homes[id])];
    if (typeof cible !== 'number') return null;
    if (memoAngleterre.has(id)) return memoAngleterre.get(id);
    const h = k => hashId(id + ':eqp-' + k);
    let profil;
    if (clubsAngleterre().has(id)) profil = { naissance: 'ENG', eqp: true };
    else {
      const naissance = pick(regles.naissances_etrangeres, h('pays'));
      const selectionne = h('selection') % 10000 < regles.deja_selectionne * 10000;
      const ascendance = h('ascendance') % 10000 < (regles.ascendance[naissance] ?? regles.ascendance.autre) * 10000;
      const annees = pick(regles.residence.annees_en_angleterre, h('residence'));
      const residence = annees * 12 >= regles.residence.mois_requis;
      profil = { naissance, eqp: !selectionne && (ascendance || residence), ascendance, annees };
    }
    memoAngleterre.set(id, profil);
    return profil;
  }

  function estimate(id) {
    const profil = angleterreProfil(id);
    if (profil) return profil.naissance;
    const anchorYouth = youthAnchor(id);
    if (anchorYouth && heritage[anchorYouth]) return youthHeritage(id, anchorYouth);
    const generated = /^(?:depth-|youth-|p)(\d+)-/.exec(id);
    const anchor = origins[id] ?? (generated ? clubs[generated[1]] : null);
    const hash = hashId(id + ':rugby-origin');
    if (Object.hasOwn(nations, anchor) && (Object.hasOwn(origins, id) || hash % 100 < 78)) return anchor;
    return variations[(hash >>> 8) % variations.length];
  }

  // Éligibilité des seuls joueurs documentés (null si rien n'est documenté).
  function eligibleDocumente(id, nation) {
    const record = source(id);
    if (record.seniorNation) return nation === record.seniorNation;
    if (record.eligibilityNations?.length) return record.eligibilityNations.includes(nation);
    const documented = byFlag.get(record.flagCode);
    return documented ? nation === documented : null;
  }

  function eligible(id, nation) {
    const record = source(id);
    if (record.seniorNation) return nation === record.seniorNation;
    if (record.eligibilityNations?.length) return record.eligibilityNations.includes(nation);
    const documented = byFlag.get(record.flagCode);
    if (documented) return nation === documented;
    const anchorYouth = youthAnchor(id);
    if (anchorYouth && heritage[anchorYouth]) return nation === anchorYouth || nation === youthHeritage(id, anchorYouth);
    const profil = angleterreProfil(id);
    if (profil) return nation === profil.naissance || nation === 'ENG' && profil.eqp;
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

  return { eligible, project, source, nations, origin, angleterreProfil };
};
