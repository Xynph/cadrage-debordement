'use strict';

const { teamNames } = require('./international-2027.cjs');

const worldRugbyAward = 'https://www.world.rugby/news/714742/rugby-world-cup-host-locations-confirmed-through-to-2033';
const australiaVenues = 'https://www.world.rugby/media-zone/advisory/1019915';
const usaVenues = 'https://www.world.rugby/media-zone/advisory/1018093';
const worldRugbyBid = 'https://www.world.rugby/news/1016610/world-rugby-launches-mens-rugby-world-cup-2035-host-selection-process';
const spainBid = 'https://ferugby.es/espana-entrega-el-cuestionario-de-candidatura-para-la-copa-del-mundo-masculina-2035-contando-con-un-gran-respaldo-institucional-y-deportivo/';
const nationsFinals = 'https://nationschampionshiprugby.com/en/finals-weekend';
const stadeDeFrance = 'https://www.world.rugby/news/890683/rugby-world-cup-2023-will-leave-a-legacy-of-harmony-growth-and-sustainable-responsibility';
const soldierField = 'https://www.soldierfield.com/events/detail/the-rematch-ireland-vs-all-blacks';
const regulation9 = 'https://www.world.rugby/organisation/governance/regulations/reg-9';

const capitals = {
  ARG: 'Buenos Aires', AUS: 'Canberra', ENG: 'Londres', ESP: 'Madrid', FIJ: 'Suva',
  FRA: 'Paris', IRE: 'Dublin', ITA: 'Rome', JPN: 'Tokyo', NZL: 'Wellington',
  RSA: 'Pretoria', SCO: 'Édimbourg', USA: 'Washington, D.C.', WAL: 'Cardiff',
};

const worldCupRotation = [
  ['ESP', 'Madrid', 'Estadio Metropolitano'],
  ['JPN', 'Yokohama', 'International Stadium Yokohama'],
  ['RSA', 'Johannesburg', 'Ellis Park'],
  ['FRA', 'Saint-Denis', 'Stade de France'],
  ['NZL', 'Auckland', 'Eden Park'],
  ['ENG', 'Londres', 'Allianz Stadium'],
  ['ITA', 'Rome', 'Stadio Olimpico'],
  ['ARG', 'Buenos Aires', 'Estadio Monumental'],
];
const nationsFinalsRotation = [
  ['JPN', 'Tokyo', 'Japan National Stadium'],
  ['ENG', 'Londres', 'Allianz Stadium'],
  ['RSA', 'Johannesburg', 'Ellis Park'],
  ['ITA', 'Rome', 'Stadio Olimpico'],
  ['NZL', 'Auckland', 'Eden Park'],
  ['IRE', 'Dublin', 'Aviva Stadium'],
  ['AUS', 'Sydney', 'Stadium Australia'],
  ['WAL', 'Cardiff', 'Principality Stadium'],
];

function worldCupHost(year) {
  const officialHostAnnouncementDate = '2022-05-12';
  if (year === 2027) return {
    id: 'AUS', city: 'Sydney', stadium: 'Stadium Australia', status: 'confirmed',
    officialHostAnnouncementDate, sources: [worldRugbyAward, australiaVenues],
  };
  if (year === 2031) return {
    id: 'USA', city: null, stadium: null, status: 'confirmed',
    officialHostAnnouncementDate, sources: [worldRugbyAward, usaVenues],
  };
  const index = (year - 2035) / 4;
  if (!Number.isInteger(index) || index < 0) return null;
  const [id, city, stadium] = worldCupRotation[index % worldCupRotation.length];
  return { id, city, stadium, status: 'simulated', sources: year === 2035 ? [worldRugbyBid, spainBid] : [] };
}

function nationsFinalHost(year) {
  if (year === 2026) return {
    id: 'ENG', city: 'Londres', stadium: 'Allianz Stadium', status: 'confirmed', sources: [nationsFinals],
  };
  if (year === 2028) return {
    id: 'FRA', city: 'Saint-Denis', stadium: 'Stade de France', status: 'simulated', sources: [stadeDeFrance],
  };
  if (year === 2030) return {
    id: 'USA', city: 'Chicago', stadium: 'Soldier Field', status: 'simulated', sources: [soldierField],
  };
  const index = (year - 2032) / 2;
  if (!Number.isInteger(index) || index < 0) return null;
  const [id, city, stadium] = nationsFinalsRotation[index % nationsFinalsRotation.length];
  return { id, city, stadium, status: 'simulated', sources: [] };
}

const neutralLeagueCountries = {
  'Cardiff City Stadium': 'WAL',
  'Hill Dickinson Stadium': 'ENG',
  'Scottish Gas Murrayfield': 'SCO',
  'McDonald Jones Stadium': 'AUS',
};

