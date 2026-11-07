import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

test('WXGUARD PRO loads its design tokens before every other stylesheet', () => {
  const html = readFileSync(resolve(root, 'index.html'), 'utf8');
  assert.match(html, /<title>WXGUARD PRO<\/title>/);
  const sheets = [...html.matchAll(/<link rel="stylesheet" href="([^"]+)">/g)].map((m) => m[1]);
  assert.equal(sheets[0], 'styles/tokens.css');
  for (const sheet of sheets) assert.ok(existsSync(resolve(root, sheet)), sheet);
});

test('colours are defined only in the token file', () => {
  for (const sheet of ['app.css', 'place.css', 'radio.css']) {
    const css = readFileSync(resolve(root, 'styles', sheet), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
    const hex = css.match(/#[0-9a-fA-F]{3,8}\b/g) ?? [];
    assert.deepEqual(hex.filter((h) => !/^#fff(fff)?$/i.test(h)), [], `${sheet} has hard-coded colours`);
  }
});

test('WXGUARD PRO retains offline radio entry point', () => {
  const html = readFileSync(resolve(root, 'index.html'), 'utf8');
  assert.match(html, /src\/app\/main\.js/);
  assert.ok(existsSync(resolve(root, 'src/app/main.js')));
});

test('user-facing strings name this app WXGUARD PRO, not the upstream app', () => {
  const dir = resolve(root, 'strings');
  for (const file of readdirSync(dir).filter((name) => name.endsWith('.json'))) {
    assert.doesNotMatch(readFileSync(resolve(dir, file), 'utf8'), /DigitainoMesh/, file);
  }
});

test('the browser loads every web-only string table in strings/', () => {
  const main = readFileSync(resolve(root, 'src/app/main.js'), 'utf8');
  const listed = main.match(/const WEB_TABLES = \[([\s\S]*?)\]/)[1].match(/'[^']+'/g).map((name) => name.slice(1, -1));
  const present = readdirSync(resolve(root, 'strings')).filter((name) => /^web\..*en\.json$|^web\.en\.json$/.test(name));
  assert.deepEqual([...listed].sort(), [...present].sort());
});
