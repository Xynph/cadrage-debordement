'use strict';

module.exports = function academyGroups() {
  const capacity = 75;
  const roles = [...new Set(POS)].map(pos => ({
    pos,
    slots: POS.flatMap((position, slot) => position === pos ? [slot] : []),
  }));
  const active = s => [1, 2].includes(s?.academyGroupPolicy);
  const worldwide = s => s?.academyGroupPolicy === 2;
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

  function recruitmentPlan(players, initial) {
    const u18 = plan(players, [17, 18], age => age <= 18, true);
    const u21 = plan(players, [19, 20, 21], age => age >= 19 && age <= 21, initial);
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
      const younger = players.filter(player => player.age <= 18).length;
      news(`Le centre accueille ${accepted.length} nouveau(x) jeune(s). Effectif : ${younger} U18 et ${players.length - younger} U21.`);
    }
    if (accepted.length < additions.length) {
      news('Le centre a atteint son plafond de 75 jeunes. Certains postes restent à compléter à la prochaine arrivée.');
    }
  }

  function refill(s, initial) {
    const ids = occupiedIds(s);
    const human = s.development;
    fillCenter(s, s.clubs[s.club], human, human.academy, recruitmentPlan(human.academy, initial), ids);
    if (!worldwide(s)) return;
    for (const center of s.aiRoster.academies) {
      fillCenter(s, s.clubs[center.clubId], center, center.players, recruitmentPlan(center.players, initial), ids);
    }
  }

  function start(s) {
    s.academyGroupPolicy = 2;
    refill(s, true);
  }

  function afterSeason(s, previousClub) {
    if (active(s)) refill(s, s.club !== previousClub);
  }

  function preview(s) {
    const context = { season: s.season, week: s.worldMode?.week ?? s.franceMode?.week ?? s.round, club: s.club };
    const result = { context, version: s.academyGroupPolicy ?? 0, centers: s.clubs.length,
      available: false, additions: 0, blocked: [], reason: '' };
    if (worldwide(s)) result.reason = 'Les groupes U18 et U21 sont déjà actifs dans tous les clubs.';
    else if (s.aiRosterVersion !== 2 || s.aiRoster?.version !== 2) result.reason = 'Activez d’abord la politique de population récente.';
    else if (s.live || s.phase !== 'league') result.reason = 'Ouvrez cette reprise hors match, pendant le championnat.';
    if (result.reason) return result;
    const all = [{ clubId: s.club, players: s.development.academy }, ...s.aiRoster.academies];
    for (const { clubId, players } of all) {
      const additions = recruitmentPlan(players, true).length;
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
      throw Error('Confirmez la reprise des groupes U18 et U21.');
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
  }

  function installHooks() {
    const legacy = globalThis.intakeYouth;
    // The native worker fills the active centre after ageing, departures and
    // manager mobility. Legacy centres keep their existing intake window.
    globalThis.intakeYouth = function (...args) {
      if (!active(S)) return legacy.apply(this, args);
    };
  }

  return { start, afterSeason, preview, enable, validate, installHooks };
};
