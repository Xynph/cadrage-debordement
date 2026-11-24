#!/usr/bin/env node
// Mesure hebdomadaire de la consommation de tokens (transcripts Claude Code).
// Usage : node scripts/mesure-tokens.cjs [--jours 7] [--dossier <transcripts>]
// Pondération : entrée 1, lecture de cache 0,1, écriture de cache 2, sortie 5.
const fs = require('fs');
const os = require('os');
const path = require('path');
const readline = require('readline');

const W_IN = 1, W_CR = 0.1, W_CW = 2, W_OUT = 5;
const IMG_TOKENS = 1600;
const INSTR = 'Instructions de Claude (relues à chaque tour)';

function argument(nom, defaut) {
  const i = process.argv.indexOf(nom);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : defaut;
}
const jours = parseFloat(argument('--jours', '7'));

function dossierParDefaut() {
  const base = path.join(os.homedir(), '.claude', 'projects');
  if (!fs.existsSync(base)) return null;
  // Dossier = chemin aplati ; un worktree est un sous-dossier du projet, on
  // retient donc le nom le plus long qui soit préfixe du chemin du dépôt.
  const cible = path.resolve(__dirname, '..').replace(/[^A-Za-z0-9]/g, '-');
  let meilleur = null;
  for (const d of fs.readdirSync(base)) {
    if (cible.startsWith(d) && (!meilleur || d.length > meilleur.length)) meilleur = d;
  }
  if (!meilleur) {
    // Repli : dossier du dépôt « Parent--Projet » dont le nom est un préfixe du parent.
    const parent = path.dirname(path.resolve(__dirname, '..')).replace(/[^A-Za-z0-9]/g, '-');
    for (const d of fs.readdirSync(base)) {
      if (parent.startsWith(d) && (!meilleur || d.length > meilleur.length)) meilleur = d;
    }
  }
  return meilleur ? path.join(base, meilleur) : null;
}
const racine = argument('--dossier', dossierParDefaut());
if (!racine || !fs.existsSync(racine)) {
  console.error('Dossier des transcripts introuvable : utiliser --dossier <chemin>.');
  process.exit(1);
}

function categorieShell(cmd) {
  const c = cmd.toLowerCase();
  if (/start-sleep|sleep \d|get-process|wait-process|until |while /.test(c)) return 'Attente / surveillance';
  // « godot » seul apparaît dans les chemins native/godot : on exige un vrai lancement.
  if (/cd_godot_exe|godot[^/\\ ]*\.exe|tempgodot|--headless|match-filme|--import/.test(c)) return 'Lancer Godot / tests du jeu';
  if (/\bgh(\.exe)?\b|\bgit\b/.test(c)) return 'GitHub et git';
  if (/python -|python - <<|\[io\.file\]::writealltext|set-content|out-file|sed -i/.test(c)) return 'Écriture de fichiers';
  return 'Lecture de fichiers';
}
function categorieOutil(nom, inp) {
  if (['Read', 'Grep', 'Glob'].includes(nom)) return 'Lecture de fichiers';
  if (['Edit', 'Write', 'NotebookEdit', 'MultiEdit'].includes(nom)) return 'Écriture de fichiers';
  if (nom === 'Bash' || nom === 'PowerShell') return categorieShell(inp.command || '');
  if (nom === 'Agent' || nom === 'Task') return 'Rapports des sous-agents';
  if (nom === 'WebSearch' || nom === 'WebFetch') return 'Recherche web';
  if (nom.startsWith('mcp__claude-in-chrome__')) return 'Navigateur Chrome';
  if (nom.startsWith('mcp__Claude_Browser__') || nom.startsWith('mcp__computer-use')) return 'Navigateur / écran';
  if (nom.startsWith('mcp__')) return 'Connecteurs';
  return 'Autres outils';
}
function taille(c) { // en caractères ; une image compte ~1600 tokens
  if (typeof c === 'string') return c.length;
  if (Array.isArray(c)) {
    let s = 0;
    for (const b of c) {
      if (b && b.type === 'image') s += IMG_TOKENS * 4;
      else if (b && b.type === 'text') s += (b.text || '').length;
      else s += JSON.stringify(b).length;
    }
    return s;
  }
  return JSON.stringify(c === undefined ? null : c).length;
}
const ajoute = (o, k, v) => { o[k] = (o[k] || 0) + v; };
const somme = (o) => Object.values(o).reduce((a, b) => a + b, 0);

