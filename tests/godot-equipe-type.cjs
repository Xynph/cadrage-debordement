'use strict';
// XV type dans le vrai jeu Godot : « XV de la journée » et « XV de la saison », quinze cartes, entrées
// depuis l'actualité (vignette) et Compétitions ; écusson du jeu sans pack, logo du pack avec pack.
// Le profil est préparé par le vrai moteur (quelques journées déléguées) ; l'équipe de la saison
// (une saison complète prend plus d'un quart d'heure) est posée par un import signé à partir de l'équipe
// de la journée, et deux joueurs du club du manager sont glissés dans le XV pour contrôler le liseré.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), crypto = require('node:crypto');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');
const POSTES = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne', 'Troisième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière'];

function signe(document, change) { const doc = structuredClone(document); change(doc.state); const text = JSON.stringify(doc.state); let h = 2166136261; for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619); doc.checksum = (h >>> 0).toString(16).padStart(8, '0'); return JSON.stringify(doc); }

function preparer(profil, { journees = 4, fixture = null, pack = false } = {}) {
  const bridge = createBridge({ dataDir: profil, seed: 4242, now: 1794315600000 });
  let id = 0, model;
  const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); model = r.model; return model; };
  try {
    if (fixture) call('new_career', { mode: 'common', club: 29 });
    else {
      call('new_career', { mode: 'common', club: 29 });
      for (let j = 0, garde = 0; j < journees && garde < 40; garde++) {
        model = settleClubMeetings(model, call) || model;
        if (model.next) {
          if (!model.selection.valid) call('auto_lineup');
          model = skipMatchTalk(call('begin_match'), call);
          call('delegate'); j++;
          model = skipMatchTalk(model, call);
          model = settleClubMeetings(model, call) || model;
        }
        const r = bridge.handle({ id: ++id, command: 'finish_round', payload: {} });
        if (r.ok) model = r.model;
      }
    }
    const doc = JSON.parse(fixture ? fs.readFileSync(fixture, 'utf8') : call('export').meta.exportText);
    const texte = signe(doc, s => {
      const st = s.matchNotes, mon = s.club;
      const choisir = (pos, sauf) => s.clubs[mon].players.find(p => p.pos === pos && !sauf.includes(p.id));
      for (const [lg, eq] of Object.entries(st.equipes)) {
        if (lg !== 'accession') continue;
        const pris = [...eq.ids];
        for (const k of [3, 10, 8]) { const p = choisir(POSTES[k], pris); if (p) { eq.ids[k] = p.id; eq.clubs[k] = mon; } }
      }
      if (!fixture) for (const [lg, eq] of Object.entries(st.equipes)) {
        st.saisons.push({ saison: s.season, ligue: lg, ids: eq.ids.slice(), moy: eq.notes.map(n => Math.max(55, n - 6)), matchs: eq.ids.map((_, k) => 14 + (k % 5)), sel: eq.ids.map((_, k) => k % 4), clubs: eq.clubs.slice(), journees: 20 });
      } else for (const f of st.saisons) if (f.ligue === 'accession') { const pris = [...f.ids]; for (const k of [3, 10]) { const p = choisir(POSTES[k], pris); if (p) { f.ids[k] = p.id; f.clubs[k] = mon; } } }
    });
    call('import', { text: texte });
    if (pack) {
      const media = require('../native/engine/media-packs.cjs'), db = require('../dist/rugby-common-rosters.js'), zlib = require('node:zlib');
      const morceau = (type, data) => { const t = Buffer.from(type), l = Buffer.alloc(4), c = Buffer.alloc(4); l.writeUInt32BE(data.length); c.writeUInt32BE(media.crc32(Buffer.concat([t, data])) >>> 0); return Buffer.concat([l, t, data, c]); };
      const entete = Buffer.alloc(13); entete.writeUInt32BE(8, 0); entete.writeUInt32BE(8, 4); entete[8] = 8; entete[9] = 2;
      const lignes = Buffer.concat(Array.from({ length: 8 }, () => Buffer.concat([Buffer.from([0]), Buffer.alloc(24, 0xc8)])));
      const pixel = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), morceau('IHDR', entete), morceau('IDAT', zlib.deflateSync(lignes)), morceau('IEND', Buffer.alloc(0))]);
      const zip = items => { let offset = 0; const locals = [], centrals = []; for (const item of items) { const n = Buffer.from(item.name), data = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data || ''), crc = media.crc32(data), local = Buffer.alloc(30), central = Buffer.alloc(46); local.writeUInt32LE(0x04034b50); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x800, 6); local.writeUInt32LE(crc, 14); local.writeUInt32LE(data.length, 18); local.writeUInt32LE(data.length, 22); local.writeUInt16LE(n.length, 26); central.writeUInt32LE(0x02014b50); central.writeUInt16LE(0x314, 4); central.writeUInt16LE(20, 6); central.writeUInt16LE(0x800, 8); central.writeUInt32LE(crc, 16); central.writeUInt32LE(data.length, 20); central.writeUInt32LE(data.length, 24); central.writeUInt16LE(n.length, 28); central.writeUInt32LE((0x81a4 * 65536) >>> 0, 38); central.writeUInt32LE(offset, 42); locals.push(local, n, data); centrals.push(central, n); offset += local.length + n.length + data.length; } const cd = Buffer.concat(centrals), end = Buffer.alloc(22); end.writeUInt32LE(0x06054b50); end.writeUInt16LE(items.length, 8); end.writeUInt16LE(items.length, 10); end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16); return Buffer.concat([...locals, cd, end]); };
      const manifest = { schema: 'cd-identity-pack-v1', id: 'essai-xv', name: 'Identités test', version: '1', databaseId: db.id, rightsStatus: 'test-local', clubs: Array.from({ length: 30 }, (_, i) => ({ id: i, logo: 'image' })), players: [], assets: [{ id: 'image', path: 'médias/image.png', sha256: crypto.createHash('sha256').update(pixel).digest('hex'), bytes: pixel.length }] };
      const fichier = path.join(os.tmpdir(), 'rl27-xv-godot-pack-' + process.pid + '.zip');
      fs.writeFileSync(fichier, zip([{ name: 'pack.json', data: JSON.stringify(manifest) }, { name: 'médias/image.png', data: pixel }]));
      try { const apercu = call('pack_inspect', { path: fichier }).packs.preview; call('pack_install', { path: fichier, digest: apercu.digest }); call('pack_select', { id: apercu.id, scope: 'career' }); } finally { fs.rmSync(fichier, { force: true }); }
    }
    call('save');
    return model;
  } finally { bridge.close(); }
}

