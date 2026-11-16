'use strict';

// Copie équivalente à JSON.parse(JSON.stringify(value)), deux fois plus rapide sur les joueurs et
// fiches (objets et tableaux simples). Fabrique sérialisée dans la VM du moteur (worker.cjs :
// nativeJsonCopy). Tout ce qui n'est pas une donnée JSON simple (toJSON, Map, Date, classe, clé
// « __proto__ », BigInt) repasse par JSON : le résultat reste celui de JSON dans tous les cas.
module.exports = function createJsonCopy() {
  const viaJson = x => JSON.parse(JSON.stringify(x));
  const own = Object.prototype.hasOwnProperty, source = Function.prototype.toString;
  const unsupported = { unsupported: true };
  // Prototypes Object et Array d'origine, de ce contexte ou d'un autre (les catalogues du monde sont
  // construits hors de la VM) : chacun est vérifié une fois.
  const objects = new Set([Object.prototype]), arrays = new Set([Array.prototype]);
  function builtin(proto, name, known) {
    if (known.has(proto)) return true;
    if (!proto || !own.call(proto, 'constructor')) return false;
    const constructor = proto.constructor, parent = Object.getPrototypeOf(proto);
    const ok = typeof constructor === 'function' && constructor.name === name && constructor.prototype === proto &&
      /\{\s*\[native code\]\s*\}\s*$/.test(source.call(constructor)) &&
      (name === 'Object' ? parent === null : builtin(parent, 'Object', objects));
    if (ok) known.add(proto);
    return ok;
  }
  const skipped = x => x === undefined || typeof x === 'function' || typeof x === 'symbol';
  function clone(x) {
    if (x === null) return null;
    switch (typeof x) {
      case 'string': case 'boolean': return x;
      case 'number': return Number.isFinite(x) ? (x === 0 ? 0 : x) : null;
      case 'object': break;
      default: throw unsupported;
    }
    if (Array.isArray(x)) {
      if (!builtin(Object.getPrototypeOf(x), 'Array', arrays) || own.call(x, 'toJSON')) throw unsupported;
      const length = x.length, out = new Array(length);
      for (let i = 0; i < length; i++) { const item = x[i]; out[i] = skipped(item) ? null : clone(item); }
      return out;
    }
    const proto = Object.getPrototypeOf(x);
    if ((proto !== null && !builtin(proto, 'Object', objects)) || typeof x.toJSON === 'function') throw unsupported;
    const out = {};
    for (const key in x) {
      if (key === '__proto__' || !own.call(x, key)) throw unsupported;
      const item = x[key];
      if (!skipped(item)) out[key] = clone(item);
    }
    return out;
  }
  return function jsonCopy(value) {
    if (value === null || typeof value !== 'object') return viaJson(value);
    try { return clone(value); }
    catch (error) { if (error === unsupported) return viaJson(value); throw error; }
  };
};
