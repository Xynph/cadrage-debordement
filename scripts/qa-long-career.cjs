#!/usr/bin/env node
'use strict';
// Executes the native engine, never substitutes match scores or injects cash.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {write} = require('./qa-long-career-report.cjs');
const ROOT = path.resolve(__dirname, '..');
const digest = value => crypto.createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex');
function sourceDigest() {
 const hash = crypto.createHash('sha256');
 for (const folder of ['native/engine', 'dist']) {
  for (const name of fs.readdirSync(path.join(ROOT, folder)).sort()) {
   const file = path.join(ROOT, folder, name);
   if (!/\.(cjs|js|json)$/.test(name) || !fs.statSync(file).isFile()) continue;
   hash.update(folder + '/' + name + '\0'); hash.update(fs.readFileSync(file));
  }
 }
 return hash.digest('hex');
}

class Campaign {
 constructor(id, name, scope) { Object.assign(this, {id, name, scope, status:'running', checks:0, checkpoints:[], failures:[], durationMs:0}); }
 check(value, name, detail = '') {
  this.checks++;
  if (!value) {
   const error = new Error(detail || name);
   error.check = name;
   throw error;
  }
 }
 checkpoint(label, value, counts = {}) {
  const text = JSON.stringify(value);
  this.checkpoints.push({label, sha256:digest(text), bytes:Buffer.byteLength(text), ...counts});
  console.log(`[${this.id}] ${label} : ${counts.results ?? 0} résultats, empreinte ${digest(text).slice(0, 12)}`);
  if (this.onCheckpoint) this.onCheckpoint();
 }
}

function unique(values) { return new Set(values).size === values.length; }
function auditState(campaign, state, previous = null) {
 campaign.check(Number.isInteger(state.season) && state.season >= 1, 'Saison native valide');
 campaign.check(Array.isArray(state.clubs) && state.clubs.length > 0, 'Clubs présents');
 const players = state.clubs.flatMap(club => club.players);
 campaign.check(unique(players.map(player => player.id)), 'Identifiants professionnels uniques');
 campaign.check(state.clubs.every(club => Number.isFinite(club.cash)), 'Trésoreries finies');
 campaign.check(players.every(player => Number.isFinite(player.salary) && player.salary >= 0), 'Salaires structurés');
 const fixtureIds = state.history.filter(result => result.fixtureId).map(result => result.fixtureId);
 campaign.check(unique(fixtureIds), 'Résultats de rencontre sans doublon');
 if (previous) campaign.check(state.season > previous.season || state.season === previous.season && state.round >= previous.round,
  'Progression monotone saison / journée');
 return {season:state.season, players:players.length, results:state.history.length};
}

async function clubCampaign(campaign, options, profiles) {
 const {createBridge} = require('../native/engine/worker.cjs');
 const bridgeOptions = {dataDir:path.join(profiles, campaign.id), seed:options.seed, now:1794315600000, mandatoryPress:true};
 let bridge = createBridge(bridgeOptions), requestId = 0, model, previous = null, played = 0;
 const good = (command, payload = {}) => {
  const result = bridge.handle({id:++requestId, command, payload});
  campaign.check(result.ok, 'Commande ' + command, `${command} : ${result.error || 'refus'} (S${model?.meta.season ?? '?'} / ${model?.meta.week ?? '?'})`);
  model = result.model;
  return model;
 };
 const exported = () => good('export').meta.exportText;
 const press = () => {
  const conference = model.clubLife?.press?.conference;
  if (conference?.required) good('press_conference', {context:model.clubLife.press.context,
   invitationId:conference.invitationId,
   answers:conference.questions.map(question => ({questionId:question.id, answerId:question.answers[0].id}))});
 };
 const checkpoint = label => {
  const text = exported(), state = JSON.parse(text).state;
  const counts = auditState(campaign, state, previous);
  previous = {season:state.season, round:state.round};
  const beforeRng = fs.readFileSync(path.join(model.meta.dataDir, 'donnees.json'), 'utf8');
  good('import', {text});
  campaign.check(digest(JSON.parse(exported()).state) === digest(state), 'Import conserve exactement l’état sportif');
  // Reload the real on-disk document, not an in-memory copy of the campaign.
  good('shutdown'); bridge.close(); bridge = createBridge(bridgeOptions);
  good('snapshot');
  campaign.check(digest(JSON.parse(exported()).state) === digest(state), 'Redémarrage conserve exactement l’état sportif');
  const disk = JSON.parse(beforeRng), reopened = JSON.parse(fs.readFileSync(path.join(model.meta.dataDir, 'donnees.json'), 'utf8'));
  campaign.check(disk.seed === reopened.seed, 'Import et reprise conservent le curseur RNG');
  campaign.checkpoint(label, state, {...counts, date:model.meta.calendarToday ?? null, cash:model.finance.cash, played});
 };
 try {
  good('new_career', {mode:'common', club:29});
  checkpoint('Ouverture');
  for (let season = 1; season <= options.seasons; season++) {
   let guard = 0;
   while (!model.meta.canAdvanceSeason) {
    campaign.check(++guard <= 60, 'La saison se termine dans la borne de journées');
    press();
    if (model.next) {
     if (!model.selection.valid) good('auto_lineup');
     if (!model.selection.valid) good('promote_cover', {confirmed:true, expectedSlots:model.selection.coverage?.slots});
     campaign.check(model.selection.valid, 'Feuille autorisée avant le match');
     good('begin_match'); good('delegate'); played++;
    }
    good('finish_round');
    if (guard === 17) checkpoint('Saison ' + season + ' · mi-parcours');
   }
   checkpoint('Saison ' + season + ' · clôture');
   if (season < options.seasons) {
    press(); good('next_season', {confirmed:true});
    campaign.check(model.meta.season === season + 1, 'Transition vers la saison suivante');
    checkpoint('Saison ' + (season + 1) + ' · ouverture');
   }
  }
  campaign.note = `${options.seasons} saisons de club via le worker réel, ${played} matchs du club délégués ; calendrier hebdomadaire, presse obligatoire. Aucun achat ni injection financière.`;
 } finally { bridge.close(); }
}

