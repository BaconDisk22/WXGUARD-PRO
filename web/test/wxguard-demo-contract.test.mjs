import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const demo = readFileSync(resolve(root, 'demo.html'), 'utf8');
const index = readFileSync(resolve(root, 'index.html'), 'utf8');

test('standalone demo prominently identifies simulated weather', () => {
  assert.match(demo, /DEMONSTRATION · SIMULATED DATA/);
  assert.match(demo, /NOT A REAL WARNING/);
  assert.match(demo, /Do not use for safety decisions/);
  assert.match(demo, /Broadcasting <strong class="ok">DISABLED<\/strong>/);
});

test('demo remains a standalone page with no external resource dependencies', () => {
  assert.match(demo, /<meta name="viewport"/);
  assert.doesNotMatch(demo, /<script[^>]+src=/i);
  assert.doesNotMatch(demo, /<link[^>]+(?:href="https?:|rel="stylesheet")/i);
  assert.doesNotMatch(demo, /\b(?:fetch|WebSocket|navigator\.serial|navigator\.bluetooth)\s*\(/);
});

test('app manifest and WXGUARD branding assets exist', () => {
  const manifest = JSON.parse(readFileSync(resolve(root, 'manifest.webmanifest'), 'utf8'));
  assert.equal(manifest.name, 'WXGUARD PRO');
  assert.equal(manifest.display, 'standalone');
  for (const icon of manifest.icons) assert.ok(existsSync(resolve(root, icon.src)), icon.src);
  assert.match(index, /<title>WXGUARD PRO<\/title>/);
});

test('README preview image paths resolve to committed files', () => {
  const readme = readFileSync(resolve(root, '../README.md'), 'utf8');
  for (const path of ['wxguard-pro-desktop.png', 'wxguard-pro-mobile.png']) {
    assert.ok(readme.includes('screenshots/' + path));
    assert.ok(existsSync(resolve(root, '../screenshots', path)), path);
  }
});
