'use strict';
// Journal d'actions de la carrière (docs/sauvegarde-journal-20261116.md).
//
// Le profil complet (`donnees.json`, ~23 Mo) n'est plus réécrit à chaque décision : chaque commande qui modifie la
// carrière ajoute une ligne de quelques centaines d'octets à `journal-actions.jsonl`, synchronisée sur disque avant
// la réponse. La sauvegarde complète suit la fréquence choisie dans les Réglages (jour, semaine, mois), la fermeture
// et « Sauvegarder ». Au chargement, les lignes postérieures à la dernière sauvegarde complète sont rejouées : le
// moteur est déterministe (graine, horloge et paramètres enregistrés par ligne).
//
// Format (une valeur JSON par ligne, terminée par « \n ») :
//   {"journal":1,"base":"<sha256 du donnees.json auquel le journal s'applique>"}          en-tête
//   {"c":"set_tactics","p":{…},"k":<horloge>,"s":<graine avant>,"e":<graine après>}       action
//   {"publication":"<sha256>"}                                                            sauvegarde complète en cours
// La marque « publication » est écrite avant le renommage du nouveau profil : si l'application s'arrête entre ce
// renommage et la remise à zéro du journal, les actions qui précèdent la marque sont déjà dans le profil publié.
// Une dernière ligne incomplète (coupure pendant l'ajout) n'a jamais été confirmée au joueur : elle est ignorée.
const fs = require('node:fs');
const path = require('node:path');
const { createHash, randomUUID } = require('node:crypto');

const FILE = 'journal-actions.jsonl';
const POLICIES = Object.freeze(['jour', 'semaine', 'mois']);
// « Chaque semaine » par défaut : la semaine est l'unité du rugby (un match, une clôture) ; le journal protège déjà
// chaque décision, la fréquence ne borne que le temps de reprise au chargement (au plus une semaine à rejouer).
const DEFAULT_POLICY = 'semaine';
const PREFERENCES_FILE = 'interface.json';
const PREFERENCES_MAX_BYTES = 16 * 1024;

const sha256 = data => createHash('sha256').update(data).digest('hex');

