'use strict';

const SIX_NATIONS = 'six-nations-2027';
const WORLD_CUP = 'rugby-world-cup-2027';

const sources = {
  sixNationsCalendar: 'https://www.sixnationsrugby.com/en/m6n/news/fixtures-round-by-round-guide-to-every-match-2027-six-nations',
  sixNationsRules: 'https://www.sixnationsrugby.com/en/m6n/championship-rules',
  worldCupCalendar: 'https://experiences.rugbyworldcup.com/rwc2027/match-schedule',
  worldCupDraw: 'https://www.rugbyworldcup.com/2027/en/news/1019390/pools-confirmed-for-mens-rugby-world-cup-2027-in-australia',
  worldCupThirds: 'https://www.world.rugby/news/1019814/the-new-mens-rugby-world-cup-draw-format-explained?lang=en',
  worldCupPreviousRules: 'https://resources.world.rugby/worldrugby/document/2023/05/03/fb8ea1ec-b3d9-46c6-933e-bdd1105e3bed/RWC-2023-Tournament-Rules.pdf',
};

const teamNames = {
  ARG: 'Argentine', AUS: 'Australie', CAN: 'Canada', CHI: 'Chili',
  ENG: 'Angleterre', ESP: 'Espagne', FIJ: 'Fidji', FRA: 'France',
  GEO: 'Géorgie', HKG: 'Hong Kong Chine', IRE: 'Irlande', ITA: 'Italie',
  JPN: 'Japon', NZL: 'Nouvelle-Zélande', POR: 'Portugal', ROU: 'Roumanie',
  RSA: 'Afrique du Sud', SAM: 'Samoa', SCO: 'Écosse', TGA: 'Tonga',
  URU: 'Uruguay', USA: 'États-Unis', WAL: 'Pays de Galles', ZIM: 'Zimbabwe',
};

const sixNationsTeams = ['ENG', 'FRA', 'IRE', 'ITA', 'SCO', 'WAL'];
const sixNationsVenues = {
  ENG: 'Allianz Stadium', FRA: 'Stade de France', IRE: 'Aviva Stadium',
  ITA: 'Stadio Olimpico', SCO: 'Scottish Gas Murrayfield', WAL: 'Principality Stadium',
};

// Matchday, stadium-local kickoff, nominal host and visitor.
const sixNationsSchedule = [
  [
    ['02-05', '20:10', 'IRE', 'ENG'],
    ['02-06', '14:10', 'SCO', 'ITA'],
    ['02-06', '17:40', 'FRA', 'WAL'],
  ],
  [
    ['02-13', '15:10', 'ITA', 'IRE'],
    ['02-13', '16:40', 'SCO', 'WAL'],
    ['02-14', '15:10', 'ENG', 'FRA'],
  ],
  [
    ['02-20', '14:10', 'WAL', 'IRE'],
    ['02-20', '16:40', 'ENG', 'ITA'],
    ['02-21', '16:10', 'FRA', 'SCO'],
  ],
  [
    ['03-05', '20:10', 'SCO', 'IRE'],
    ['03-06', '15:10', 'ITA', 'FRA'],
    ['03-06', '16:40', 'WAL', 'ENG'],
  ],
  [
    ['03-13', '15:10', 'ITA', 'WAL'],
    ['03-13', '16:40', 'ENG', 'SCO'],
    ['03-13', '20:10', 'IRE', 'FRA'],
  ],
];

const worldCupPools = {
  A: ['NZL', 'AUS', 'CHI', 'HKG'],
  B: ['RSA', 'ITA', 'GEO', 'ROU'],
  C: ['ARG', 'FIJ', 'ESP', 'CAN'],
  D: ['IRE', 'SCO', 'URU', 'POR'],
  E: ['FRA', 'JPN', 'USA', 'SAM'],
  F: ['ENG', 'WAL', 'TGA', 'ZIM'],
};

const worldCupVenues = {
  ADE: 'Adelaide Oval',
  BNE: 'Brisbane Stadium',
  MEL: 'Docklands Stadium',
  NEW: 'Newcastle Stadium',
  PER: 'Perth Stadium',
  SFS: 'Sydney Football Stadium',
  SYD: 'Stadium Australia',
  TSV: 'North Queensland Stadium',
};

