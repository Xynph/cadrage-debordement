#!/usr/bin/env node
'use strict';
// Détecteur de retard du journal et du bandeau sur l'image (match filmé, report.json → chrono).
// Pour chaque relevé (0,25 s de jeu) : horloge affichée, dernière minute du journal à l'écran (journal du
// bandeau en 3D, fil de l'écran 2D sinon), équipe annoncée « X a le ballon », contre ce que montre l'image
// (porteur 3D, terrain 2D) et ce que sait le moteur (faits et minute).
// Écarts signalés : journal en retard de plus de 2 minutes de jeu alors que des faits de ces minutes existent,
// ou possession annoncée contraire à l'image pendant au moins 1 s.
// Usage : node tools/match-filme/retard-journal.cjs <dossier du film | report.json> [--json] [--seuil 2]
const fs = require('fs');
const path = require('path');

function minuteDe(texte) {
  if (texte === null || texte === undefined) return null;
  if (typeof texte === 'number') return texte;
  const m = String(texte).trim().match(/^(\d+)(?:\+(\d+))?(?::(\d{1,2}))?\s*['′]?/);
  if (!m) return null;
  return Number(m[1]) + (m[2] ? Number(m[2]) : 0);
}

function campAnnonce(texte, equipes) {
  if (!texte || !/a le ballon/.test(texte)) return -1;
  let meilleur = -1;
  let longueur = 0;
  (equipes || []).forEach((nom, cote) => {
    if (nom && texte.startsWith(nom) && nom.length > longueur) { meilleur = cote; longueur = nom.length; }
  });
  return meilleur;
}

// Équipes : celles du rapport, sinon déduites des phrases « X a le ballon » et du terrain 2D (vote).
function equipesDe(report) {
  if (Array.isArray(report.equipes) && report.equipes.length === 2) return report.equipes;
  const votes = [{}, {}];
  for (const r of report.chrono || []) {
    const texte = r.etat_2d || '';
    const camp = r.terrain ? r.terrain.possession : -1;
    const m = texte.match(/^(.*?) a le ballon/);
    if (m && (camp === 0 || camp === 1)) votes[camp][m[1]] = (votes[camp][m[1]] || 0) + 1;
  }
  return votes.map((v) => Object.entries(v).sort((a, b) => b[1] - a[1])[0]?.[0] || '');
}

function analyser(report, { seuil = 2, tenue = 1.0 } = {}) {
  const equipes = equipesDe(report);
  const chrono = report.chrono || [];
  const retards = [];
  const possessions = [];
  let enCours = null;
  for (const r of chrono) {
    const horloge = minuteDe(r.horloge);
    const regie = r.regie || {};
    const en3d = regie.etat === 1;
    // Journal à l'écran : celui du bandeau en 3D (s'il est visible), le fil sur l'écran 2D.
    let journal = null;
    let source = '';
    if (en3d && r.journal_visible && Array.isArray(r.journal) && r.journal.length) { journal = minuteDe(r.journal[0]); source = 'bandeau'; }
    else if (!en3d && r.fil) { journal = minuteDe(r.fil.min); source = 'fil'; }
    // Fil : en retard seulement si le terrain 2D a déjà joué des faits après sa dernière ligne (un écart sans fait
    // entre deux est le jeu lui-même : trois minutes sans fait notable).
    const faitsApres = source === 'bandeau' || (r.terrain && r.fil && Number(r.terrain.joue_i) > Number(r.fil.i));
    if (horloge !== null && journal !== null && horloge - journal > seuil && faitsApres) {
      retards.push({ s: r.s, image: r.image, horloge: r.horloge, journal: source === 'bandeau' ? r.journal[0] : `${r.fil.min}′ (fil i=${r.fil.i})`, source,
        ecart: horloge - journal, moteur: r.minute_moteur, regie: `${regie.etat}/${regie.phase}/${regie.index}`, plan: r.plan || null,
        tiroir: r.tiroir || null, dernierFaitMoteur: r.dernier_fait_moteur || null, terrain: r.terrain || null });
    }
    // Possession annoncée contre l'image.
    const texte = en3d ? r.possession : (r.etat_2d || r.possession);
    const annonce = campAnnonce(texte, equipes);
    // Image : porteur 3D (sinon la scène du plan) ; terrain 2D : pendant la lecture d'un fait, la ligne d'état dit le
    // dernier fait fini (même instant que le fil) et le terrain montre déjà le suivant : les deux camps sont justes.
    let vrais = [];
    // 3D : l'équipe du plan montré ou celle du porteur (coup de pied : le receveur est porteur dès le départ du ballon).
    if (en3d) vrais = [r.porteur_3d, r.plan ? Number(r.plan.possession) : -1].filter((v) => v === 0 || v === 1);
    else if (r.terrain) {
      vrais = [r.terrain.possession];
      if (r.terrain.possession_joue !== undefined) vrais.push(r.terrain.possession_joue);
      else if (r.terrain.file > 0) vrais = [];
    }
    const vrai = vrais.find((v) => v === 0 || v === 1) ?? -1;
    const faux = annonce >= 0 && vrais.some((v) => v === 0 || v === 1) && !vrais.includes(annonce);
    if (faux) {
      if (!enCours) enCours = { debut: r.s, image: r.image, horloge: r.horloge, texte, annonce, vrai, vue: en3d ? '3d' : '2d', regie: `${regie.etat}/${regie.phase}/${regie.index}`, plan: r.plan || null, terrain: r.terrain || null, fin: r.s };
      enCours.fin = r.s;
    } else if (enCours) {
      if (enCours.fin - enCours.debut >= tenue) possessions.push(enCours);
      enCours = null;
    }
  }
  if (enCours && enCours.fin - enCours.debut >= tenue) possessions.push(enCours);
  // Retards regroupés en épisodes (relevés consécutifs).
  const episodes = [];
  for (const r of retards) {
    const dernier = episodes[episodes.length - 1];
    if (dernier && r.s - dernier.fin <= 0.6 && r.source === dernier.source) { dernier.fin = r.s; dernier.ecartMax = Math.max(dernier.ecartMax, r.ecart); dernier.dernier = r; continue; }
    episodes.push({ debut: r.s, fin: r.s, ecartMax: r.ecart, premier: r, dernier: r, source: r.source });
  }
  return { equipes, releves: chrono.length, retards: episodes, possessions };
}

function main() {
  const args = process.argv.slice(2);
  const cible = args.find((a) => !a.startsWith('--'));
  if (!cible) { console.error('Usage : retard-journal.cjs <dossier du film | report.json> [--json] [--seuil 2]'); process.exit(2); }
  const fichier = fs.statSync(cible).isDirectory() ? path.join(cible, 'report.json') : cible;
  const report = JSON.parse(fs.readFileSync(fichier, 'utf8'));
  const i = args.indexOf('--seuil');
  const res = analyser(report, { seuil: i >= 0 ? Number(args[i + 1]) : 2 });
  if (args.includes('--json')) { console.log(JSON.stringify(res, null, 2)); }
  else {
    console.log(`Relevés : ${res.releves} ; équipes : ${res.equipes.join(' / ')}`);
    console.log(`Journal en retard (> 2 min) : ${res.retards.length} épisode(s)`);
    for (const e of res.retards) console.log(`  ${e.debut}-${e.fin} s image ${e.premier.image} [${e.source}] horloge ${e.premier.horloge} journal « ${e.premier.journal} » écart max ${e.ecartMax} ; moteur ${e.premier.moteur}′ régie ${e.premier.regie}`);
    console.log(`Possession fausse (≥ 1 s) : ${res.possessions.length}`);
    for (const p of res.possessions) console.log(`  ${p.debut}-${p.fin} s image ${p.image} [${p.vue}] horloge ${p.horloge} « ${p.texte} » annonce ${p.annonce} image ${p.vrai} régie ${p.regie}`);
  }
  process.exit(res.retards.length || res.possessions.length ? 1 : 0);
}

module.exports = { analyser, minuteDe, campAnnonce };
if (require.main === module) main();