const citiesByVenue = {
  'Adelaide Oval': 'Adélaïde', 'Brisbane Stadium': 'Brisbane', 'Docklands Stadium': 'Melbourne',
  'Newcastle Stadium': 'Newcastle', 'North Queensland Stadium': 'Townsville',
  'Perth Stadium': 'Perth', 'Stadium Australia': 'Sydney', 'Sydney Football Stadium': 'Sydney',
  'Allianz Stadium, Turin': 'Turin', 'Aviva Stadium': 'Dublin', 'Bluenergy Stadium': 'Udine',
  'Cardiff City Stadium': 'Cardiff', 'Eden Park': 'Auckland', 'Ellis Park': 'Johannesburg',
  'Estadio Mario Alberto Kempes': 'Córdoba', 'Estadio San Juan del Bicentenario': 'San Juan',
  'Estadio Único Madre de Ciudades': 'Santiago del Estero', 'Groupama Stadium': 'Décines-Charpieu',
  'HBF Park': 'Perth', 'Hill Dickinson Stadium': 'Liverpool', 'Hnry Stadium': 'Wellington',
  'Hollywoodbets Kings Park': 'Durban', 'Loftus Versfeld': 'Pretoria',
  'McDonald Jones Stadium': 'Newcastle', 'Melbourne Cricket Ground': 'Melbourne',
  'MUFG Stadium': 'Tokyo', 'One New Zealand Stadium': 'Christchurch',
  'Prince Chichibu Memorial Rugby Ground': 'Tokyo', 'Principality Stadium': 'Cardiff',
  'Queensland Country Bank Stadium': 'Townsville', 'Scottish Gas Murrayfield': 'Édimbourg',
  'Stade de France': 'Saint-Denis', 'Stadio Luigi Ferraris': 'Gênes',
  'Stadio Olimpico': 'Rome', 'Suncorp Stadium': 'Brisbane',
};

function monthsEarlier(date, months) {
  const [year, month, day] = date.split('-').map(Number);
  const target = new Date(Date.UTC(year, month - 1 - months, 1));
  const lastDay = new Date(Date.UTC(target.getUTCFullYear(), target.getUTCMonth() + 1, 0)).getUTCDate();
  target.setUTCDate(Math.min(day, lastDay));
  return target.toISOString().slice(0, 10);
}

function hostDossier(edition) {
  if (!edition?.fixtures?.length) throw new Error('international edition with fixtures required');
  const cup = edition.id.startsWith('rugby-world-cup-');
  const nations = edition.id.startsWith('nations-championship-');
  const finalHost = cup ? worldCupHost(edition.year) : nations ? nationsFinalHost(edition.year) : null;
  const countries = new Map();
  const dates = [];
  let finalDate = null;

  for (const fixture of edition.fixtures) {
    dates.push(fixture.date);
    if (fixture.phase === 'final') finalDate = fixture.date;
    const finalsVenue = cup || (nations && Boolean(fixture.placement));
    const id = finalsVenue ? finalHost.id :
      fixture.neutralVenue ? neutralLeagueCountries[fixture.venue] : fixture.homeId;
    if (!id) continue;
    if (!countries.has(id)) countries.set(id, { matchCount: 0, cities: new Set(), stadiums: new Set() });
    const entry = countries.get(id);
    entry.matchCount++;
    if (fixture.venue) {
      entry.stadiums.add(fixture.venue);
      const city = fixture.venue === finalHost?.stadium && id === finalHost.id ? finalHost.city :
        fixture.venue === 'Allianz Stadium' ? (id === 'AUS' ? 'Sydney' : 'Londres') :
        citiesByVenue[fixture.venue];
      if (city) entry.cities.add(city);
    }
  }

  const finalCountry = finalHost?.id ?? null;
  const countryIds = [...countries.keys()].sort();
  if (finalCountry) {
    countryIds.splice(countryIds.indexOf(finalCountry), 1);
    countryIds.unshift(finalCountry);
  }
  const opens = dates.sort()[0], ends = dates.at(-1);
  const calendarStatus = edition.provenance?.calendarStatus;
  return {
    countries: countryIds.map(id => {
      const entry = countries.get(id);
      const { matchCount } = entry;
      const cities = [...entry.cities].sort();
      const stadiums = [...entry.stadiums].sort();
      const details = [matchCount === 1 ? 'Une rencontre au programme.' : matchCount + ' rencontres au programme.'];
      if (cities.length === 1) details.push(cities[0] + ' figure au calendrier.');
      if (cities.length > 1) details.push('Les villes au calendrier comprennent ' + cities.join(', ') + '.');
      if (id === 'RSA') details.push('Pretoria est la capitale administrative.');
      return { id, name: teamNames[id], capital: capitals[id], details, matchCount, cities, stadiums };
    }),
    finalCountry,
    finalCountryName: teamNames[finalCountry] ?? null,
    city: finalHost?.city ?? null,
    stadium: finalHost?.stadium ?? null,
    opens,
    ends,
    finalDate,
    announcementDate: monthsEarlier(opens, cup ? (edition.year === 2027 ? 12 : 36) : 4),
    officialHostAnnouncementDate: finalHost?.officialHostAnnouncementDate ?? null,
    hostStatus: finalHost?.status ?? (calendarStatus === 'partially-confirmed' ? 'mixed' : calendarStatus ?? 'confirmed'),
    venueStatus: finalHost ? (finalHost.stadium ? finalHost.status : 'pending') : null,
    sources: [...new Set([edition.provenance?.calendar ?? edition.provenance?.cycle, ...(finalHost?.sources ?? []), regulation9]
      .filter(Boolean))],
  };
}

module.exports = { hostDossier, worldCupHost, nationsFinalHost };