// Two rows per pool per round, using the published match order.
const worldCupPoolSchedule = {
  A: [
    [1, '18:45', 'PER', 'AUS', 'HKG'], [2, '13:15', 'PER', 'NZL', 'CHI'],
    [9, '17:10', 'SYD', 'NZL', 'AUS'], [9, '20:15', 'TSV', 'CHI', 'HKG'],
    [15, '17:15', 'MEL', 'NZL', 'HKG'], [16, '15:10', 'BNE', 'AUS', 'CHI'],
  ],
  B: [
    [3, '14:15', 'ADE', 'RSA', 'ITA'], [3, '20:15', 'TSV', 'GEO', 'ROU'],
    [10, '16:45', 'BNE', 'RSA', 'GEO'], [11, '19:45', 'SFS', 'ITA', 'ROU'],
    [17, '12:15', 'NEW', 'ITA', 'GEO'], [17, '19:15', 'PER', 'RSA', 'ROU'],
  ],
  C: [
    [4, '14:15', 'NEW', 'FIJ', 'ESP'], [4, '18:45', 'BNE', 'ARG', 'CAN'],
    [10, '12:15', 'ADE', 'FIJ', 'CAN'], [10, '15:15', 'MEL', 'ARG', 'ESP'],
    [16, '13:15', 'ADE', 'ARG', 'FIJ'], [16, '20:15', 'TSV', 'ESP', 'CAN'],
  ],
  D: [
    [3, '17:15', 'MEL', 'SCO', 'URU'], [4, '17:15', 'SFS', 'IRE', 'POR'],
    [10, '17:45', 'PER', 'IRE', 'SCO'], [11, '17:15', 'NEW', 'URU', 'POR'],
    [17, '14:45', 'MEL', 'IRE', 'URU'], [17, '16:15', 'BNE', 'SCO', 'POR'],
  ],
  E: [
    [2, '17:45', 'MEL', 'FRA', 'USA'], [3, '12:15', 'NEW', 'JPN', 'SAM'],
    [9, '12:15', 'PER', 'USA', 'SAM'], [9, '18:45', 'BNE', 'FRA', 'JPN'],
    [15, '20:00', 'ADE', 'JPN', 'USA'], [17, '19:45', 'SFS', 'FRA', 'SAM'],
  ],
  F: [
    [2, '12:15', 'ADE', 'WAL', 'ZIM'], [2, '20:15', 'BNE', 'ENG', 'TGA'],
    [8, '18:15', 'MEL', 'WAL', 'TGA'], [8, '20:15', 'ADE', 'ENG', 'ZIM'],
    [15, '20:15', 'TSV', 'TGA', 'ZIM'], [16, '19:45', 'SYD', 'ENG', 'WAL'],
  ],
};

// A1 = first in Pool A, TA = third-place opponent of A1, W/L = winner/loser.
const worldCupKnockoutSchedule = [
  ['r16-1', '10-23', '14:15', 'SFS', 4, 'round-of-16', 'C2', 'F2'],
  ['r16-2', '10-23', '15:45', 'BNE', 4, 'round-of-16', 'A1', 'TA'],
  ['r16-3', '10-23', '19:15', 'MEL', 4, 'round-of-16', 'E1', 'D2'],
  ['r16-4', '10-23', '18:45', 'PER', 4, 'round-of-16', 'B1', 'TB'],
  ['r16-5', '10-24', '14:15', 'SFS', 4, 'round-of-16', 'C1', 'TC'],
  ['r16-6', '10-24', '16:45', 'MEL', 4, 'round-of-16', 'D1', 'TD'],
  ['r16-7', '10-24', '18:15', 'BNE', 4, 'round-of-16', 'A2', 'E2'],
  ['r16-8', '10-24', '18:45', 'PER', 4, 'round-of-16', 'F1', 'B2'],
  ['qf-1', '10-30', '16:45', 'SYD', 5, 'quarter-final', 'Wr16-2', 'Wr16-4'],
  ['qf-2', '10-30', '18:45', 'BNE', 5, 'quarter-final', 'Wr16-1', 'Wr16-3'],
  ['qf-3', '10-31', '16:00', 'BNE', 5, 'quarter-final', 'Wr16-5', 'Wr16-6'],
  ['qf-4', '10-31', '20:00', 'SYD', 5, 'quarter-final', 'Wr16-7', 'Wr16-8'],
  ['sf-1', '11-05', '20:00', 'SYD', 6, 'semi-final', 'Wqf-1', 'Wqf-2'],
  ['sf-2', '11-06', '20:00', 'SYD', 6, 'semi-final', 'Wqf-3', 'Wqf-4'],
  ['bronze-final', '11-12', '19:45', 'SYD', 7, 'bronze-final', 'Lsf-1', 'Lsf-2'],
  ['final', '11-13', '20:00', 'SYD', 7, 'final', 'Wsf-1', 'Wsf-2'],
];

// Exact published matrix: columns give the pool of the opponent for A1, B1, C1 and D1.
const thirdPlacePermutations = {
  ABCD: 'CDAB', ABCE: 'CEAB', ABCF: 'CFAB',
  ABDE: 'EDAB', ABDF: 'FDAB', ABEF: 'EFAB',
  ACDE: 'CDAE', ACDF: 'CDAF', ACEF: 'CEAF', ADEF: 'EDAF',
  BCDE: 'CDEB', BCDF: 'CDFB', BCEF: 'CEFB', BDEF: 'EDFB',
  CDEF: 'CDEF',
};

// Provisional in-game order for the participants. This is not the 2027-10-18 World Rugby ranking.
const defaultRankings = [
  'RSA', 'NZL', 'ENG', 'IRE', 'FRA', 'ARG',
  'AUS', 'FIJ', 'SCO', 'ITA', 'WAL', 'JPN',
  'GEO', 'URU', 'ESP', 'USA', 'TGA', 'CHI',
  'POR', 'SAM', 'ROU', 'CAN', 'HKG', 'ZIM',
];

module.exports = {
  SIX_NATIONS, WORLD_CUP, sources, teamNames,
  sixNationsTeams, sixNationsVenues, sixNationsSchedule,
  worldCupPools, worldCupVenues, worldCupPoolSchedule, worldCupKnockoutSchedule,
  thirdPlacePermutations, defaultRankings,
};
