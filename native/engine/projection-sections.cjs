'use strict';
// Sections lourdes de la réponse reprises d'une réponse à l'autre (réactivité de l'interface, lot 19).
//
// Le modèle envoyé à l'interface pèse ~13 Mo, dont ~11 Mo dans quelques sections : marché entre clubs, carrière du
// staff, carnet du manager, centre de formation… (domaines mémorisables de native-systems.cjs) et `staff` (tiré de la
// carrière du staff). Leur présentation finale (packs d'identité, portraits, connaissance des joueurs) ne dépend que
// de leur texte brut (repris tel quel par la mémoire des domaines quand les sections de la carrière qu'ils lisent
// n'ont pas changé) et de quelques réglages globaux (mode, frontière de connaissance, pack). Quand ces entrées sont
// celles de la réponse précédente, la section n'est ni relue (JSON.parse), ni reparcourue (packs, portraits,
// connaissance), ni resérialisée : sa présentation et son texte précédents sont repris.
//
// Pendant le parcours de la projection, une section reprise est remplacée par une sentinelle (objet vide marqué) que
// les parcours ignorent ; les lecteurs qui en ont besoin (planification du manager) reçoivent l'objet final mémorisé
// (`reveal`). À la fin (`finish`), le texte de chaque section du modèle est joint au modèle (symbole TEXTS, lu par
// l'encodeur différentiel sans resérialiser) et les sections lourdes deviennent des propriétés paresseuses (lues depuis
// leur texte à la première lecture) : aucun appelant ne reçoit l'objet mémorisé lui-même.
const { NESTED, TEXTS } = require('./model-delta.cjs');

const SENTINEL = Symbol.for('cd.sectionSentinel');
const RETRY = 'cd.sections.retry';
const plain = value => !!value && typeof value === 'object' && !Array.isArray(value);
const sentinelOf = value => (value && typeof value === 'object' && value[SENTINEL]) || null;
function sentinel(path) { const out = {}; Object.defineProperty(out, SENTINEL, { value: path }); return out; }

// Texte d'une valeur de premier niveau, tel que l'encodeur le découpe : chaîne, ou {keys, texts} pour une clé imbriquée.
function textOf(key, value) {
  if (NESTED.has(key) && plain(value)) {
    const keys = [], texts = new Map();
    for (const name of Object.keys(value)) { const text = JSON.stringify(value[name]); if (text === undefined) continue; keys.push(name); texts.set(name, text); }
    return { keys, texts };
  }
  return JSON.stringify(value);
}

function lazy(container, key, text) {
  Object.defineProperty(container, key, {
    configurable: true, enumerable: true,
    get() { const value = JSON.parse(text); Object.defineProperty(container, key, { value, writable: true, configurable: true, enumerable: true }); return value; },
    set(value) { Object.defineProperty(container, key, { value, writable: true, configurable: true, enumerable: true }); },
  });
}
function lazyNested(container, key, nested) {
  const out = {};
  for (const name of nested.keys) lazy(out, name, nested.texts.get(name));
  Object.defineProperty(container, key, { value: out, writable: true, configurable: true, enumerable: true });
}

