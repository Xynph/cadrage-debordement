#!/usr/bin/env node
// Compare deux captures PNG et ne rend que les zones changées (vignettes « avant | après »).
//   node scripts/diff-captures.cjs <avant.png> <apres.png> [--sortie <dossier>] [--seuil N]
// Défaut : seuil 24 (somme des écarts RGB), sortie temp/diff-captures/. Sans dépendance (zlib Node).
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const FUSION = 16, MAX_ZONES = 6, MARGE = 12, LARGEUR_MAX = 900;

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = (crc ^ buf[i]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function decoderPng(buf) {
  if (buf.readUInt32BE(0) !== 0x89504e47) throw new Error("pas un PNG");
  let pos = 8, l = 0, h = 0, profondeur = 0, type = 0, entrelace = 0;
  const morceaux = [];
  let palette = null;
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const nom = buf.toString("latin1", pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (nom === "IHDR") {
      l = data.readUInt32BE(0); h = data.readUInt32BE(4);
      profondeur = data[8]; type = data[9]; entrelace = data[12];
    } else if (nom === "PLTE") palette = data;
    else if (nom === "IDAT") morceaux.push(data);
    else if (nom === "IEND") break;
    pos += 12 + len;
  }
  if (profondeur !== 8 || entrelace !== 0 || ![2, 3, 6].includes(type))
    throw new Error("PNG non géré (8 bits RGB/RGBA/palette non entrelacé seulement)");
  const canaux = type === 2 ? 3 : type === 6 ? 4 : 1;
  const raw = zlib.inflateSync(Buffer.concat(morceaux));
  const stride = l * canaux;
  const cur = Buffer.alloc(stride), prev = Buffer.alloc(stride);
  const rgba = Buffer.alloc(l * h * 4);
  let p = 0;
  for (let y = 0; y < h; y++) {
    const f = raw[p++];
    raw.copy(cur, 0, p, p + stride); p += stride;
    for (let i = 0; i < stride; i++) {
      const a = i >= canaux ? cur[i - canaux] : 0, b = prev[i], c = i >= canaux ? prev[i - canaux] : 0;
      let v = cur[i];
      if (f === 1) v += a;
      else if (f === 2) v += b;
      else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) {
        const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      cur[i] = v & 255;
    }
    for (let x = 0; x < l; x++) {
      const o = (y * l + x) * 4;
      if (canaux === 1) { const q = cur[x] * 3; rgba[o] = palette[q]; rgba[o + 1] = palette[q + 1]; rgba[o + 2] = palette[q + 2]; rgba[o + 3] = 255; }
      else { rgba[o] = cur[x * canaux]; rgba[o + 1] = cur[x * canaux + 1]; rgba[o + 2] = cur[x * canaux + 2]; rgba[o + 3] = canaux === 4 ? cur[x * canaux + 3] : 255; }
    }
    cur.copy(prev);
  }
  return { l, h, rgba };
}

function encoderPng(img) {
  const { l, h, rgba } = img;
  const raw = Buffer.alloc((l * 4 + 1) * h);
  for (let y = 0; y < h; y++) rgba.copy(raw, y * (l * 4 + 1) + 1, y * l * 4, (y + 1) * l * 4);
  const morceau = (nom, data) => {
    const b = Buffer.alloc(12 + data.length);
    b.writeUInt32BE(data.length, 0); b.write(nom, 4, "latin1"); data.copy(b, 8);
    b.writeUInt32BE(crc32(b.subarray(4, 8 + data.length)), 8 + data.length);
    return b;
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(l, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    morceau("IHDR", ihdr), morceau("IDAT", zlib.deflateSync(raw)), morceau("IEND", Buffer.alloc(0))]);
}

function zonesDiff(a, b, seuil) {
  const { l, h } = a;
  let n = 0;
  let boites = [];
  for (let y = 0; y < h; y++) {
    let x0 = -1, x1 = -1;
    for (let x = 0; x < l; x++) {
      const o = (y * l + x) * 4;
      const d = Math.abs(a.rgba[o] - b.rgba[o]) + Math.abs(a.rgba[o + 1] - b.rgba[o + 1]) + Math.abs(a.rgba[o + 2] - b.rgba[o + 2]);
      if (d > seuil) { n++; if (x0 < 0) x0 = x; x1 = x; }
    }
    if (x0 >= 0) boites.push({ x0, y0: y, x1, y1: y });
  }
  // fusion itérative des boîtes proches (< FUSION px)
  const proche = (p, q) => p.x0 - FUSION <= q.x1 && q.x0 - FUSION <= p.x1 && p.y0 - FUSION <= q.y1 && q.y0 - FUSION <= p.y1;
  let change = true;
  while (change) {
    change = false;
    const sortie = [];
    for (const b2 of boites) {
      const m = sortie.find((s) => proche(s, b2));
      if (m) { m.x0 = Math.min(m.x0, b2.x0); m.y0 = Math.min(m.y0, b2.y0); m.x1 = Math.max(m.x1, b2.x1); m.y1 = Math.max(m.y1, b2.y1); change = true; }
      else sortie.push({ ...b2 });
    }
    boites = sortie;
  }
  // au-delà de MAX_ZONES : on garde les plus grandes, les autres sont absorbées dans la dernière gardée
  while (boites.length > MAX_ZONES) {
    boites.sort((p, q) => (q.x1 - q.x0) * (q.y1 - q.y0) - (p.x1 - p.x0) * (p.y1 - p.y0));
    const petit = boites.pop(), cible = boites[boites.length - 1];
    cible.x0 = Math.min(cible.x0, petit.x0); cible.y0 = Math.min(cible.y0, petit.y0);
    cible.x1 = Math.max(cible.x1, petit.x1); cible.y1 = Math.max(cible.y1, petit.y1);
  }
  boites.sort((p, q) => p.y0 - q.y0 || p.x0 - q.x0);
  return { n, zones: boites.map((z) => ({ x: z.x0, y: z.y0, l: z.x1 - z.x0 + 1, h: z.y1 - z.y0 + 1 })) };
}

function vignette(a, b, z) {
  const x0 = Math.max(0, z.x - MARGE), y0 = Math.max(0, z.y - MARGE);
  const x1 = Math.min(a.l, z.x + z.l + MARGE), y1 = Math.min(a.h, z.y + z.h + MARGE);
  const w = x1 - x0, h = y1 - y0, sep = 4, W = w * 2 + sep;
  const out = { l: W, h, rgba: Buffer.alloc(W * h * 4, 255) };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const s = ((y0 + y) * a.l + x0 + x) * 4;
    a.rgba.copy(out.rgba, (y * W + x) * 4, s, s + 4);
    b.rgba.copy(out.rgba, (y * W + w + sep + x) * 4, s, s + 4);
  }
  for (let y = 0; y < h; y++) for (let x = 0; x < sep; x++) { const o = (y * W + w + x) * 4; out.rgba[o] = 255; out.rgba[o + 1] = 0; out.rgba[o + 2] = 255; }
  if (W <= LARGEUR_MAX) return out;
  const f = LARGEUR_MAX / W, nl = LARGEUR_MAX, nh = Math.max(1, Math.round(h * f));
  const red = { l: nl, h: nh, rgba: Buffer.alloc(nl * nh * 4) };
  for (let y = 0; y < nh; y++) for (let x = 0; x < nl; x++) {
    const sx0 = Math.floor(x / f), sx1 = Math.max(sx0 + 1, Math.floor((x + 1) / f));
    const sy0 = Math.floor(y / f), sy1 = Math.max(sy0 + 1, Math.floor((y + 1) / f));
    const acc = [0, 0, 0, 0]; let c = 0;
    for (let yy = sy0; yy < Math.min(sy1, h); yy++) for (let xx = sx0; xx < Math.min(sx1, W); xx++) {
      const o = (yy * W + xx) * 4;
      for (let k = 0; k < 4; k++) acc[k] += out.rgba[o + k];
      c++;
    }
    for (let k = 0; k < 4; k++) red.rgba[(y * nl + x) * 4 + k] = Math.round(acc[k] / (c || 1));
  }
  return red;
}

