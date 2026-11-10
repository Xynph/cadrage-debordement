'use strict';

module.exports = function academyGroups() {
  const capacity = 75;
  const roles = [...new Set(POS)].map(pos => ({
    pos,
    slots: POS.flatMap((position, slot) => position === pos ? [slot] : []),
  }));
  const active = s => [1, 2].includes(s?.academyGroupPolicy);
  const worldwide = s => s?.academyGroupPolicy === 2;

  function plan(players, ages, belongs, balance) {
    const additions = [];
    for (const { pos, slots } of roles) {
      const current = players.filter(player => player.pos === pos && belongs(player.age));
      const cohorts = ages.map(age => current.filter(player => player.age === age).length);
      for (let count = current.length; count < 2 * slots.length; count++) {
        const cohort = balance ? cohorts.indexOf(Math.min(...cohorts)) : 0;
        cohorts[cohort]++;
        additions.push({ slot: slots[count % slots.length], age: ages[cohort] });
      }
    }
    return additions;
  }

  function recruitmentPlan(players, initial) {
    const u18 = plan(players, [17, 18], age => age <= 18, true);
    const u21 = plan(players, [19, 20, 21], age => age >= 19 && age <= 21, initial);
    const additions = [];
    for (let index = 0; index < Math.max(u18.length, u21.length); index++) {
      if (u18[index]) additions.push(u18[index]);
      if (u21[index]) additions.push(u21[index]);
    }
    return additions;
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

  return { start, afterSeason, validate, installHooks };
};