function createSectionMemo() {
  // chemin → {raw, globals, packSig, text, object, carried}
  const cache = new Map();
  let active = null;
  const sameRaw = (a, b) => Array.isArray(a) ? Array.isArray(b) && a.length === b.length && a.every((x, i) => x === b[i]) : a === b;

  let lastGlobals = null;
  // `verify` : aucune section n'est reprise ; celles qui l'auraient été sont recalculées et leur texte final doit être
  // celui de la mémoire (vérifié dans finish).
  function begin({ globals, bypass = true, verify = false }) {
    if (globals === lastGlobals) globals = lastGlobals; else lastGlobals = globals;
    active = { globals, bypass, verify, bypassed: new Map(), computed: new Map(), carried: new Map(), expected: new Map(), packSig: null };
    return active;
  }
  const valid = (path, raw) => { const entry = cache.get(path); return !!entry && entry.globals === active.globals && sameRaw(entry.raw, raw) ? entry : null; };
  // Section reprise si son texte brut et les réglages globaux sont ceux de la dernière présentation mémorisée.
  function take(path, raw) { return takeAll([[path, raw]])[0]; }
  // Sections liées (carrière du staff et `staff`) : reprises ensemble ou recalculées ensemble.
  function takeAll(list) {
    if (!active) return list.map(() => null);
    const entries = list.map(([path, raw]) => active.bypass ? valid(path, raw) : null);
    for (const [path, raw] of list) active.computed.set(path, raw);
    if (!entries.every(Boolean)) return list.map(() => null);
    if (active.verify) { list.forEach(([path], i) => active.expected.set(path, entries[i].text)); return list.map(() => null); }
    return list.map(([path], i) => { active.computed.delete(path); active.bypassed.set(path, entries[i]); return sentinel(path); });
  }
  // Section toujours recalculée mais mémorisée (présentation gardée pendant le direct du match).
  function note(path) { if (active) active.computed.set(path, null); }
  // Direct du match : section gardée telle que présentée à la dernière réponse complète (rien n'est recalculé).
  function keep(path) {
    if (!active || !active.bypass) return null;
    const entry = cache.get(path);
    if (!entry || entry.globals !== active.globals) return null;
    active.bypassed.set(path, entry);
    return sentinel(path);
  }
  const kept = path => !!active && active.bypassed.has(path);
  const available = path => { const entry = cache.get(path); return !!entry && !!active && entry.globals === active.globals; };
  // Pack d'identité : la présentation reprise suppose les mêmes remplacements de noms. Sinon, projection recalculée.
  function packSignature(signature) {
    if (!active) return;
    active.packSig = signature;
    for (const entry of active.bypassed.values()) if (entry.packSig !== signature) { const error = Error('Sections à recalculer (pack).'); error.code = RETRY; throw error; }
  }
  const carriedOf = path => cache.get(path)?.carried ?? null;
  const recordCarried = (path, entries) => { if (active) active.carried.set(path, entries); };
  // Lecteurs en lecture seule après la connaissance : objets finals mémorisés à la place des sentinelles.
  function reveal(model) {
    if (!active) return;
    // Objet final relu depuis son texte à la première lecture seulement, puis gardé avec l'entrée (seules les sections
    // réellement lues — le marché pour la planification — occupent la mémoire sous forme d'objets).
    const final = entry => { if (entry.object === null) entry.object = JSON.parse(entry.text); return entry.object; };
    for (const [path, entry] of active.bypassed) {
      if (typeof entry.text !== 'string') continue;
      const [top, name] = path.split('.'), container = name ? model[top] : model, key = name || top;
      if (!plain(container) || !sentinelOf(container[key])) continue;
      Object.defineProperty(container, key, { configurable: true, enumerable: true, get: () => final(entry), set(value) { Object.defineProperty(container, key, { value, writable: true, configurable: true, enumerable: true }); } });
    }
  }
  // Texte de chaque section ; mémorisation des sections lourdes recalculées ; propriétés paresseuses.
  function finish(model) {
    const context = active; active = null;
    if (!context || !plain(model)) return model;
    const keys = [], items = new Map(), heavy = [];
    const remember = (path, text) => cache.set(path, { raw: context.computed.get(path), globals: context.globals, packSig: context.packSig, text, object: null, carried: context.carried.get(path) ?? [] });
    for (const key of Object.keys(model)) {
      const value = model[key], whole = context.bypassed.get(key);
      if (whole) { keys.push(key); items.set(key, whole.text); heavy.push([model, key, whole.text]); continue; }
      if (context.computed.has(key)) {
        const text = textOf(key, value);
        if (text === undefined) continue;
        remember(key, text); heavy.push([model, key, text]);
        keys.push(key); items.set(key, text); continue;
      }
      if (NESTED.has(key) && plain(value)) {
        const inner = { keys: [], texts: new Map() };
        for (const name of Object.keys(value)) {
          const path = key + '.' + name, entry = context.bypassed.get(path);
          let text;
          if (entry) { text = entry.text; heavy.push([value, name, text]); }
          else {
            text = JSON.stringify(value[name]);
            if (text !== undefined && context.computed.has(path)) { remember(path, text); heavy.push([value, name, text]); }
          }
          if (text === undefined) continue;
          inner.keys.push(name); inner.texts.set(name, text);
        }
        keys.push(key); items.set(key, inner);
        continue;
      }
      const text = textOf(key, value);
      if (text === undefined) continue;
      keys.push(key); items.set(key, text);
    }
    for (const [path, expected] of context.expected) {
      const [top, name] = path.split('.'), item = items.get(top);
      const actual = name ? item?.texts?.get(name) : item;
      const same = typeof expected === 'string' ? expected === actual : !!actual && typeof actual === 'object' && expected.keys.join('\u0000') === actual.keys.join('\u0000') && expected.keys.every(k => expected.texts.get(k) === actual.texts.get(k));
      if (!same) throw Error('Section reprise différente du calcul complet : ' + path + '.');
    }
    for (const [container, key, text] of heavy) {
      if (typeof text === 'string') lazy(container, key, text); else lazyNested(container, key, text);
    }
    Object.defineProperty(model, TEXTS, { value: { keys, items }, configurable: true });
    return model;
  }
  function abort() { active = null; }
  function clear() { cache.clear(); active = null; }
  return { begin, take, takeAll, note, keep, kept, available, packSignature, carriedOf, recordCarried, reveal, finish, abort, clear, sentinel, size: () => cache.size };
}