function lancer(profil, sortie, env) {
  const graphique = process.env.CD_EQUIPE_GRAPHICS === '1';
  const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-equipe-type.gd')];
  const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
  const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
  const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_EQUIPE_OUTPUT: sortie, ...env } });
  const journal = (r.stdout || '') + (r.stderr || '');
  if (r.error) throw r.error;
  assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
  assert.equal(r.status, 0, journal.slice(-3000));
  const ligne = journal.split('\n').find(l => l.startsWith('EQUIPE_TYPE '));
  assert.ok(ligne, 'rapport Godot');
  const rapport = JSON.parse(ligne.slice('EQUIPE_TYPE '.length));
  assert.deepEqual(rapport.failures, []);
  return rapport;
}

test('XV type : journée et saison dans le vrai jeu, écusson du jeu sans pack, logo avec pack', { skip: !godot && 'SDK Godot requis' }, () => {
  const sortie = process.env.CD_EQUIPE_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-xv-ui-'));
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-xv-base-')), avecPack = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-xv-pack-'));
  fs.mkdirSync(sortie, { recursive: true });
  try {
    const fixture = process.env.CD_EQUIPE_FIXTURE || null;
    preparer(base, { fixture });
    const a = lancer(base, sortie, { CD_EQUIPE_PACK: '0', CD_EQUIPE_CAPTURE: '1' });
    preparer(avecPack, { journees: 2, pack: true });
    const b = lancer(avecPack, sortie, { CD_EQUIPE_PACK: '1', CD_EQUIPE_CAPTURE: '0' });
    console.log('XV type (Godot) : ' + JSON.stringify(a.mesures) + ' · pack : ' + JSON.stringify(b.mesures) + ' · captures : ' + sortie);
  } finally { fs.rmSync(base, { recursive: true, force: true }); fs.rmSync(avecPack, { recursive: true, force: true }); }
});
