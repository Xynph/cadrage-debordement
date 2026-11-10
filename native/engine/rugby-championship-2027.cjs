'use strict';

const id = 'rugby-championship-2027';
const name = 'Rugby Championship 2027';
const teams = ['ARG', 'AUS', 'NZL', 'RSA'];
const provenance = {
  calendar: 'https://super.rugby/therugbychampionship/news/sanzaar-confirms-new-and-exciting-international-rugby-calendar-2026-2030/',
  australia: 'https://www.rugby.com.au/wallabies/news/wallabies-lock-in-2027-bledisloe-cup-rugby-championship-fixtures-ahead-of-home-rugby-world-cup-all-blacks-springboks-argentina-2026929',
  bledisloe: 'https://super.rugby/therugbychampionship/news/wallabies-to-host-new-zealand-in-bledisloe-blockbuster-at-mcg/',
  provisionalRules: 'https://super.rugby/therugbychampionship/about-trc/tournament-format/',
  calendarStatus: 'partially-confirmed',
};

// Official dates carry their confirmed venue. Unpublished slots use the
// mini-tour structure of the most recently documented senior format.
const schedule = [
  ['07-10', [['AUS', 'ARG', 'Allianz Stadium'], ['NZL', 'RSA']]],
  ['07-17', [['AUS', 'ARG', 'Queensland Country Bank Stadium'], ['NZL', 'RSA']]],
  ['07-31', [['AUS', 'NZL', 'Melbourne Cricket Ground'], ['ARG', 'RSA']]],
  ['08-07', [['NZL', 'AUS'], ['RSA', 'ARG']]],
  ['08-14', [['RSA', 'AUS'], ['ARG', 'NZL']]],
  ['08-21', [['RSA', 'AUS'], ['ARG', 'NZL']]],
];

module.exports = { id, name, teams, provenance, schedule };