// Vérification : textes de deux modèles comparés section par section (chemins « clé » ou « clé.sous-clé »).
function differences(expected, actual, limit = 8) {
  const out = [], a = expected[TEXTS] || textsFor(expected), b = actual[TEXTS] || textsFor(actual);
  const flat = s => { const m = new Map(); for (const key of s.keys) { const item = s.items.get(key); if (typeof item === 'string') m.set(key, item); else { m.set(key + '/', item.keys.join(',')); for (const name of item.keys) m.set(key + '.' + name, item.texts.get(name)); } } m.set('/', s.keys.join(',')); return m; };
  const fa = flat(a), fb = flat(b);
  for (const key of new Set([...fa.keys(), ...fb.keys()])) if (fa.get(key) !== fb.get(key)) { out.push(key); if (out.length >= limit) break; }
  return out;
}
function textsFor(model) {
  const keys = [], items = new Map();
  for (const key of Object.keys(model)) { const text = textOf(key, model[key]); if (text === undefined) continue; keys.push(key); items.set(key, text); }
  return { keys, items };
}

// Catalogues de création des éditions du monde (meta.*Catalogue, ~0,5 Mo) : données fixes, mémorisées dans la VM par
// édition (world-model.cjs, catalogue(R)). Lus avec le modèle, ils sont remplacés par un jeton d'identité ; la section
// n'est relue (texte) que si son jeton ou les réglages globaux ont changé. `meta.catalogue` (lu par le staff et les
// packs) n'est pas concerné.
const CATALOGUES = Object.freeze(['worldCatalogue', 'pacificCatalogue', 'japanCatalogue', 'nationaleCatalogue', 'champCatalogue']);
const CATALOGUE_SOURCE = `globalThis.nativeCatalogueSections=(()=>{
 const KEYS=${JSON.stringify(CATALOGUES)},ids=new WeakMap();let serial=0,last=new Map();
 return {
  // Texte JSON de [modèle, {clé: jeton}] : catalogues retirés du modèle (valeur null à leur place, ordre des clés gardé).
  read(){const m=nativeModel(),tokens={};last=new Map();
   for(const key of KEYS){const value=m?.meta?.[key];if(!value||typeof value!=='object')continue;let id=ids.get(value);if(!id){id='catalogue#'+(++serial);ids.set(value,id);}last.set(key,value);tokens[key]=id;m.meta[key]=null;}
   return JSON.stringify([m,tokens]);},
  text(key){return JSON.stringify(last.get(key));}
 };
})();`;

module.exports = { CATALOGUES, CATALOGUE_SOURCE, createSectionMemo, sentinel, sentinelOf, SENTINEL, RETRY, differences, textsFor, textOf };
