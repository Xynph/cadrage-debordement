'use strict';

// Serialized into the world VM and called once on the initial senior rosters.
// V1 (France et carrières déjà créées) : dose qui relève les notes selon leur niveau.
// V2 (nouvelles carrières Monde, scale + levels fournis) : note réaliste selon le niveau réel de chaque
// joueur, de son club et de son championnat (native/engine/world-rating-scale.json, native/engine/world-niveaux-v2.json).
module.exports = function createSeniorCalibration(projectSkills, roleNote, roleWeights, rolePriors, scale = null, levels = null) {
  const version = 1;
  const worldVersion = scale && levels ? 2 : 1;
  const versions = worldVersion === 2 ? [1, 2] : [1];
  const openerId = 'lnr:2436';
  const openerProfile = {
    passing: 95, receiving: 91, offload: 77, ballHandling: 94,
    kickDistance: 93, kickAccuracy: 96,
    decisions: 96, anticipation: 90, vision: 95, teamwork: 88, leadership: 85,
    positioning: 83, tackling: 72, evasion: 82, ballCarry: 76,
  };
  // Floor profiles for documented senior performances below the elite starting tier.
  const reviewed = {
    [openerId]: [88, openerProfile],
    'world:srp:p-724f734b6caa9dbb76061ef4': [87, {
      passing: 86, receiving: 87, offload: 80, ballHandling: 86,
      tackling: 96, jackal: 74, positioning: 90, leadership: 87,
      strength: 94, explosiveness: 95, ballCarry: 96, ruckClearout: 73,
      topSpeed: 86, acceleration: 87, agility: 86, evasion: 82, kickChase: 79,
    }],
    'world:urc:193699': [85, {
      passing: 90, receiving: 86, offload: 76, ballHandling: 89,
      topSpeed: 92, acceleration: 94, agility: 91, evasion: 94, kickChase: 82,
      decisions: 93, anticipation: 86, vision: 89, composure: 86, teamwork: 86, leadership: 80,
      kickDistance: 74, kickAccuracy: 74,
    }],
  };
  // Curated starting tiers for ten documented senior profiles, by stable ID.
  // The last column contains their signature attributes.
  const elite = {
    'lnr:2449': [96, 96, ['passing', 'decisions', 'evasion']],
    'world:jlo:e9174f62b95a2e2f7c3e72f2': [95, 95, ['hooking', 'lineoutThrow', 'jackal']],
    'world:urc:185466': [94, 95, ['scrumTechnique', 'strength']],
    'world:prem:155409': [94, 94, ['lineoutJump', 'jumping', 'leadership']],
    'world:urc:235189': [93, 94, ['kickDistance', 'kickAccuracy', 'goalAccuracy']],
    'world:srp:p-20e72f6a2de567813bdcfb40': [93, 93, ['aerialAbility', 'topSpeed', 'positioning']],
    'lnr:2425': [92, 93, ['jackal', 'tackling', 'ruckClearout']],
    'world:urc:147486': [92, 92, ['jackal', 'tackling', 'positioning']],
    'world:srp:p-421a0e8fd929af7e40f1448d': [92, 92, ['passing', 'acceleration', 'ballCarry']],
    'world:urc:154929': [92, 92, ['acceleration', 'agility', 'evasion']],
  };
  const anchors = [[73, 0], [79, 3], [82, 5], [84, 7], [87, 8], [90, 8]];
  const weightsByPosition = new Map();
  const round = value => Math.round(value * 100) / 100;
  const compareId = (a, b) => Number(a > b) - Number(a < b);

  function alignStartingRole(player, confirmedPosition) {
    const originalPosition = player.gameplayPosition || player.pos;
    if (player.age < 23 || !player.attributesV2 || originalPosition === confirmedPosition) return;
    const original = rolePriors[originalPosition];
    const confirmed = rolePriors[confirmedPosition];
    if (!original || !confirmed) return;

    // Keep the player's estimated deviation from the V12 reference at each attribute.
    const attributesV2 = Object.fromEntries(Object.entries(player.attributesV2).map(([key, value]) => [
      key, Math.min(97, Math.max(20, value + confirmed[key] - original[key])),
    ]));
    player.attributesV2 = attributesV2;
    player.skills = projectSkills({ attributesV2, gameplayPosition: confirmedPosition });
  }

  function dose(rating) {
    if (rating <= anchors[0][0]) return 0;
    for (let i = 1; i < anchors.length; i++) {
      const [upper, high] = anchors[i];
      const [lower, low] = anchors[i - 1];
      if (rating <= upper) return Math.round(low + (high - low) * (rating - lower) / (upper - lower));
    }
    return anchors.at(-1)[1];
  }

  function axes(player, position) {
    const key = position + ':' + player.fam;
    if (!weightsByPosition.has(key)) {
      const neutral = Object.fromEntries(Object.keys(player.attributesV2).map(axis => [axis, 50]));
      const baseline = projectSkills({ attributesV2: neutral, gameplayPosition: position });
      const weights = Object.entries(roleWeights[player.fam]);
      const total = weights.reduce((sum, [, weight]) => sum + weight, 0);
      const sensitive = Object.keys(neutral).map(axis => {
        const adjusted = projectSkills({ attributesV2: { ...neutral, [axis]: 51 }, gameplayPosition: position });
        const weight = weights.reduce((sum, [skill, factor]) =>
          sum + factor * (adjusted[skill] - baseline[skill]), 0) / total;
        return { axis, weight };
      }).filter(({ weight }) => weight > 0);
      weightsByPosition.set(key, sensitive);
    }
    return weightsByPosition.get(key);
  }

  function calibrate(player) {
    const opener = player.id === openerId;
    const profile = reviewed[player.id];
    const tier = elite[player.id];
    const lift = dose(player.rating);
    if (!profile && !tier && !lift) return;

    const initialNote = roleNote(player);
    const position = player.gameplayPosition || player.pos;
    const starting = player.attributesV2;
    const attributesV2 = { ...starting };
    const baseline = projectSkills({ attributesV2: starting, gameplayPosition: position });
    // Keep the existing difference between the source skills and their projection,
    // for example when the documented position differs from the original one.
    const skillsAt = () => Object.fromEntries(Object.entries(projectSkills({ attributesV2, gameplayPosition: position }))
      .map(([key, value]) => [key, round(Math.min(99, Math.max(15, player.skills[key] + value - baseline[key])))]));
    let skills = skillsAt();
    let note = initialNote;
    if (profile) {
      for (const [axis, value] of Object.entries(profile[1])) {
        attributesV2[axis] = Math.max(starting[axis], value);
      }
      skills = skillsAt();
      note = roleNote({ ...player, skills });
    } else {
      const target = tier ? tier[1] : Math.min(90, initialNote + lift);
      if (tier) {
        for (const axis of tier[2]) attributesV2[axis] = Math.max(starting[axis], Math.min(97, target + 1));
        skills = skillsAt();
        note = roleNote({ ...player, skills });
      }
      const axesForRole = axes(player, position);
      while (note < target) {
        let choice = null;
        let best = 0;
        for (const { axis, weight } of axesForRole) {
          const increase = attributesV2[axis] - starting[axis];
          if (attributesV2[axis] >= 97 || !tier && (increase >= 16 || weight < 0.05)) continue;
          const priority = weight / (1 + 0.3 * increase);
          if (priority > best || priority === best && compareId(axis, choice) < 0) {
            choice = axis;
            best = priority;
          }
        }
        if (!choice) break;
        attributesV2[choice] = Math.min(97, attributesV2[choice] + 1);
        skills = skillsAt();
        note = roleNote({ ...player, skills });
      }
    }

    if (note <= initialNote) return;
    const targetRating = profile?.[0] ?? tier?.[0] ?? Math.min(90, player.rating + note - initialNote);
    const rating = Math.max(player.rating, targetRating);
    const growth = rating - player.rating;
    player.skillBase += growth;
    player.rating = rating;
    player.attributesV2 = attributesV2;
    player.skills = skills;
    player.dev.seasonStart = rating;
    if (opener) player.dev.potential = Math.max(player.dev.potential, 91);
    else player.dev.potential = Math.min(Math.max(97, player.dev.potential), player.dev.potential + growth);
  }

  // ---- Barème V2 -------------------------------------------------------------------------
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  const hashText = text => {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) { h ^= text.charCodeAt(i); h = Math.imul(h, 16777619); }
    return h >>> 0;
  };
  const NONE = Object.freeze(['aucune', 'inconnu', 0, 'basse']);
  const levelOf = id => levels?.joueurs?.[id] || NONE;
  const etageOf = clubId => levels?.clubs?.[clubId] ?? 'milieu';
  const leagueScale = leagueId => scale.leagues[leagueId] || scale.leagues.guest;
  const statsByRegistry = new WeakMap();
  const band = age => (age < scale.age.seniorFrom ? 'jeune' : 'senior');

  // Moyenne et dispersion des notes de départ par championnat, poste (famille) et tranche d'âge :
  // l'écart propre au joueur se mesure à ce niveau, ce qui neutralise le biais des postes des estimations.
  function leagueStats(registry) {
    if (statsByRegistry.has(registry)) return statsByRegistry.get(registry);
    const groups = new Map();
    const push = (key, value) => (groups.get(key) || groups.set(key, []).get(key)).push(value);
    for (const club of registry.clubs) {
      for (const p of club.players) {
        if (!Number.isFinite(p.rating)) continue;
        push(club.leagueId + '|' + p.fam + '|' + band(p.age), p.rating);
        push(club.leagueId + '|' + p.fam, p.rating);
      }
    }
    const stats = new Map();
    for (const [key, list] of groups) {
      const mean = list.reduce((sum, x) => sum + x, 0) / list.length;
      const sd = Math.sqrt(list.reduce((sum, x) => sum + (x - mean) ** 2, 0) / list.length);
      stats.set(key, { mean, sd: Math.max(1.5, sd), n: list.length });
    }
    statsByRegistry.set(registry, stats);
    return stats;
  }

  function deviation(player, rating, context) {
    const stats = leagueStats(context.registry);
    const fine = stats.get(context.leagueId + '|' + player.fam + '|' + band(player.age));
    const group = fine && fine.n >= 6 ? fine : stats.get(context.leagueId + '|' + player.fam);
    return group ? (rating - group.mean) / group.sd : 0;
  }

  // Note cible : classe d'international (quel que soit le club), sinon ancre du statut dans le
  // championnat, étage du club et écart propre au joueur. Statut inconnu : valeur neutre (rotation).
  function targetRating(player, context) {
    const [classe, statut] = levelOf(player.id);
    const L = leagueScale(context.leagueId), R = scale.residual, A = scale.age;
    const z = deviation(player, player.rating, context);
    const known = statut !== 'inconnu';
    const base = statut === 'titulaire' ? L.titulaire : statut === 'rotation' || !known ? L.rotation : L.reserviste;
    // Statut inconnu : valeur neutre (rotation) du championnat et de l'étage ; l'écart propre au joueur se lit
    // alors dans son effectif (même poste), là où l'estimation de départ range déjà titulaires et doublures.
    // Un jeune se compare aux jeunes de son championnat (même poste) ; l'âge est compté à part, une fois.
    const young = player.age < A.seniorFrom;
    const spread = known || young ? z * (known ? R.known : R.unknown) : (context.club?.get(player.fam)?.(player.rating) ?? z) * R.unknown;
    let value = base + (scale.etages[etageOf(context.clubId)] ?? 0) + clamp(spread, -R.limit, R.limit);
    if (young) value -= (A.seniorFrom - player.age) * A.youngPerYear * (statut === 'titulaire' ? 0.5 : 1);
    // L'écart dans l'effectif d'un senior au statut inconnu contient déjà son âge.
    if (known && player.age >= A.veteranFrom) value -= (player.age - A.veteranFrom + 1) * A.veteranPerYear;
    const range = scale.classes[classe];
    if (range) {
      let international = range[0] + clamp(R.classCenter + z * R.classSpread, 0, 1) * (range[1] - range[0]);
      if (player.age < A.seniorFrom) international -= (A.seniorFrom - player.age) * R.youngInternational;
      if (player.age > A.veteranFrom) international -= player.age - A.veteranFrom;
      value = Math.max(value, international);
    }
    return Math.round(clamp(value, 40, 95));
  }

  // La projection des attributs en compétences est linéaire et ne dépend que du poste : ses
  // coefficients sont relevés une fois par poste, pour chercher vite le facteur des attributs.
  const projections = new Map();
  function linearProjection(position, axes) {
    const key = position + '|' + axes.join(',');
    if (!projections.has(key)) {
      const zero = Object.fromEntries(axes.map(axis => [axis, 0]));
      const origin = projectSkills({ attributesV2: zero, gameplayPosition: position });
      const columns = axes.map(axis => projectSkills({ attributesV2: { ...zero, [axis]: 100 }, gameplayPosition: position }));
      const weights = Object.fromEntries(Object.keys(origin).map(skill => [skill, axes.map((axis, i) => (columns[i][skill] - origin[skill]) / 100)]));
      projections.set(key, { origin, weights });
    }
    return projections.get(key);
  }

  // Les 36 attributs suivent la nouvelle note : même facteur pour tous au-dessus du plancher (20),
  // ce qui garde les proportions du profil au poste ; les compétences sont reprojetées.
  function retarget(player, target) {
    const position = player.gameplayPosition || player.pos;
    const starting = player.attributesV2, axes = Object.keys(starting), values = axes.map(axis => starting[axis]);
    const baseline = projectSkills({ attributesV2: starting, gameplayPosition: position });
    const growth = target - player.rating, shift = player.rating - player.skillBase;
    // Note au poste (roleNote) pour un facteur donné, calculée sur les seules compétences du poste.
    const { origin, weights } = linearProjection(position, axes);
    const role = Object.entries(roleWeights[player.fam] || roleWeights[7]);
    const total = role.reduce((sum, [, w]) => sum + w, 0);
    const scaled = new Array(values.length);
    const noteAt = factor => {
      for (let i = 0; i < values.length; i++) scaled[i] = clamp(Math.round(20 + (values[i] - 20) * factor), 20, 97);
      let sum = 0;
      for (const [skill, w] of role) {
        const row = weights[skill];
        let projected = origin[skill];
        for (let i = 0; i < scaled.length; i++) projected += row[i] * scaled[i];
        const value = round(clamp(player.skills[skill] + round(projected) - baseline[skill], 15, 99));
        sum += w * clamp(value + shift, 15, 99);
      }
      return Math.round(sum / total);
    };
    let factor = 1;
    const initial = noteAt(1);
    if (initial !== target) {
      // Encadrement du facteur, puis dichotomie courte : la note au poste est entière.
      let low = [1, initial], high = low;
      const step = initial < target ? 0.25 : -0.2;
      for (let f = 1 + step; ; f += step) {
        const bounded = clamp(f, 0.3, 2.5), next = [bounded, noteAt(bounded)];
        if (step > 0) { if (next[1] >= target || bounded === 2.5) { high = next; break; } low = next; }
        else { if (next[1] < target || bounded === 0.3) { low = next; break; } high = next; }
      }
      for (let i = 0; i < 8 && high[0] - low[0] > 0.002 && high[1] !== target; i++) {
        const middle = [(low[0] + high[0]) / 2, 0];
        middle[1] = noteAt(middle[0]);
        if (middle[1] >= target) high = middle; else low = middle;
      }
      factor = (Math.abs(low[1] - target) < Math.abs(high[1] - target) ? low : high)[0];
    }
    if (factor !== 1) {
      const attributesV2 = Object.fromEntries(axes.map((axis, i) => [axis, clamp(Math.round(20 + (values[i] - 20) * factor), 20, 97)]));
      const projected = projectSkills({ attributesV2, gameplayPosition: position });
      player.attributesV2 = attributesV2;
      player.skills = Object.fromEntries(Object.entries(projected).map(([key, value]) =>
        [key, round(clamp(player.skills[key] + value - baseline[key], 15, 99))]));
    }
    player.skillBase += growth;
    player.rating = target;
    player.dev.seasonStart = target;
  }

  // Potentiel de départ = note + marge selon l'âge, modulée par la classe, le statut, le U20 et le championnat.
  function startingPotential(player, context) {
    const P = scale.potential, age = player.age;
    const [classe, statut, u20] = levelOf(player.id);
    const international = classe !== 'aucune';
    let margin = P.margins.find(([upTo]) => age <= upTo)[1];
    if (age < 23) {
      if (u20) margin += P.u20;
      if (statut === 'titulaire') margin += P.youngStarter;
      else if (statut === 'rotation') margin += P.youngRotation;
      if (international) margin += P.youngInternational;
      if (P.lowerTiers.includes(context.leagueId) && !u20 && !international) margin += P.lowerTierYoung;
    } else if (age <= 25 && (classe === 'S' || classe === 'A')) margin += P.eliteYoung;
    if (margin > 0) margin += hashText(player.id + ':potentiel-v2') % (2 * P.spread + 1) - P.spread;
    // Hors des championnats d'élite, un potentiel de 88 et plus est réservé aux internationaux U20.
    const ceiling = P.eliteLeagues.includes(context.leagueId) || u20 ? 99 : P.outsideEliteCeiling;
    return clamp(Math.min(player.rating + Math.max(0, margin), ceiling), player.rating, 99);
  }

  function calibrateV2(player, context) {
    if (reviewed[player.id] || elite[player.id]) calibrate(player);
    else retarget(player, targetRating(player, context));
    player.dev.potential = startingPotential(player, context);
  }

  // Peu de potentiels de 90 et plus par génération : au plus N par année de naissance chez les 25 ans et moins.
  function settle(players) {
    if (worldVersion !== 2) return;
    const byAge = new Map();
    for (const p of players) {
      if (!p.dev || p.age > 25 || p.dev.potential < 90 || p.rating >= 90) continue;
      (byAge.get(p.age) || byAge.set(p.age, []).get(p.age)).push(p);
    }
    for (const list of byAge.values()) {
      list.sort((a, b) => b.dev.potential - a.dev.potential || b.rating - a.rating || compareId(a.id, b.id));
      // Les suivants restent de très bons espoirs, assez loin de 90 pour que la variation de carrière l'atteigne rarement.
      for (const p of list.slice(scale.potential.per90Generation)) p.dev.potential = Math.max(p.rating, scale.potential.belowGeneration);
    }
  }

  // Potentiel d'un jeune du centre de formation (politique 3) sur l'échelle du championnat de son club.
  function youthPotential(s, club, player, weight = 0) {
    if (worldVersion !== 2 || !s?.worldMode?.leagues || !club) return null;
    const leagueId = Object.entries(s.worldMode.leagues).find(([, l]) => l.members?.includes(club.id))?.[0] ?? 'guest';
    const Y = scale.academy, anchor = leagueScale(leagueId).titulaire + (scale.etages[etageOf(club.id)] ?? 0);
    const draw = hashText(player.id + ':formation-v2'), percentile = (draw % 10000) / 100, variation = draw >>> 14;
    const elitePercent = Y.elitePercent + Y.elitePerWeight * weight, strong = Y.strongBase + weight;
    const index = percentile >= 100 - elitePercent ? 3 : percentile >= 100 - elitePercent - strong ? 2 : percentile >= 100 - elitePercent - strong - Y.promising ? 1 : 0;
    const [low, high] = Y.bands[index];
    const target = anchor + low + variation % (high - low + 1);
    return Math.min(99, player.rating + Math.max(4, target - roleNote(player)));
  }

  // Écart de chaque joueur à son effectif, par famille de poste (notes de départ, avant barème).
  function clubDeviation(players) {
    const groups = new Map();
    for (const p of players) if (Number.isFinite(p.rating) && p.age >= scale.age.seniorFrom) (groups.get(p.fam) || groups.set(p.fam, []).get(p.fam)).push(p.rating);
    return new Map([...groups].map(([fam, list]) => {
      const mean = list.reduce((sum, x) => sum + x, 0) / list.length;
      const sd = Math.max(2, Math.sqrt(list.reduce((sum, x) => sum + (x - mean) ** 2, 0) / list.length));
      return [fam, rating => (rating - mean) / sd];
    }));
  }

  // Joueurs de complément d'effectif (« depth- », générés sans attributs détaillés) : statut inconnu, juste
  // sous la valeur neutre du championnat et de l'étage ; leurs compétences suivent la note, leurs 36 qualités compactes aussi.
  function calibrateDepth(player, context) {
    const L = leagueScale(context.leagueId);
    // Un joueur de complément reste sous le moins bon joueur de l'effectif (règle de nativeProfessionalDepth).
    // Au poste, sa note reste aussi sous celle du moins bon titulaire potentiel (même poste, sinon tout l'effectif).
    const peers = context.others.filter(p => p.pos === player.pos);
    const noteFloor = Math.min(...(peers.length ? peers : context.others).map(p => roleNote(p)));
    const value = Math.min(L.rotation + (scale.etages[etageOf(context.clubId)] ?? 0) - 1, context.floor - 1,
      player.rating + noteFloor - 1 - roleNote(player));
    const target = Math.round(clamp(value, 40, 95));
    if (typeof player.nativeAttributesV1 === 'string' && /^\d{72}$/.test(player.nativeAttributesV1) && player.rating > 20) {
      const factor = (target - 20) / (player.rating - 20);
      player.nativeAttributesV1 = Array.from({ length: 36 }, (_, i) =>
        String(clamp(Math.round(20 + (Number(player.nativeAttributesV1.slice(2 * i, 2 * i + 2)) - 20) * factor), 20, 97)).padStart(2, '0')).join('');
    }
    player.rating = target;
    if (player.dev) {
      player.dev.seasonStart = target;
      player.dev.potential = startingPotential(player, context);
    }
  }

  function apply(players, sources = null, context = null) {
    if (worldVersion === 2 && context) context = { ...context, club: clubDeviation(players.filter(p => !sources || sources.has(p.id))) };
    for (const player of players) {
      if (!player.attributesV2 || sources && !sources.has(player.id)) continue;
      if (worldVersion === 2 && context) calibrateV2(player, context);
      else if (player.age >= 23) calibrate(player);
    }
    if (worldVersion === 2 && context) {
      const depth = players.filter(p => /^depth-/.test(p.id) && !p.attributesV2 && Number.isFinite(p.rating));
      const others = players.filter(p => !depth.includes(p) && Number.isFinite(p.rating));
      const floor = others.length ? Math.min(...others.map(p => p.rating)) : 99;
      if (others.length) for (const player of depth) calibrateDepth(player, { ...context, floor, others });
    }
  }

  return Object.freeze({ version, worldVersion, versions, alignStartingRole, apply, settle, youthPotential, targetRating });
};
