'use strict';

module.exports = function academyGroups() {
  const capacity = 75;
  const roles = [...new Set(POS)].map(pos => ({
    pos,
    slots: POS.flatMap((position, slot) => position === pos ? [slot] : []),
  }));
  const active = s => [1, 2, 3].includes(s?.academyGroupPolicy);
  const worldwide = s => [2, 3].includes(s?.academyGroupPolicy);
  // Politique 3 (décisions de Léo du 12/11/2026) : Crabos de 16-17 ans (35 au plus) et
  // Espoirs de 18 à 21 ans ; deux joueurs par poste au départ ; ensuite une fournée de
  // 12 à 20 jeunes de 16 ans chaque début de saison (1er juillet), aux postes tirés au
  // hasard mais orientés vers les manques, parmi laquelle chaque club choisit.
  const modern = s => s?.academyGroupPolicy === 3;
  const CRABOS_CAP = 35;
  const groupSize = 2 * POS.length;

  function plan(players, ages, belongs, balance) {
    const group = players.filter(player => belongs(player.age));
    const additions = [];
    for (const { pos, slots } of roles) {
      const current = group.filter(player => player.pos === pos);
      const cohorts = ages.map(age => current.filter(player => player.age === age).length);
      for (let count = current.length; count < 2 * slots.length; count++) {
        const cohort = balance ? cohorts.indexOf(Math.min(...cohorts)) : 0;
        cohorts[cohort]++;
        additions.push({ slot: slots[count % slots.length], age: ages[cohort], coverage: count / slots.length });
      }
    }
    return { additions, shortfall: Math.max(0, groupSize - group.length) };
  }

  function interleave(a, b) {
    const ordered = [];
    for (let index = 0; index < Math.max(a.length, b.length); index++) {
      if (a[index]) ordered.push(a[index]);
      if (b[index]) ordered.push(b[index]);
    }
    return ordered;
  }

  function recruitmentPlan(players, initial, policy3 = false) {
    const u18 = policy3 ? plan(players, [16, 17], age => age <= 17, true) : plan(players, [17, 18], age => age <= 18, true);
    const u21 = policy3 ? plan(players, [18, 19, 20, 21], age => age >= 18 && age <= 21, true) : plan(players, [19, 20, 21], age => age >= 19 && age <= 21, initial);
    if (players.length + u18.additions.length + u21.additions.length <= capacity) {
      return interleave(u18.additions, u21.additions);
    }
    const byCoverage = (a, b) => a.coverage - b.coverage;
    u18.additions.sort(byCoverage);
    u21.additions.sort(byCoverage);
    const minU18 = u18.additions.slice(0, u18.shortfall), extraU18 = u18.additions.slice(u18.shortfall);
    const minU21 = u21.additions.slice(0, u21.shortfall), extraU21 = u21.additions.slice(u21.shortfall);
    return [...interleave(minU18, minU21), ...interleave(extraU18, extraU21)];
  }

  function occupiedIds(s) {
    return new Set([
      ...s.clubs.flatMap(club => club.players), ...s.development.academy,
      ...s.aiRoster.academies.flatMap(group => group.players),
      ...(s.nativeAcademy?.centers ?? []).flatMap(center => center.players ?? []),
      ...s.economy.freeAgents, ...s.market, ...s.development.retired,
    ].map(player => player.id));
  }

  function fillCenter(s, club, record, players, additions, ids) {
    const accepted = additions.slice(0, Math.max(0, capacity - players.length));
    let serial = 60000;
    for (const { slot, age } of accepted) {
      while (ids.has(`youth-${club.id}-${s.season}-${serial}`)) serial++;
      const player = academyPlayer(club.id, slot, s.season, serial++, false, club);
      player.age = age;
      ids.add(player.id);
      players.push(player);
    }
    record.intakeSeason = s.season;
    if (club.id !== s.club) return;
    if (accepted.length) {
      const limit = modern(s) ? 17 : 18;
      const younger = players.filter(player => player.age <= limit).length;
      news(modern(s)
        ? `Le centre accueille ${accepted.length} jeune(s). Effectif : ${younger} Crabos et ${players.length - younger} Espoirs.`
        : `Le centre accueille ${accepted.length} nouveau(x) jeune(s). Effectif : ${younger} U18 et ${players.length - younger} U21.`);
    }
    if (accepted.length < additions.length) {
      news('Le centre a atteint son plafond de 75 jeunes. Certains postes restent à compléter à la prochaine arrivée.');
    }
  }

  function refill(s, initial) {
    const ids = occupiedIds(s);
    const human = s.development;
    const policy3 = modern(s);
    fillCenter(s, s.clubs[s.club], human, human.academy, recruitmentPlan(human.academy, initial, policy3), ids);
    if (!worldwide(s)) return;
    for (const center of s.aiRoster.academies) {
      fillCenter(s, s.clubs[center.clubId], center, center.players, recruitmentPlan(center.players, initial, policy3), ids);
    }
  }

  // --- Fournées annuelles (politique 3) -------------------------------------------
  const FAMILY = slot => typeof FAMILIES === 'undefined' ? slot : FAMILIES[slot];
  let slotsByFamily = null;
  const familySlots = () => slotsByFamily ??= POS.reduce((m, _, slot) => (m[FAMILY(slot)] = (m[FAMILY(slot)] || 0) + 1, m), {});
  const hash = text => Array.from(String(text)).reduce((n, c) => Math.imul(n ^ c.charCodeAt(0), 16777619), 2166136261) >>> 0;
  const crabos = players => players.filter(p => p.age <= 17);
  function deficit(players, family) {
    return 2 * familySlots()[family] - crabos(players).filter(p => FAMILY(POS.indexOf(p.pos)) === family).length;
  }
  // Proposition déterministe : aucun tirage du RNG de simulation.
  function proposal(s, club, players, ids) {
    const size = 12 + hash(`intake:${club.id}:${s.season}:size`) % 9;
    const chosen = [];
    const counted = () => [...players, ...chosen];
    for (let k = 0; k < size; k++) {
      const weights = POS.map((_, slot) => Math.max(0.3, 1 + deficit(counted(), FAMILY(slot)) / familySlots()[FAMILY(slot)]));
      const total = weights.reduce((a, b) => a + b, 0);
      let roll = (hash(`intake:${club.id}:${s.season}:${k}`) % 100000) / 100000 * total, slot = 0;
      while (slot < POS.length - 1 && roll >= weights[slot]) { roll -= weights[slot]; slot++; }
      chosen.push(make(s, club, slot, ids, chosen.length));
    }
    // Recrutement ciblé : une famille sans aucun Crabos ni candidat reçoit un candidat.
    for (const family of Object.keys(familySlots()).map(Number)) {
      if (!counted().some(p => p.age <= 17 && FAMILY(POS.indexOf(p.pos)) === family)) {
        const slots = POS.map((_, slot) => slot).filter(slot => FAMILY(slot) === family);
        chosen.push(make(s, club, slots[hash(`intake:${club.id}:${s.season}:target:${family}`) % slots.length], ids, chosen.length));
      }
    }
    // Rarement, un jeune de 15 ans exceptionnellement fort (environ 1 club sur 20 par saison).
    if (chosen.length && hash(`intake:${club.id}:${s.season}:prodige`) % 20 === 0) {
      const p = chosen[hash(`intake:${club.id}:${s.season}:prodige:who`) % chosen.length];
      p.age = 15;
      p.dev.potential = Math.min(99, Math.max(p.dev.potential, 90 + hash(p.id + ':prodige') % 6, p.rating + 4));
      p.prodigy = true;
    }
    return chosen;
  }
  function make(s, club, slot, ids, index) {
    let serial = 70000 + index;
    while (ids.has(`youth-${club.id}-${s.season}-${serial}`)) serial += 100;
    const player = academyPlayer(club.id, slot, s.season, serial, false, club);
    player.age = 16;
    ids.add(player.id);
    return player;
  }
  // Choix du staff (ordinateur, ou club joué sans décision) : les postes les plus en manque d'abord.
  function staffChoice(s, club, players, candidates) {
    const target = 14 + hash(`intake:${club.id}:${s.season}:keep`) % 4;
    const pool = candidates.slice(), kept = [];
    while (pool.length && kept.length < target && crabos([...players, ...kept]).length < CRABOS_CAP) {
      pool.sort((a, b) => {
        const da = deficit([...players, ...kept], FAMILY(POS.indexOf(a.pos))), db = deficit([...players, ...kept], FAMILY(POS.indexOf(b.pos)));
        return db - da || (b.prodigy ? 1 : 0) - (a.prodigy ? 1 : 0) || b.dev.potential - a.dev.potential || (a.id < b.id ? -1 : 1);
      });
      kept.push(pool.shift());
    }
    return kept;
  }
  function welcome(s, record, players, kept) {
    for (const p of kept) players.push(p);
    record.intakeSeason = s.season;
  }
  // Passage à 18 ans des centres IA : tous les Crabos ne reçoivent pas de contrat Espoir.
  // Le groupe Espoirs reste borné par la masse salariale ; on garde les plus prometteurs.
  const ESPOIRS_AI = 36;
  function trimEspoirs(center) {
    const espoirs = center.players.filter(p => p.age >= 18);
    if (espoirs.length <= ESPOIRS_AI) return 0;
    const value = p => (p.dev?.potential ?? p.rating) * 2 + p.rating - (p.age - 18) * 3;
    const out = new Set(espoirs.sort((a, b) => value(a) - value(b) || (a.id < b.id ? -1 : 1)).slice(0, espoirs.length - ESPOIRS_AI).map(p => p.id));
    center.players = center.players.filter(p => !out.has(p.id));
    return out.size;
  }
  function seasonalIntake(s) {
    const ids = occupiedIds(s);
    for (const center of s.aiRoster.academies) {
      const club = s.clubs[center.clubId];
      if (!club) continue;
      trimEspoirs(center);
      const candidates = proposal(s, club, center.players, ids);
      welcome(s, center, center.players, staffChoice(s, club, center.players, candidates).slice(0, Math.max(0, capacity - center.players.length)));
    }
    const human = s.development, own = s.clubs[s.club];
    s.academyIntake = { version: 1, season: s.season, players: proposal(s, own, human.academy, ids) };
    human.intakeSeason = s.season;
    news(`Nouvelle génération : ${s.academyIntake.players.length} jeunes de 16 ans se présentent au centre de formation. Choisissez ceux que vous gardez en Crabos.`);
  }
  function pendingIntake(s) {
    return modern(s) && s.academyIntake?.version === 1 && s.academyIntake.season === s.season ? s.academyIntake : null;
  }
  // Décision du club joué : garder certains candidats, libérer des Crabos pour faire de la place.
  function confirmIntake(s, keep, release) {
    const intake = pendingIntake(s);
    if (!intake) throw Error('Aucune nouvelle génération à examiner.');
    if (!Array.isArray(keep) || !Array.isArray(release) || new Set(keep).size !== keep.length || new Set(release).size !== release.length) throw Error('Choix de la génération invalide.');
    const academy = s.development.academy;
    if (!keep.every(id => intake.players.some(p => p.id === id))) throw Error('Ce jeune ne fait pas partie de la génération.');
    if (!release.every(id => academy.some(p => p.id === id))) throw Error('Seuls des jeunes du centre peuvent être libérés.');
    const remaining = academy.filter(p => !release.includes(p.id));
    const crabosAfter = crabos(remaining).length + keep.length;
    if (crabosAfter > CRABOS_CAP) throw Error(`Il faut d'abord faire de la place : ${crabosAfter} Crabos pour ${CRABOS_CAP} places.`);
    if (remaining.length + keep.length > capacity) throw Error(`Le centre est plein : ${capacity} jeunes au plus.`);
    s.development.academy = remaining.concat(intake.players.filter(p => keep.includes(p.id)));
    delete s.academyIntake;
    news(`Génération ${(typeof libelleSaison==='function'?libelleSaison:String)(s.season)} : ${keep.length} jeune(s) rejoignent les Crabos${release.length ? `, ${release.length} quittent le centre` : ''}.`);
    return { kept: keep.length, released: release.length };
  }
  // Sans décision avant la première journée, le responsable de la formation choisit.
  function settleIntake(s) {
    const intake = pendingIntake(s);
    if (!intake) return false;
    const own = s.clubs[s.club], academy = s.development.academy;
    const kept = staffChoice(s, own, academy, intake.players).slice(0, Math.max(0, capacity - academy.length));
    academy.push(...kept);
    delete s.academyIntake;
    news(`Le responsable de la formation a retenu ${kept.length} jeune(s) de la nouvelle génération.`);
    return true;
  }
  function intakeProject(s) {
    const intake = pendingIntake(s);
    if (!intake) return null;
    return { season: intake.season, crabos: crabos(s.development.academy).length, crabosCap: CRABOS_CAP, capacity, academy: s.development.academy.length,
      players: intake.players.map(p => ({ id: p.id, name: p.name, pos: p.pos, age: p.age, rating: p.rating, prodigy: !!p.prodigy,
        potential: Math.round(p.dev.potential) })) };
  }

  function start(s) {
    s.academyGroupPolicy = 3;
    refill(s, true);
  }

  function afterSeason(s, previousClub) {
    if (!active(s)) return;
    if (modern(s)) seasonalIntake(s);
    else refill(s, s.club !== previousClub);
  }

  function preview(s) {
    const context = { season: s.season, week: s.worldMode?.week ?? s.franceMode?.week ?? s.round, club: s.club };
    const result = { context, version: s.academyGroupPolicy ?? 0, centers: s.clubs.length,
      available: false, additions: 0, blocked: [], reason: '' };
    if (worldwide(s)) result.reason = 'Les Crabos et les Espoirs sont déjà actifs dans tous les clubs.';
    else if (s.aiRosterVersion !== 2 || s.aiRoster?.version !== 2) result.reason = 'Activez d’abord la politique de population récente.';
    else if (s.live || s.phase !== 'league') result.reason = 'Ouvrez cette reprise hors match, pendant le championnat.';
    if (result.reason) return result;
    const all = [{ clubId: s.club, players: s.development.academy }, ...s.aiRoster.academies];
    for (const { clubId, players } of all) {
      const additions = recruitmentPlan(players, true, true).length;
      const required = players.length + additions;
      result.additions += additions;
      if (required > capacity) result.blocked.push({ clubId, name: s.clubs[clubId].name, current: players.length, required });
    }
    if (result.blocked.length) {
      const first = result.blocked[0];
      result.reason = `${first.name} aurait besoin de ${first.required} places pour garder ses ${first.current} jeunes et compléter ses groupes. Le plafond est de ${capacity}. Réessayez après les sorties de saison.`;
    } else result.available = true;
    return result;
  }

  function enable(s, payload) {
    if (payload.confirmed !== true || Object.keys(payload).some(key => !['confirmed', 'context'].includes(key))) {
      throw Error('Confirmez la reprise des groupes Crabos et Espoirs.');
    }
    const result = preview(s);
    const supplied = payload.context;
    if (!supplied || Object.keys(supplied).length !== 3 || Object.keys(result.context).some(key => supplied[key] !== result.context[key])) {
      throw Error('Le contexte de carrière a changé. Consultez à nouveau la reprise des groupes.');
    }
    if (!result.available) throw Error(result.reason);
    start(s);
  }

  function validate(s) {
    if (s.academyGroupPolicy !== undefined && (!active(s) || !s.aiRoster || !s.development || !s.economy ||
      (worldwide(s) ? s.aiRosterVersion !== 2 : !s.commonDatabase))) {
      throw Error('Politique des effectifs de formation invalide.');
    }
    if (s.academyIntake !== undefined) {
      const x = s.academyIntake, keys = Object.keys(x || {});
      if (!modern(s) || keys.length !== 3 || !['version', 'season', 'players'].every(k => keys.includes(k)) || x.version !== 1 ||
        !Number.isSafeInteger(x.season) || x.season < 1 || x.season > s.season || !Array.isArray(x.players) || x.players.length > 30 ||
        new Set(x.players.map(p => p?.id)).size !== x.players.length ||
        !x.players.every(p => p && typeof p.id === 'string' && /^youth-\d+-\d+-\d+$/.test(p.id) && p.academy === true && [15, 16].includes(p.age) &&
          POS.includes(p.pos) && Number.isFinite(p.rating) && Number.isFinite(p.dev?.potential) && p.dev.potential >= p.rating && p.dev.potential <= 99)) {
        throw Error('Nouvelle génération du centre invalide.');
      }
    }
  }

  function installHooks() {
    const legacy = globalThis.intakeYouth;
    // The native worker fills the active centre after ageing, departures and
    // manager mobility. Legacy centres keep their existing intake window.
    globalThis.intakeYouth = function (...args) {
      if (!active(S)) return legacy.apply(this, args);
    };
  }

  return { start, afterSeason, preview, enable, validate, installHooks, confirmIntake, settleIntake, intakeProject, proposal, staffChoice };
};
