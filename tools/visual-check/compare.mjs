// Prototype vs app, station by station (see README.md).
// Needs out/ours.json and out/shots.json from PlateKit:  PL8_SCENE_DUMP=$PWD/out swift test --filter SceneDump
// Writes out/<station>.png (prototype | app | difference), out/report.json and out/report.md.
// Fails when a station is less alike than baseline.json says it was (minus a small margin).
import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import http from 'http'; import fs from 'fs'; import path from 'path'; import { fileURLToPath } from 'url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const out = path.join(here, 'out');
const W = 390, H = 844, MARGIN = 0.01;   // fail if another 1 % of the picture starts to differ
const shots = JSON.parse(fs.readFileSync(path.join(out, 'shots.json'), 'utf8'));
const stations = (process.env.STATIONS || 'overview,corner,nameFlag,flag,bar,pr,board,kit,setv').split(',');
const baselinePath = path.join(here, 'baseline.json');
const baseline = fs.existsSync(baselinePath) ? JSON.parse(fs.readFileSync(baselinePath, 'utf8')) : {};

const types = { '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.html': 'text/html' };
const server = http.createServer((q, r) => {
  const file = path.join(repo, decodeURIComponent(q.url.split('?')[0]));
  if (!file.startsWith(repo)) { r.writeHead(403); r.end(); return; }
  fs.readFile(file, (err, data) => { if (err) { r.writeHead(404); r.end(); } else { r.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream' }); r.end(data); } });
}).listen(0);
const base = `http://localhost:${server.address().port}`;

const browser = await chromium.launch({
  executablePath: process.env.PW_CHROMIUM || undefined,
  args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});

async function page(url) {
  const p = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  // Will's palette and look, as the prototype's Layout Lab saved them (scene-layout-and-look.json).
  await p.addInitScript(() => {
    localStorage.setItem('dz-art', JSON.stringify({ boxLight: '#F0E2F3', boxDark: '#6C3713', bgColor: '#FF6200', bgMode: 'colour', flagFont: 'playfair' }));
    localStorage.setItem('layoutlab-look', JSON.stringify({ v2: true, bg: 'flat' }));
  });
  p.on('pageerror', (e) => console.log('page error:', e.message.slice(0, 200)));
  await p.goto(base + url);
  await p.waitForFunction(() => window.ready, null, { timeout: 180000 });
  const ready = await p.evaluate(() => window.ready);
  if (ready !== 'ok') throw new Error(url + ': ' + ready);
  return p;
}

const proto = await page('/tools/visual-check/prototype.html');
const ours = await page('/tools/visual-check/ours.html');

function decode(buffer) { return PNG.sync.read(buffer); }
/// The share of 3×3 blocks (small enough to keep a plate, big enough to blur single-pixel line jitter) whose colour
/// clearly differs, as 1 − that share: 1 means nothing visibly different.
function similarity(a, b) {
  const s = 3, w = Math.floor(W / s), h = Math.floor(H / s);
  const diff = new PNG({ width: W, height: H });
  let total = 0;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const ca = [0, 0, 0], cb = [0, 0, 0];
    for (let dy = 0; dy < s; dy++) for (let dx = 0; dx < s; dx++) {
      const i = ((y * s + dy) * W + (x * s + dx)) * 4;
      for (let k = 0; k < 3; k++) { ca[k] += a.data[i + k]; cb[k] += b.data[i + k]; }
    }
    const d = (Math.abs(ca[0] - cb[0]) + Math.abs(ca[1] - cb[1]) + Math.abs(ca[2] - cb[2])) / (3 * 255 * s * s);
    if (d > 0.12) total += 1;
    for (let dy = 0; dy < s; dy++) for (let dx = 0; dx < s; dx++) {
      const i = ((y * s + dy) * W + (x * s + dx)) * 4, v = Math.min(255, d * 255 * 4);
      diff.data[i] = 255; diff.data[i + 1] = 255 - v; diff.data[i + 2] = 255 - v; diff.data[i + 3] = 255;
    }
  }
  return { score: 1 - total / (w * h), diff };
}

function sideBySide(images) {
  const gap = 8, png = new PNG({ width: W * images.length + gap * (images.length - 1), height: H });
  png.data.fill(255);
  images.forEach((img, n) => PNG.bitblt(img, png, 0, 0, W, H, n * (W + gap), 0));
  return PNG.sync.write(png);
}

const report = [];
let failed = false;
for (const station of stations) {
  const shot = shots[station];
  if (!shot) continue;
  await proto.evaluate(({ T, P, fov }) => {
    const c = window.C;
    c.camera.fov = fov; c.camera.updateProjectionMatrix(); c.controls.target.set(...T); c.camera.position.set(...P); c.fovGoal = fov;
    for (let i = 0; i < 3; i++) c.frame(0.016, 1 + i * 0.016);
  }, shot);
  await ours.evaluate(({ T, P, fov }) => window.show(T, P, fov), shot);
  const a = decode(await proto.screenshot()), b = decode(await ours.screenshot());
  const { score, diff } = similarity(a, b);
  fs.writeFileSync(path.join(out, `${station}.png`), sideBySide([a, b, diff]));
  const floor = baseline[station] != null ? baseline[station] - MARGIN : null;
  const ok = floor == null || score >= floor;
  if (!ok) failed = true;
  report.push({ station, score: +score.toFixed(4), baseline: baseline[station] ?? null, ok });
  console.log(`${ok ? '✔' : '✘'} ${station.padEnd(9)} ${(score * 100).toFixed(1)}%${floor != null ? `  (baseline ${(baseline[station] * 100).toFixed(1)}%)` : '  (no baseline)'}`);
}
await browser.close(); server.close();

fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
fs.writeFileSync(path.join(out, 'report.md'), ['| Station | Alike | Baseline | |', '|---|---|---|---|',
  ...report.map((r) => `| ${r.station} | ${(r.score * 100).toFixed(1)}% | ${r.baseline != null ? (r.baseline * 100).toFixed(1) + '%' : '—'} | ${r.ok ? '✔' : '✘'} |`)].join('\n') + '\n');
if (process.env.UPDATE_BASELINE) {
  fs.writeFileSync(baselinePath, JSON.stringify(Object.fromEntries(report.map((r) => [r.station, r.score])), null, 2) + '\n');
  console.log('baseline updated');
}
process.exit(failed ? 1 : 0);
