'use strict';

const fs = require('node:fs');
const path = require('node:path');
const {build} = require('../tools/calendrier04-build.cjs');
const {clubs} = require('../native/engine/world-registry.json');
const {events, sourceUrls} = require('../world-data/univers01/shared-calendar-2026-2027.json');

const slugs = {
  'AVIRON BAYONNAIS': 'bayonne',
  'UNION BORDEAUX-BÈGLES': 'bordeaux-begles',
  'CASTRES OLYMPIQUE': 'castres',
  'STADE ROCHELAIS': 'la-rochelle',
  'LOU RUGBY': 'lyon',
  'MONTPELLIER HR': 'montpellier',
  'STADE FRANÇAIS PARIS': 'paris',
  'ASM CLERMONT': 'clermont',
  'SECTION PALOISE': 'pau',
  'USA PERPIGNAN': 'perpignan',
  'RACING 92': 'racing-92',
  'RC TOULON': 'toulon',
  'STADE TOULOUSAIN': 'toulouse',
  'RC VANNES': 'vannes',
  'PROVENCE RUGBY': 'provence-rugby',
  'SOYAUX-ANGOULÊME XV': 'angouleme',
  'AS BÉZIERS HÉRAULT': 'beziers',
  'BIARRITZ OLYMPIQUE PB': 'biarritz',
  'CA BRIVE': 'brive',
  'US DAX': 'dax',
  'FC GRENOBLE RUGBY': 'grenoble',
  'USON NEVERS': 'nevers',
  'SU AGEN': 'agen',
  'STADE AURILLACOIS': 'aurillac',
  'COLOMIERS RUGBY': 'colomiers',
  'US MONTAUBAN': 'montauban',
  'RC NARBONNAIS': 'narbonne',
  'NISSA RUGBY': 'nice',
  'OYONNAX RUGBY': 'oyonnax',
  'VALENCE ROMANS DR': 'valence-romans',
};
const bySlug = new Map(clubs.map(club => [club.slug, club]));
const fixtures = {elite: [], accession: []};
const sourceFixtures = build().fixtures;
for (const fixture of sourceFixtures) {
  const league = fixture.competition === 'top14' ? 'elite' : 'accession';
  const home = bySlug.get(slugs[fixture.home]);
  const away = bySlug.get(slugs[fixture.away]);
  if (home?.leagueId !== league || away?.leagueId !== league) {
    throw Error('Correspondance LNR invalide pour ' + fixture.id);
  }
  fixtures[league].push([
    home.id, away.id, fixture.windowStart, fixture.windowEnd,
    fixture.simulatedKickoff.slice(0, 10), fixture.simulatedKickoff.slice(11, 16)
  ]);
}

const sourcePhase = {playoffBarrage: 'barrage', playoffSemiFinal: 'semi', final: 'final', accessMatchTop14: 'access'};
const playoffs = {elite: {}, accession: {}, access: {}};
for (const event of events.filter(item => Object.hasOwn(sourcePhase, item.type))) {
  const phase = sourcePhase[event.type];
  const league = phase === 'access' ? 'access' : event.competition === 'TOP 14' ? 'elite' : 'accession';
  playoffs[league][phase] = [event.start, event.end];
}
const sourceFiles = Object.fromEntries(['elite', 'accession'].map(league => {
  const competition = league === 'elite' ? 'top14' : 'prod2';
  const filename = sourceFixtures.find(fixture => fixture.competition === competition).sourceFile;
  const base = league === 'elite' ? 'https://assets.lnr.fr/2/9/4/0/4/6/' : 'https://assets.lnr.fr/2/9/4/0/2/9/';
  return [league, base + filename];
}));

const target = path.join(__dirname, '../native/engine/lnr-calendar-2026-27.json');
const lines = [
  '{',
  '  "schema": "world-lnr-calendar-v1",',
  '  "regularSources": ' + JSON.stringify(sourceFiles) + ',',
  '  "playoffSources": ' + JSON.stringify(sourceUrls) + ',',
  '  "playoffs": ' + JSON.stringify(playoffs) + ',',
  '  "fixtures": {',
  ...Object.entries(fixtures).flatMap(([league, rows], index) => [
    '    "' + league + '": [',
    ...rows.map((row, i) => '      ' + JSON.stringify(row) + (i < rows.length - 1 ? ',' : '')),
    '    ]' + (index === 0 ? ',' : ''),
  ]),
  '  }',
  '}',
  '',
];
const output = lines.join('\n');
if (process.argv.includes('--check')) {
  if (fs.readFileSync(target, 'utf8').replaceAll('\r\n', '\n') !== output) throw Error('Calendrier LNR embarqué à régénérer.');
} else {
  fs.writeFileSync(target, output, 'utf8');
}
