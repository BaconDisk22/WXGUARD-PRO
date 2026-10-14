import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

test('WXGUARD PRO loads its responsive theme', () => {
  const html = readFileSync(resolve(root, 'index.html'), 'utf8');
  assert.match(html, /<title>WXGUARD PRO<\/title>/);
  assert.match(html, /styles\/wxguard-responsive\.css/);
  assert.ok(existsSync(resolve(root, 'styles/wxguard-responsive.css')));
});

test('WXGUARD PRO retains offline radio entry point', () => {
  const html = readFileSync(resolve(root, 'index.html'), 'utf8');
  assert.match(html, /src\/app\/main\.js/);
  assert.ok(existsSync(resolve(root, 'src/app/main.js')));
});
