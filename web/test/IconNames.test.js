// Every icon a screen names by a literal string must exist: a missing one draws a placeholder
// box, which is easy to miss on one screen and looks broken to whoever lands there.
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { hasIcon } from '../src/ui/kit/icons.js'

const src = join(dirname(fileURLToPath(import.meta.url)), '..', 'src')
const files = (dir) => readdirSync(dir).flatMap((name) => {
  const path = join(dir, name)
  return statSync(path).isDirectory() ? files(path) : path.endsWith('.js') ? [path] : []
})

test('every literal icon name used in the source exists', () => {
  const missing = []
  const pattern = /\bicon(?:Name)?\s*[(:]\s*'([a-z][a-z0-9.]*)'/g
  for (const file of files(src)) {
    if (file.endsWith('icons.js')) continue
    for (const match of readFileSync(file, 'utf8').matchAll(pattern)) {
      const name = match[1] ?? match[2]
      if (!hasIcon(name)) missing.push(`${file.slice(src.length + 1)}: ${name}`)
    }
  }
  assert.deepEqual(missing, [])
})
