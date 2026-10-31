// Times how long the real build takes to reach play in desktop Chrome, and
// reports any errors, on a fast connection and on a slow one with a slow CPU.
//
//   npm run build && node promo/check-load.mjs
import { createReadStream, existsSync, statSync } from 'node:fs'
import { createServer } from 'node:http'
import { dirname, extname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import puppeteer, { PredefinedNetworkConditions } from 'puppeteer-core'

const web = join(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(web, 'dist')
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.ttf': 'font/ttf', '.txt': 'text/plain' }

const server = createServer((request, response) => {
  const path = join(dist, decodeURIComponent(request.url.split('?')[0]).replace(/\/$/, '/index.html'))
  if (!existsSync(path) || !statSync(path).isFile()) {
    response.writeHead(404).end()
    return
  }
  response.writeHead(200, { 'content-type': types[extname(path)] ?? 'application/octet-stream' })
  createReadStream(path).pipe(response)
})
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
const url = `http://127.0.0.1:${server.address().port}/`

const browser = await puppeteer.launch({ executablePath: chrome, headless: true })
const runs = [
  { name: 'fast connection', cpu: 1, network: null },
  { name: 'slow 4G, CPU 4× slower', cpu: 4, network: PredefinedNetworkConditions['Slow 4G'] },
]
let failed = false
for (const run of runs) {
  const context = await browser.createBrowserContext()
  const page = await context.newPage()
  const problems = []
  page.on('pageerror', (error) => problems.push(`page error: ${error.message}`))
  page.on('console', (message) => {
    if (message.type() === 'error') problems.push(`console error: ${message.text()}`)
  })
  page.on('requestfailed', (request) => problems.push(`failed request: ${request.url()}`))
  await page.setCacheEnabled(false)
  await page.emulateCPUThrottling(run.cpu)
  if (run.network) await page.emulateNetworkConditions(run.network)
  const start = Date.now()
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 })
  await page.waitForFunction(() => document.querySelector('.arne p')?.textContent && !document.querySelector('#loading'), { timeout: 60_000 })
  const seconds = (Date.now() - start) / 1000
  const slowest = await page.evaluate(() => performance.getEntriesByType('resource')
    .sort((a, b) => b.duration - a.duration).slice(0, 3)
    .map((entry) => `${entry.name.split('/').pop().slice(0, 34)} ${Math.round(entry.duration)}ms`))
  console.log(`${run.name}: playable in ${seconds.toFixed(2)}s, ${problems.length} problems`)
  console.log(`  slowest files: ${slowest.join(', ')}`)
  for (const problem of problems) console.log(`  ${problem}`)
  if (seconds > 20 || problems.length > 0) failed = true
  await context.close()
}
await browser.close()
server.close()
process.exitCode = failed ? 1 : 0