function principal(argv) {
  const pos = [];
  let sortie = path.join(__dirname, "..", "temp", "diff-captures"), seuil = 24;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--sortie") sortie = path.resolve(argv[++i]);
    else if (argv[i] === "--seuil") seuil = Number(argv[++i]);
    else pos.push(argv[i]);
  }
  if (pos.length !== 2 || !(seuil >= 0)) {
    console.error("usage : node scripts/diff-captures.cjs <avant.png> <apres.png> [--sortie <dossier>] [--seuil N]");
    return 2;
  }
  const a = decoderPng(fs.readFileSync(pos[0])), b = decoderPng(fs.readFileSync(pos[1]));
  if (a.l !== b.l || a.h !== b.h) { console.log(`tailles différentes : ${a.l}x${a.h} contre ${b.l}x${b.h}`); return 1; }
  const { n, zones } = zonesDiff(a, b, seuil);
  if (n === 0) { console.log("identiques"); return 0; }
  fs.mkdirSync(sortie, { recursive: true });
  const nom = path.basename(pos[1], ".png");
  const txt = [`${a.l}x${a.h}, ${(100 * n / (a.l * a.h)).toFixed(2)} % de pixels changés, ${zones.length} zone(s) (x, y, l, h) :`];
  zones.forEach((z, i) => {
    const v = vignette(a, b, z), f = path.join(sortie, `${nom}-zone${i + 1}.png`);
    fs.writeFileSync(f, encoderPng(v));
    txt.push(`  ${i + 1}. ${z.x}, ${z.y}, ${z.l}, ${z.h} -> ${f} (${v.l}x${v.h})`);
  });
  console.log(txt.join("\n"));
  return 1;
}

if (require.main === module) process.exit(principal(process.argv.slice(2)));
module.exports = { decoderPng, encoderPng, zonesDiff };
