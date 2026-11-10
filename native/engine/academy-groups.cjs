'use strict';

module.exports = function academyGroups() {
  const capacity = 75;
  const roles = [...new Set(POS)].map(pos => ({
    pos,
    slots: POS.flatMap((position, slot) => position === pos ? [slot] : []),
  }));
  const active = s => s?.academyGroupPolicy === 1;

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

  function refill(s, initial = false) {
    const academy = s.development;
    const players = academy.academy;
    const u18 = plan(players, [17, 18], age => age <= 18, true);
    const u21 = plan(players, [19, 20, 21], age => age >= 19 && age <= 21, initial);
    const additions = [];
    for (let index = 0; index < Math.max(u18.length, u21.length); index++) {
      if (u18[index]) additions.push(u18[index]);
      if (u21[index]) additions.push(u21[index]);
    }
    const ids = new Set([
      ...s.clubs.flatMap(club => club.players), ...players,
      ...s.aiRoster.academies.flatMap(group => group.players),
      ...s.economy.freeAgents, ...s.market, ...academy.retired,
    ].map(player => player.id));
    const accepted = additions.slice(0, Math.max(0, capacity - players.length));
    let serial = 60000;
    for (const { slot, age } of accepted) {
      while (ids.has(`youth-${s.club}-${s.season}-${serial}`)) serial++;
      const player = academyPlayer(s.club, slot, s.season, serial++);
      player.age = age;
      ids.add(player.id);
      players.push(player);
    }
    academy.intakeSeason = s.season;
    if (accepted.length) {
      const younger = players.filter(player => player.age <= 18).length;
      news(`Le centre accueille ${accepted.length} nouveau(x) jeune(s). Effectif : ${younger} U18 et ${players.length - younger} U21.`);
    }
    if (accepted.length < additions.length) {
      news('Le centre a atteint son plafond de 75 jeunes. Certains postes restent à compléter à la prochaine arrivée.');
    }
  }

  function start(s) {
    if (!s.commonDatabase) return;
    s.academyGroupPolicy = 1;
    refill(s, true);
  }

  function afterSeason(s, previousClub) {
    if (active(s)) refill(s, s.club !== previousClub);
  }

  function validate(s) {
    if (s.academyGroupPolicy !== undefined && (!active(s) || !s.commonDatabase || !s.aiRoster || !s.development || !s.economy)) {
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
