#!/usr/bin/env node
// Carte du code GDScript : sommaire d'un fichier, recherche avec fonction englobante, plus gros fichiers.
// Sans dépendance. Sert à filtrer AVANT de lire (Read offset/limit sur la plage trouvée).
//   node scripts/carte-code.cjs <fichier.gd>               sommaire (func + lignes début-fin)
//   node scripts/carte-code.cjs --cherche <motif> [dossier] occurrences + fonction englobante (40 max)
//   node scripts/carte-code.cjs --gros [n]                  les n plus gros .gd
const fs = require("fs");
const path = require("path");

const RACINE = path.resolve(__dirname, "..");
const DOSSIER_DEFAUT = path.join(RACINE, "native", "godot");
const MAX_RESULTATS = 40;
const MAX_LIGNE = 160;

function lire(fichier) {
  return fs.readFileSync(fichier, "utf8").replace(/^﻿/, "").split(/\r?\n/);
}

function joli(fichier) {
  const rel = path.relative(process.cwd(), fichier).replace(/\\/g, "/");
  return rel.startsWith("..") ? fichier.replace(/\\/g, "/") : rel;
}

function tronque(texte, max) {
  return texte.length > max ? texte.slice(0, max - 1) + "…" : texte;
}

const RE_FUNC = /^(?:static\s+)?func\s+([A-Za-z_]\w*)/;
const RE_CLASSE = /^class\s+([A-Za-z_]\w*)/;

// Analyse : fonctions de haut niveau (colonne 0) avec début et fin (1-indexés).
function analyser(lignes) {
  const debuts = [];
  lignes.forEach((l, i) => {
    const m = RE_FUNC.exec(l) || RE_CLASSE.exec(l);
    if (m) debuts.push({ nom: m[1], debut: i + 1, classe: l.startsWith("class ") });
  });
  const total = lignes.length;
  debuts.forEach((f, k) => {
    let limite = k + 1 < debuts.length ? debuts[k + 1].debut - 1 : total;
    // Retire blancs et commentaires de colonne 0 (docstring de la func suivante) en fin de plage.
    while (limite > f.debut && (/^\s*$/.test(lignes[limite - 1]) || /^#/.test(lignes[limite - 1]))) limite--;
    f.fin = limite;
  });
  return debuts;
}

function sommaire(fichier) {
  const lignes = lire(fichier);
  const funcs = analyser(lignes);
  const sortie = [];
  const octets = fs.statSync(fichier).size;
  sortie.push(`${joli(fichier)} — ${lignes.length} lignes, ${(octets / 1024).toFixed(0)} Ko, ${funcs.filter((f) => !f.classe).length} func`);
  const premiere = funcs.length ? funcs[0].debut : lignes.length + 1;
  lignes.forEach((l, i) => {
    const n = i + 1;
    let m;
    if ((m = /^class_name\s+(\w+)/.exec(l))) sortie.push(`${n}: class_name ${m[1]}`);
    else if (/^extends\s/.test(l)) sortie.push(`${n}: ${tronque(l.trim(), 80)}`);
    else if (/^signal\s/.test(l)) sortie.push(`${n}: ${tronque(l.trim(), 100)}`);
    else if (/^(?:const|enum)\s/.test(l) && !/preload\(/.test(l)) sortie.push(`${n}: ${tronque(l.trim(), 90)}`);
    else if (/^#\s*[=\-]{3,}\s*\S/.test(l)) sortie.push(`${n}: ${tronque(l.replace(/^#\s*[=\-]+\s*/, "# ").replace(/\s*[=\-]{3,}\s*$/, ""), 100)}`);
    else if (n < premiere && /^## /.test(l) && n <= 3) sortie.push(`${n}: ${tronque(l, 110)}`);
    else {
      const f = funcs.find((x) => x.debut === n);
      if (f) {
        const sig = l.replace(/\s*:\s*$/, "").replace(/^static\s+/, "static ");
        sortie.push(`${n}-${f.fin}: ${tronque(sig, 110)}`);
      }
    }
  });
  const consts = lignes.filter((l) => /^const\s.*preload\(/.test(l)).length;
  if (consts) sortie.push(`(${consts} const preload non listés)`);
  return sortie.join("\n");
}

function fichiersGd(dossier) {
  const out = [];
  const pile = [dossier];
  while (pile.length) {
    const d = pile.pop();
    let entrees;
    try { entrees = fs.readdirSync(d, { withFileTypes: true }); } catch { continue; }
    for (const e of entrees) {
      if (e.name === ".git" || e.name === ".godot" || e.name === "node_modules") continue;
      const p = path.join(d, e.name);
      if (e.isDirectory()) pile.push(p);
      else if (e.name.endsWith(".gd")) out.push(p);
    }
  }
  return out.sort();
}

function cherche(motif, dossier) {
  let re;
  try { re = new RegExp(motif, "i"); } catch { re = new RegExp(motif.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i"); }
  const base = dossier ? path.resolve(dossier) : DOSSIER_DEFAUT;
  const cible = fs.existsSync(base) && fs.statSync(base).isFile() ? [base] : fichiersGd(base);
  let total = 0;
  const sortie = [];
  for (const f of cible) {
    const lignes = lire(f);
    let funcs = null;
    lignes.forEach((l, i) => {
      if (!re.test(l)) return;
      total++;
      if (sortie.length >= MAX_RESULTATS) return;
      funcs = funcs || analyser(lignes);
      const n = i + 1;
      const f2 = funcs.filter((x) => x.debut <= n).pop();
      const dans = f2 && n <= f2.fin + 0 ? f2.nom : f2 ? f2.nom + "?" : "(haut de fichier)";
      sortie.push(`${joli(f)}:${n} [${dans}] ${tronque(l.trim(), MAX_LIGNE)}`);
    });
  }
  sortie.push(total > MAX_RESULTATS ? `-- ${total} occurrences, ${MAX_RESULTATS} affichées : affiner le motif ou le dossier` : `-- ${total} occurrence(s)`);
  return sortie.join("\n");
}

function gros(n) {
  const liste = fichiersGd(DOSSIER_DEFAUT).map((f) => ({ f, o: fs.statSync(f).size }));
  liste.sort((a, b) => b.o - a.o);
  const sortie = liste.slice(0, n).map((x) => {
    const nf = analyser(lire(x.f)).filter((y) => !y.classe).length;
    return `${String(Math.round(x.o / 1024)).padStart(4)} Ko  ${String(nf).padStart(4)} func  ${joli(x.f)}`;
  });
  sortie.push(`-- ${liste.length} fichiers .gd, ${(liste.reduce((s, x) => s + x.o, 0) / 1048576).toFixed(1)} Mo`);
  return sortie.join("\n");
}

function aide() {
  return [
    "usage : node scripts/carte-code.cjs <fichier.gd>",
    "        node scripts/carte-code.cjs --cherche <motif> [dossier]",
    "        node scripts/carte-code.cjs --gros [n]",
  ].join("\n");
}

const a = process.argv.slice(2);
try {
  if (!a.length || a[0] === "--aide" || a[0] === "-h") console.log(aide());
  else if (a[0] === "--cherche") {
    if (!a[1]) { console.error(aide()); process.exit(2); }
    console.log(cherche(a[1], a[2]));
  } else if (a[0] === "--gros") console.log(gros(parseInt(a[1], 10) || 15));
  else {
    if (!fs.existsSync(a[0])) { console.error("fichier introuvable : " + a[0]); process.exit(1); }
    console.log(sommaire(a[0]));
  }
} catch (e) {
  console.error("erreur : " + e.message);
  process.exit(1);
}
