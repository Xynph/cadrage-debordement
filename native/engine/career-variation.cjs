'use strict';

// Applied explicitly once, at the end of a new-career transaction. Hashing and
// validation never consume the competition RNG or mutate reference catalogues.
module.exports = function careerVariation(dependencies = {}) {
  const version = 1;
  const attributes = ['passing','receiving','offload','tackling','jackal','ruckClearout','ballCarry','evasion',
    'kickDistance','kickAccuracy','goalAccuracy','ballHandling','decisions','anticipation','vision','positioning',
    'composure','discipline','teamwork','leadership','workRate','acceleration','topSpeed','agility','explosiveness',
    'strength','endurance','jumping','scrumTechnique','hooking','lineoutThrow','lineoutJump','lineoutLift','maul','kickChase','aerialAbility'];
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const copy = value => JSON.parse(JSON.stringify(value));
  const round = value => Math.round(value * 100) / 100;
  const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
  const check = (condition, message) => { if (!condition) throw Error('Variation de carrière : ' + message); };

  function validate(settings) {
    check(settings && typeof settings === 'object' && !Array.isArray(settings) &&
      Object.keys(settings).length === 3 && ['version','seed','varyCurrent'].every(key => own(settings,key)), 'paramètres invalides.');
    check(settings.version === version && Number.isInteger(settings.seed) && settings.seed >= 0 && settings.seed <= 0xffffffff &&
      typeof settings.varyCurrent === 'boolean', 'version, graine ou option invalide.');
    return settings;
  }

  function settings(seed, varyCurrent = true) {
    return validate({ version, seed, varyCurrent });
  }

  function hash(seed, id, channel) {
    let result = (2166136261 ^ seed) >>> 0;
    for (const character of `oval-career-v1/${channel}/${id}`) {
      result ^= character.charCodeAt(0);
      result = Math.imul(result, 16777619) >>> 0;
    }
    result ^= result >>> 16;
    result = Math.imul(result, 0x7feb352d) >>> 0;
    result ^= result >>> 15;
    result = Math.imul(result, 0x846ca68b) >>> 0;
    return (result ^ (result >>> 16)) >>> 0;
  }

  function deltas(config, id) {
    validate(config);
    check(typeof id === 'string' && id.length > 0, 'identifiant de joueur absent.');
    // 68% of potentials and 84% of levels are unchanged or shifted by one.
    const draw = (channel, buckets) => {
      let value = hash(config.seed,id,channel) % 1000;
      for (const [delta, weight] of buckets) {
        if (value < weight) return delta;
        value -= weight;
      }
      throw Error('Distribution de variation invalide.');
    };
    return {
      potential: draw('potential', [[0,280],[-1,200],[1,200],[-2,100],[2,100],[-3,40],[3,40],[-4,15],[4,15],[-5,5],[5,5]]),
      current: config.varyCurrent ? draw('current', [[0,360],[-1,240],[1,240],[-2,65],[2,65],[-3,15],[3,15]]) : 0,
    };
  }

  function sourcePotential(source, id, config) {
    if (!config) return source;
    return clamp(source + deltas(config,id).potential,20,97);
  }

  function note(player) {
    return dependencies.roleNote ? dependencies.roleNote(player) : roleNote(player);
  }

  function player(source, config) {
    const result = copy(source);
    const variation = deltas(config,result.id);
    check(Number.isFinite(result.rating) && Number.isFinite(result.skillBase) && result.skills && result.dev &&
      Number.isFinite(result.dev.potential), 'profil initial incomplet : ' + result.id);
    if (variation.current) {
      const before = note(result);
      if (result.attributesV2) {
        check(attributes.every(key => Number.isFinite(result.attributesV2[key])), 'qualités initiales incomplètes.');
        const project = dependencies.projectSkills ?? lnrProjectV12;
        const originalProjection = project({ ...result, gameplayPosition:result.gameplayPosition || result.pos });
        result.attributesV2 = Object.fromEntries(attributes.map(key => [key,round(clamp(result.attributesV2[key]+variation.current,20,97))]));
        const variedProjection = project({ ...result, gameplayPosition:result.gameplayPosition || result.pos });
        // Preserve any existing source calibration offset instead of silently
        // replacing it. Only the effect of these changed attributes is applied.
        result.skills = Object.fromEntries(Object.entries(result.skills).map(([key,value]) =>
          [key,round(clamp(value+variedProjection[key]-originalProjection[key],15,99))]));
      } else {
        result.skills = Object.fromEntries(Object.entries(result.skills).map(([key,value]) => [key,round(clamp(value+variation.current,15,99))]));
        if (result.nativeAttributesV1 !== undefined) {
          check(typeof result.nativeAttributesV1 === 'string' && /^\d{72}$/.test(result.nativeAttributesV1), 'qualités compactes invalides.');
          result.nativeAttributesV1 = attributes.map((_,index) => String(clamp(Number(result.nativeAttributesV1.slice(index*2,index*2+2))+variation.current,20,97)).padStart(2,'0')).join('');
        }
      }
      const change = clamp(note(result)-before, Math.max(15-result.rating,15-result.skillBase), Math.min(99-result.rating,99-result.skillBase));
      result.rating += change;
      result.skillBase += change;
    }
    result.dev.potential = clamp(result.dev.potential+variation.potential,result.rating,99);
    result.dev.seasonStart = result.rating;
    if (Number.isFinite(source.potential)) result.potential = sourcePotential(source.potential,source.id,config);
    return result;
  }

  function populations(state) {
    return [
      ...state.clubs.map(club => club.players),state.development.academy,state.economy.freeAgents,state.market,
      ...(state.aiRoster?.academies ?? []).map(center => center.players),
      ...(state.nativeAcademy?.centers ?? []).filter(center => Array.isArray(center.players)).map(center => center.players),
    ];
  }

  function apply(state, config) {
    validate(config);
    if (state.careerVariation !== undefined) {
      validate(state.careerVariation);
      check(['version','seed','varyCurrent'].every(key => state.careerVariation[key] === config[key]), 'paramètres contradictoires.');
      return state;
    }
    check(state.season === 1 && state.round === 0 && !state.live, 'réservée à la création.');
    const canonical = new Map(), changes = new Map(), seen = new WeakSet();
    const fields = ['rating','skillBase','skills','attributesV2','nativeAttributesV1','potential','dev'];
    for (const pool of populations(state)) for (const original of pool) {
      if (seen.has(original)) continue;
      seen.add(original);
      if (!canonical.has(original.id)) {
        const varied = player(original,config);
        canonical.set(original.id,varied);
        changes.set(original.id,varied.rating-original.rating);
      }
      const varied = canonical.get(original.id);
      for (const field of fields) if (own(varied,field)) original[field] = typeof varied[field] === 'object' ? copy(varied[field]) : varied[field];
    }
    // These are initial coaching references, not past results or observations.
    const offices = [state,...Object.values(state.nativeAcademy?.offices ?? {})];
    for (const office of offices) {
      for (const record of office.v90to94?.profiles ?? []) {
        const delta = changes.get(record.id) ?? 0;
        for (const field of ['startRating','baseline']) if (Number.isFinite(record[field])) record[field] = clamp(record[field]+delta,15,99);
      }
      for (const record of office.v101to104?.paths ?? []) {
        if (record.createdSeason === 1 && changes.has(record.id)) record.startRating = clamp(record.startRating+changes.get(record.id),15,99);
      }
      for (const record of [...(office.v95to100?.candidates ?? []),...(office.v95to100?.network?.players ?? [])]) {
        if (seen.has(record) || !Number.isFinite(record.rating) || !Number.isFinite(record.potential)) continue;
        seen.add(record);
        const variation = deltas(config,record.id);
        record.rating = clamp(record.rating+variation.current,20,99);
        record.potential = clamp(record.potential+variation.potential,record.rating,99);
      }
    }
    state.careerVariation = copy(config);
    return state;
  }

  return Object.freeze({version,settings,validate,deltas,sourcePotential,player,apply});
};
