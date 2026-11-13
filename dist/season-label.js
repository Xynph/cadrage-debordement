'use strict';
// Libellé d'une saison pour l'affichage : « 2026-2027 » pour la saison interne 1, « 2027-2028 » pour la 2, etc.
// Fonction unique (VM du moteur, interface web, processus Node du pont) : le numéro interne `season`
// reste dans les données et la logique, seul l'affichage change. Le jeu commence à la pré-saison
// 2026-2027 : SEASON_START_YEAR est l'année de départ de la saison interne 1.
const SEASON_START_YEAR=2026;
function libelleSaison(season,startYear=SEASON_START_YEAR){const n=Number(season);if(season===null||season===undefined||season===''||!Number.isInteger(n)||n<1||n>7973)return '—';return (startYear+n-1)+'-'+(startYear+n)}
if(typeof module!=='undefined'&&module.exports)module.exports={libelleSaison,SEASON_START_YEAR};