async function analyse(fichier, tot, lus, stats) {
  let ctx = {}, pending = {};
  const outils = new Map(); // id -> {cat, nom, chemin}
  let base = null;
  const rl = readline.createInterface({ input: fs.createReadStream(fichier, { encoding: 'utf8' }), crlfDelay: Infinity });
  for await (const ligne of rl) {
    let d;
    try { d = JSON.parse(ligne); } catch { continue; }
    const t = d.type, m = d.message || {};
    if (t === 'user') {
      const c = m.content;
      if (Array.isArray(c)) {
        for (const b of c) {
          if (b.type === 'tool_result') {
            const o = outils.get(b.tool_use_id);
            const cat = o ? o.cat : 'Autres outils';
            const n = taille(b.content);
            ajoute(ctx, cat, n); ajoute(pending, cat, n);
            if (o && o.nom === 'Read' && o.chemin) {
              let tk = n / 4;
              if (Array.isArray(b.content)) tk = b.content.reduce((a, x) => a + (x && x.type === 'image' ? IMG_TOKENS : taille([x]) / 4), 0);
              const e = lus.get(o.chemin) || { tokens: 0, fois: 0 };
              e.tokens += tk; e.fois++; lus.set(o.chemin, e);
            }
          } else {
            const n = taille([b]);
            ajoute(ctx, 'Messages et consignes', n); ajoute(pending, 'Messages et consignes', n);
          }
        }
      } else {
        const n = taille(c);
        ajoute(ctx, 'Messages et consignes', n); ajoute(pending, 'Messages et consignes', n);
      }
    } else if (t === 'assistant') {
      const u = m.usage || {};
      const inp = u.input_tokens || 0, cr = u.cache_read_input_tokens || 0, cw = u.cache_creation_input_tokens || 0, out = u.output_tokens || 0;
      stats.tours++;
      const totalCtx = inp + cr + cw;
      if (base === null && totalCtx) base = Math.max(0, totalCtx - somme(ctx) / 4);
      const b = base || 0;
      let ksum = 0;
      for (const v of Object.values(ctx)) ksum += v / 4;
      const denom = ksum + b;
      const coutCtx = inp * W_IN + cr * W_CR;
      if (denom > 0) {
        ajoute(tot, INSTR, coutCtx * b / denom);
        for (const [k, v] of Object.entries(ctx)) ajoute(tot, k, coutCtx * (v / 4) / denom);
      }
      const ns = somme(pending);
      if (ns > 0) { for (const [k, v] of Object.entries(pending)) ajoute(tot, k, cw * W_CW * v / ns); }
      else ajoute(tot, INSTR, cw * W_CW);
      pending = {};
      let catSortie = 'Réponses et réflexion de Claude';
      for (const blk of m.content || []) {
        if (blk.type === 'tool_use') {
          const inpt = blk.input || {};
          const cat = categorieOutil(blk.name || '', inpt);
          outils.set(blk.id, { cat, nom: blk.name, chemin: blk.name === 'Read' ? inpt.file_path : null });
          catSortie = cat;
          ajoute(ctx, cat, JSON.stringify(inpt).length);
        } else {
          const n = blk.type === 'thinking' ? (blk.thinking || '').length : taille([blk]);
          ajoute(ctx, 'Réponses et réflexion de Claude', n);
        }
      }
      ajoute(tot, catSortie, out * W_OUT);
    } else if (t === 'summary' || (t === 'system' && d.subtype === 'compact_boundary')) {
      ctx = {};
    }
  }
}

function fichiersSousAgents(dir) {
  const res = [];
  if (!fs.existsSync(dir)) return res;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) res.push(...fichiersSousAgents(p));
    else if (e.name.endsWith('.jsonl')) res.push(p);
  }
  return res;
}

(async () => {
  const coupure = Date.now() - jours * 86400000;
  const principal = {}, sous = {};
  const lus = new Map();
  const stats = { tours: 0 };
  let sessions = 0, agents = 0;
  const fichiers = fs.readdirSync(racine).filter((f) => f.endsWith('.jsonl')).map((f) => path.join(racine, f));
  for (const f of fichiers) {
    if (fs.statSync(f).mtimeMs < coupure) continue;
    sessions++;
    await analyse(f, principal, lus, stats);
    for (const sf of fichiersSousAgents(path.join(racine, path.basename(f, '.jsonl'), 'subagents'))) {
      agents++;
      await analyse(sf, sous, lus, stats);
    }
  }
  const sp = somme(principal), ss = somme(sous), st = sp + ss;
  const M = (v) => (v / 1e6).toFixed(1).padStart(8) + ' M';
  const P = (v, t) => (t ? (100 * v / t).toFixed(1) : '0.0').padStart(5) + ' %';
  const total = { ...principal };
  for (const [k, v] of Object.entries(sous)) ajoute(total, k, v);
  console.log(`Période : ${jours} jours | sessions : ${sessions} | sous-agents : ${agents} | tours : ${stats.tours}`);
  console.log('\nTotal pondéré (équivalent tokens d\'entrée)');
  console.log(`  ${'Principal'.padEnd(46)}${M(sp)} ${P(sp, st)}`);
  console.log(`  ${'Sous-agents'.padEnd(46)}${M(ss)} ${P(ss, st)}`);
  console.log(`  ${'Total'.padEnd(46)}${M(st)}`);
  for (const [nom, dd] of [['Principal', principal], ['Sous-agents', sous], ['Total', total]]) {
    const s = somme(dd);
    console.log(`\n${nom} par catégorie`);
    for (const [k, v] of Object.entries(dd).sort((a, b) => b[1] - a[1])) console.log(`  ${k.padEnd(46)}${M(v)} ${P(v, s)}`);
  }
  console.log('\nTop 10 des fichiers les plus lus (outil Read, tokens estimés)');
  const top = [...lus.entries()].sort((a, b) => b[1].tokens - a[1].tokens).slice(0, 10);
  for (const [p, e] of top) console.log(`  ${String(Math.round(e.tokens)).padStart(9)}  x${String(e.fois).padEnd(4)} ${p}`);
})();
