// Zips the build for upload to CrazyGames. index.html must sit at the root
// of the archive, so the zip is made from inside dist.
import { execFileSync } from 'node:child_process'
import { readdirSync, rmSync, statSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const web = join(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(web, 'dist')
const name = process.argv[2] ?? 'farm-web.zip'
const archive = join(web, name)

rmSync(archive, { force: true })
execFileSync('zip', ['-qr', archive, '.'], { cwd: dist })

const files = readdirSync(dist, { recursive: true }).filter((file) => statSync(join(dist, String(file))).isFile())
const megabytes = (statSync(archive).size / 1_000_000).toFixed(2)
console.log(`package: ${name}, ${files.length} files, ${megabytes} MB`)