function fsyncFile(target) {
  const fd = fs.openSync(target, 'r+');
  try { fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
}

// Fréquence de la sauvegarde complète : option du moteur (tests, CD_SAUVEGARDE_AUTO), sinon préférence « autosave »
// du fichier d'interface que Godot tient dans le même dossier de profil. Fichier absent ou valeur inconnue : défaut
// (Godot signale lui-même une préférence illisible).
function readPolicy(dataDir, override) {
  if (POLICIES.includes(override)) return override;
  try {
    const file = path.join(dataDir, PREFERENCES_FILE);
    if (fs.statSync(file).size > PREFERENCES_MAX_BYTES) return DEFAULT_POLICY;
    const value = JSON.parse(fs.readFileSync(file, 'utf8'))?.autosave;
    return POLICIES.includes(value) ? value : DEFAULT_POLICY;
  } catch { return DEFAULT_POLICY; }
}

// Lundi de la semaine d'une date ISO (AAAA-MM-JJ), en UTC.
function monday(iso) {
  const t = Date.parse(iso + 'T00:00:00Z');
  if (!Number.isFinite(t)) return iso;
  const day = (new Date(t).getUTCDay() + 6) % 7;
  return new Date(t - day * 86400000).toISOString().slice(0, 10);
}

// Une sauvegarde complète est-elle due ? `last` et `now` : {date: 'AAAA-MM-JJ'|null, season, round}.
function due(policy, last, now) {
  if (!last || !now) return false;
  if (last.date && now.date) {
    if (policy === 'jour') return now.date !== last.date;
    if (policy === 'mois') return now.date.slice(0, 7) !== last.date.slice(0, 7);
    return monday(now.date) !== monday(last.date);
  }
  // Cadence hebdomadaire sans date de calendrier : la journée de championnat sert de semaine.
  if (now.season !== last.season) return true;
  if (policy === 'mois') return Math.floor((now.round ?? 0) / 4) !== Math.floor((last.round ?? 0) / 4);
  return now.round !== last.round;
}

function createJournal(dataDir) {
  const file = path.join(dataDir, FILE);
  let entries = 0;
  const exists = () => fs.existsSync(file);
  const size = () => { try { return fs.statSync(file).size; } catch { return 0; } };
  function writeWhole(lines) {
    const temp = path.join(dataDir, 'journal-actions.tmp-' + randomUUID());
    const fd = fs.openSync(temp, 'wx');
    try { fs.writeFileSync(fd, lines.map(line => JSON.stringify(line) + '\n').join('')); fs.fsyncSync(fd); }
    catch (error) { fs.closeSync(fd); try { fs.unlinkSync(temp); } catch {} throw error; }
    fs.closeSync(fd);
    try { fs.renameSync(temp, file); } catch (error) { try { fs.unlinkSync(temp); } catch {} throw error; }
  }
  function appendLine(value) {
    const fd = fs.openSync(file, 'a');
    try { fs.writeFileSync(fd, JSON.stringify(value) + '\n'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  }
  // Nouveau journal vide, lié au profil publié `base` (remplacement atomique).
  function reset(base, kept = []) { writeWhole([{ journal: 1, base }, ...kept]); entries = kept.length; }
  function append(entry) {
    if (!exists()) throw Error('Journal d’actions introuvable : la dernière sauvegarde complète ne l’a pas créé.');
    appendLine(entry); entries++;
  }
  function markPublication(sha) { if (exists()) appendLine({ publication: sha }); }
  // Annule les lignes ajoutées depuis `offset` (avance refusée après coup : la carrière revient à son départ).
  function truncate(offset, count) {
    if (!exists() || size() <= offset) return;
    fs.truncateSync(file, offset); fsyncFile(file); entries = count;
  }
  // Conserve le journal tel quel sous un autre nom (jamais supprimé) ; renvoie le nom donné.
  function preserve(reason) {
    if (!exists()) return null;
    const target = path.join(dataDir, 'journal-' + reason + '-' + randomUUID() + '.jsonl');
    fs.renameSync(file, target);
    entries = 0;
    return path.basename(target);
  }
  // Lecture au chargement : actions à rejouer sur le profil d'empreinte `current`.
  // Renvoie {status:'absent'|'vide'|'rejouer'|'etranger'|'illisible', actions, torn, published}.
  function read(current) {
    if (!exists()) return { status: 'absent', actions: [] };
    const text = fs.readFileSync(file, 'utf8');
    // Dernière ligne sans « \n » : coupée pendant l'ajout, jamais confirmée au joueur, ignorée.
    const raw = text.split('\n');
    const torn = raw.pop() !== '';
    const lines = [];
    for (let i = 0; i < raw.length; i++) {
      try { lines.push(JSON.parse(raw[i])); } catch { return { status: 'illisible', actions: [], line: i + 1 }; }
    }
    const header = lines[0];
    if (!header || header.journal !== 1 || typeof header.base !== 'string') return { status: 'illisible', actions: [], line: 1 };
    let start = -1, published = false;
    for (let i = lines.length - 1; i > 0; i--) if (lines[i]?.publication === current) { start = i; published = true; break; }
    if (start < 0) {
      if (header.base !== current) {
        const actions = lines.slice(1).filter(line => line && typeof line.c === 'string');
        return { status: actions.length ? 'etranger' : 'vide', actions: [] };
      }
      start = 0;
    }
    const actions = [];
    for (const line of lines.slice(start + 1)) {
      if (line && typeof line.publication === 'string') continue;
      if (!line || typeof line.c !== 'string' || !Number.isFinite(line.k) || !Number.isInteger(line.s) || !Number.isInteger(line.e)) return { status: 'illisible', actions: [], line: lines.indexOf(line) + 1 };
      actions.push(line);
    }
    entries = actions.length;
    return { status: actions.length ? 'rejouer' : 'vide', actions, torn, published };
  }
  return { file, reset, append, markPublication, truncate, preserve, read, size, exists, count: () => entries };
}

module.exports = { FILE, POLICIES, DEFAULT_POLICY, createJournal, readPolicy, due, monday, sha256 };
