'use strict';

const id = 'nations-championship-2026';
const name = 'Nations Championship 2026';
const year = 2026;
const hemispheres = {
  north: ['ENG', 'FRA', 'IRE', 'ITA', 'SCO', 'WAL'],
  south: ['ARG', 'AUS', 'FIJ', 'JPN', 'NZL', 'RSA'],
};
const provenance = {
  calendar: 'https://nationschampionshiprugby.com/en',
  rules: 'https://nationschampionshiprugby.com/en/match-centre/stats/hemisphere',
  finals: 'https://nationschampionshiprugby.com/en/finals-weekend',
};

// Local dates and nominal home teams. July kick-off times are omitted.
const leagueSchedule = [
  [
    ['07-04', null, 'NZL', 'FRA', 'One New Zealand Stadium'],
    ['07-04', null, 'JPN', 'ITA', 'Prince Chichibu Memorial Rugby Ground'],
    ['07-04', null, 'AUS', 'IRE', 'Allianz Stadium'],
    ['07-04', null, 'FIJ', 'WAL', 'Cardiff City Stadium', true],
    ['07-04', null, 'RSA', 'ENG', 'Ellis Park'],
    ['07-04', null, 'ARG', 'SCO', 'Estadio Mario Alberto Kempes'],
  ],
  [
    ['07-11', null, 'NZL', 'ITA', 'Hnry Stadium'],
    ['07-11', null, 'AUS', 'FRA', 'Suncorp Stadium'],
    ['07-11', null, 'JPN', 'IRE', 'McDonald Jones Stadium', true],
    ['07-11', null, 'FIJ', 'ENG', 'Hill Dickinson Stadium', true],
    ['07-11', null, 'RSA', 'SCO', 'Loftus Versfeld'],
    ['07-11', null, 'ARG', 'WAL', 'Estadio San Juan del Bicentenario'],
  ],
  [
    ['07-18', null, 'NZL', 'IRE', 'Eden Park'],
    ['07-18', null, 'JPN', 'FRA', 'MUFG Stadium'],
    ['07-18', null, 'AUS', 'ITA', 'HBF Park'],
    ['07-18', null, 'FIJ', 'SCO', 'Scottish Gas Murrayfield', true],
    ['07-18', null, 'RSA', 'WAL', 'Hollywoodbets Kings Park'],
    ['07-18', null, 'ARG', 'ENG', 'Estadio Único Madre de Ciudades'],
  ],
  [
    ['11-06', '20:10', 'IRE', 'ARG', 'Aviva Stadium'],
    ['11-07', '12:40', 'ITA', 'RSA', 'Allianz Stadium, Turin'],
    ['11-07', '14:10', 'SCO', 'NZL', 'Scottish Gas Murrayfield'],
    ['11-07', '16:40', 'WAL', 'JPN', 'Principality Stadium'],
    ['11-07', '21:10', 'FRA', 'FIJ', 'Groupama Stadium'],
    ['11-08', '15:10', 'ENG', 'AUS', 'Allianz Stadium'],
  ],
  [
    ['11-13', '21:10', 'FRA', 'RSA', 'Stade de France'],
    ['11-14', '12:40', 'ITA', 'ARG', 'Stadio Luigi Ferraris'],
    ['11-14', '14:10', 'WAL', 'NZL', 'Principality Stadium'],
    ['11-14', '16:40', 'ENG', 'JPN', 'Allianz Stadium'],
    ['11-14', '20:10', 'IRE', 'FIJ', 'Aviva Stadium'],
    ['11-15', '15:10', 'SCO', 'AUS', 'Scottish Gas Murrayfield'],
  ],
  [
    ['11-21', '14:10', 'ENG', 'NZL', 'Allianz Stadium'],
    ['11-21', '14:10', 'SCO', 'JPN', 'Scottish Gas Murrayfield'],
    ['11-21', '16:40', 'IRE', 'RSA', 'Aviva Stadium'],
    ['11-21', '17:40', 'ITA', 'FIJ', 'Bluenergy Stadium'],
    ['11-21', '21:10', 'FRA', 'ARG', 'Stade de France'],
    ['11-21', '20:10', 'WAL', 'AUS', 'Principality Stadium'],
  ],
];

const finalsSchedule = [
  ['11-27', '16:40', 6],
  ['11-27', '20:10', 3],
  ['11-28', '13:10', 5],
  ['11-28', '16:40', 2],
  ['11-29', '13:10', 4],
  ['11-29', '16:40', 1],
];

module.exports = { id, name, year, provenance, hemispheres, leagueSchedule, finalsSchedule };
