// Test de scripts/diff-captures.cjs : images générées en mémoire, rectangle ajouté, zone retrouvée.
const fs = require("fs"), os = require("os"), path = require("path"), assert = require("assert");
const { execFileSync, spawnSync } = require("child_process");
const { encoderPng, decoderPng } = require("../scripts/diff-captures.cjs");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "diffcap-"));
const L = 1920, H = 1080;
const base = { l: L, h: H, rgba: Buffer.alloc(L * H * 4) };
for (let y = 0; y < H; y++) for (let x = 0; x < L; x++) { const o = (y * L + x) * 4; base.rgba[o] = x % 256; base.rgba[o + 1] = y % 256; base.rgba[o + 2] = 90; base.rgba[o + 3] = 255; }
const mod = { l: L, h: H, rgba: Buffer.from(base.rgba) };
for (let y = 300; y < 340; y++) for (let x = 500; x < 620; x++) { const o = (y * L + x) * 4; mod.rgba[o] = 255; mod.rgba[o + 1] = 0; mod.rgba[o + 2] = 0; }
const A = path.join(dir, "a.png"), B = path.join(dir, "b.png");
fs.writeFileSync(A, encoderPng(base)); fs.writeFileSync(B, encoderPng(mod));
assert.strictEqual(decoderPng(fs.readFileSync(A)).rgba.compare(base.rgba), 0);
const script = path.join(__dirname, "..", "scripts", "diff-captures.cjs");
assert.strictEqual(execFileSync(process.execPath, [script, A, A]).toString().trim(), "identiques");
const out = spawnSync(process.execPath, [script, A, B, "--sortie", dir]).stdout.toString();
assert.ok(/ 500, 300, 120, 40 /.test(out), out);
assert.ok(fs.existsSync(path.join(dir, "b-zone1.png")));
fs.rmSync(dir, { recursive: true, force: true });
console.log("diff-captures : OK");