function internationalCampaign(campaign, options) {
 const competitions = require('../native/engine/international-competitions.cjs');
 const callups = require('../native/engine/international-callups.cjs');
 const facts = require('../native/engine/player-real-facts.json');
 const registry = require('../native/engine/world-registry.json');
 const {createInternationalCareer} = require('../native/engine/international-career.cjs');
 const players = registry.clubs.flatMap(club => club.players);
 const own = registry.clubs[0].players.map(player => player.id);
 const career = createInternationalCareer(competitions, callups, facts);
 let state = career.initial('2026-08-17', options.seed);
 const mailIds = new Set(), kinds = {}, resultIds = new Set();
 const advance = to => {
  const before = state.date;
  const result = career.advance(state, {from:state.date, to, players, managedNation:null, clubPlayerIds:own});
  state = result.state;
  campaign.check(state.date >= before && state.date === to, 'Date internationale monotone');
  for (const item of result.mail) {
   campaign.check(!mailIds.has(item.id), 'Courrier international unique', 'Courrier répété : ' + item.id);
   mailIds.add(item.id); kinds[item.kind] = (kinds[item.kind] || 0) + 1;
  }
  campaign.check(career.validate(state), 'Historique international validé par le moteur');
  campaign.check(unique(state.callups.map(camp => [camp.competitionId, camp.nation, camp.from].join('/'))), 'Convocations uniques');
  campaign.check(state.callups.every(camp => unique(camp.playerIds)), 'Joueurs uniques par convocation');
  campaign.check(unique(state.appearances.map(row => [row.fixtureId, row.nation].join('/'))), 'Participations internationales uniques');
  const sameDay = career.advance(state, {from:state.date, to:state.date, players, clubPlayerIds:own});
  campaign.check(sameDay.mail.length === 0 && digest(sameDay.state) === digest(state), 'Même date sans nouveau courrier ni mutation');
 };
 campaign.checkpoint('Ouverture · 2026', state, {date:state.date, players:players.length, results:0, mail:0});
 for (let year = 2026; year <= options.throughYear; year++) {
  // Season and calendar boundaries, including finals and the 2031 World Cup.
  for (const month of ['03-31','07-31','11-30','12-31']) {
   const date = `${year}-${month}`;
   if (date <= state.date) continue;
   advance(date);
  }
  const before = digest(state), restored = JSON.parse(JSON.stringify(state));
  campaign.check(career.validate(restored) && digest(restored) === before, 'Checkpoint international restauré sans perte');
  state = restored;
  for (const [yearKey, results] of Object.entries(state.results)) for (const id of Object.keys(results)) resultIds.add(yearKey + '/' + id);
  campaign.checkpoint('Fin ' + year, state, {date:state.date, players:players.length, results:resultIds.size, mail:mailIds.size});
 }
 campaign.check((kinds.international_host || 0) > 0, 'Des annonces de prochains hôtes ont été produites');
 campaign.check((kinds.international_callup || 0) > 0, 'Des convocations du club ont été produites');
 if (options.throughYear >= 2031) {
  const cup = career.project(state, {players}).competitions.find(edition => edition.id === 'rugby-world-cup-2031');
  campaign.check(cup?.outcome.complete, 'Mondial 2031 terminé');
 }
 campaign.note = `Module international de production, registre mondial de ${players.length} joueurs, années 2026–${options.throughYear}. ${resultIds.size} résultats observés, ${mailIds.size} courriers. Reprise JSON du module uniquement ; ce scénario ne simule pas une carrière complète de club ni des clics UI.`;
 campaign.mailKinds = kinds;
}

function parseArgs(args) {
 const options = {seed:713492, seasons:3, throughYear:2031, campaign:'all'};
 for (let i=0; i<args.length; i++) {
  const key = args[i], value = args[++i];
  if (key === '--output' && value) options.output = path.resolve(value);
  else if (key === '--seasons' && /^[1-5]$/.test(value)) options.seasons = Number(value);
  else if (key === '--through-year' && /^(202[7-9]|203[01])$/.test(value)) options.throughYear = Number(value);
  else if (key === '--seed' && /^(0|[1-9]\d*)$/.test(value) && Number(value) <= 0xffffffff) options.seed = Number(value);
  else if (key === '--campaign' && ['all','club','international'].includes(value)) options.campaign = value;
  else throw Error('Argument invalide : ' + key + '. Options : --output DOSSIER --seasons 1..5 --through-year 2027..2031 --seed UINT32 --campaign all|club|international');
 }
 return options;
}

async function run(options) {
 const start = Date.now(), profileRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-long-career-profiles-'));
 const output = options.output || fs.mkdtempSync(path.join(os.tmpdir(), 'oval-long-career-report-'));
 const git = args => execFileSync('git', args, {cwd:ROOT, encoding:'utf8'}).trim();
 const report = {format:'oval-long-career-audit', version:1, seed:options.seed, source:{commit:git(['rev-parse','HEAD']), engineSha256:sourceDigest(), dirty:Boolean(git(['status','--porcelain','--untracked-files=no'])), node:process.version, platform:process.platform}, startedAt:new Date(start).toISOString(), profileRoot, command:`node scripts/qa-long-career.cjs --seasons ${options.seasons} --through-year ${options.throughYear} --seed ${options.seed} --campaign ${options.campaign} --output ${output}`, status:'running', durationMs:0, campaigns:[], limits:[
  'Carrières de recette uniquement : aucun profil personnel lu ou modifié. Trésoreries du jeu fictives.',
  'Contrôles structurels et reprises : ni certification réglementaire, ni mesure de l’équilibrage ou de la performance GPU.',
  'Club : worker complet en cadence hebdomadaire avec conférences obligatoires. Les journées quotidiennes et autres championnats ne sont pas couverts par cette campagne.',
  'International : module natif et catalogue livré, simulations automatiques ; pas une carrière complète de sélectionneur et pas de recette UI.',
  'Une seule graine et un club ne démontrent pas la robustesse de toutes les trajectoires possibles. Un échec stoppe la campagne concernée et reste rouge.'
 ]};
 const definitions = [
  ['club', 'Club · Accession française', 'Worker complet · trois saisons par défaut · presse obligatoire · vrais exports/imports et redémarrages', () => clubCampaign(report.campaigns.at(-1), options, profileRoot)],
  ['international', 'International · jusqu’au Mondial 2031', 'Module de carrière natif · fenêtres, convocations, résultats, annonces et archives', () => internationalCampaign(report.campaigns.at(-1), options)]
 ];
 for (const [id, name, scope, execute] of definitions) {
  if (options.campaign !== 'all' && options.campaign !== id) continue;
  const campaign = new Campaign(id, name, scope), began = Date.now(); report.campaigns.push(campaign);
  campaign.onCheckpoint = () => { campaign.durationMs = Date.now() - began; report.durationMs = Date.now() - start; write(report, output); };
  try { await execute(); campaign.status = 'passed'; }
  catch (error) {
   campaign.status = 'failed'; campaign.failures.push({check:error.check || 'Exécution native', message:error.message, nextAction:`Rejouer la campagne ${id} avec la graine ${options.seed}, à partir du dernier checkpoint reçu. Corriger la cause native avant de déclarer la campagne reçue.`});
  }
  campaign.durationMs = Date.now() - began;
  console.log(`${campaign.name}: ${campaign.status}, ${campaign.checks} contrôles, ${campaign.checkpoints.length} checkpoints, ${campaign.durationMs} ms`);
  report.durationMs = Date.now() - start; write(report, output);
 }
 report.status = report.campaigns.every(campaign => campaign.status === 'passed') ? 'passed' : 'failed';
 report.durationMs = Date.now() - start; write(report, output);
 console.log('Rapport : ' + path.join(output, 'index.html'));
 return report;
}
if (require.main === module) run(parseArgs(process.argv.slice(2))).then(report => {process.exitCode = report.status === 'passed' ? 0 : 1;}).catch(error => {console.error(error.message); process.exitCode = 1;});
module.exports = {Campaign, unique, auditState, parseArgs, run};
