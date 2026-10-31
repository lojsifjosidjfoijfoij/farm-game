// Makes the portal covers and preview videos from the real game.
//
//   node promo/make-promo.mjs covers    Puts the title on the renders in promo/renders
//   node promo/make-promo.mjs videos    Records the gameplay videos (add portrait or landscape for just one)
//   node promo/make-promo.mjs           Both
//
// Render the art first (see cover_scene.py). Everything lands in promo/out.
// Videos run the game on a stepped clock, so they play at true speed with
// every frame perfect, and there's no mouse cursor to hide.
import { execFileSync, spawn } from 'node:child_process'
import { createReadStream, existsSync, mkdirSync, readFileSync, rmSync, statSync } from 'node:fs'
import { createServer } from 'node:http'
import { dirname, extname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import puppeteer from 'puppeteer-core'

const web = join(dirname(fileURLToPath(import.meta.url)), '..')
const renders = join(web, 'promo', 'renders')
const out = join(web, 'promo', 'out')
const buildDir = join(web, 'promo', '.build')
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const title = /GAME_TITLE = '(.+)'/.exec(readFileSync(join(web, 'src', 'main.ts'), 'utf8'))[1]

const FPS = 30
const COVER_SECONDS = 1

// Sizes CrazyGames asks for. Videos are drawn zoomed in, so the HUD stays readable on a phone-shaped frame.
const COVERS = {
  landscape: { width: 1920, height: 1080, fontSize: 190, lines: [title], top: 34 },
  portrait: { width: 800, height: 1200, fontSize: 170, lines: title.split(' '), top: 66 },
  square: { width: 800, height: 800, fontSize: 124, lines: title.split(' '), top: 26 },
}
const VIDEOS = {
  landscape: { width: 1280, height: 720, zoom: 1.5 },
  portrait: { width: 540, height: 810, zoom: 2 },
}

async function launch() {
  return puppeteer.launch({ executablePath: chrome, headless: true, args: ['--hide-scrollbars', '--mute-audio'] })
}

async function makeCovers() {
  const font = readFileSync(join(web, 'src', 'fonts', 'Fredoka.ttf')).toString('base64')
  const browser = await launch()
  for (const [name, cover] of Object.entries(COVERS)) {
    const art = readFileSync(join(renders, `${name}.png`)).toString('base64')
    const page = await browser.newPage()
    await page.setViewport({ width: cover.width, height: cover.height })
    await page.setContent(`<!doctype html><style>
      @font-face { font-family: Fredoka; src: url(data:font/ttf;base64,${font}); font-weight: 300 700; }
      html, body { margin: 0; width: ${cover.width}px; height: ${cover.height}px; overflow: hidden; }
      body { background: url(data:image/png;base64,${art}) center / cover; }
      h1 {
        position: absolute; left: 0; right: 0; top: ${cover.top}px; margin: 0; text-align: center;
        font: 700 ${cover.fontSize}px/0.98 Fredoka;
        color: #ffe27a; paint-order: stroke fill;
        -webkit-text-stroke: ${Math.round(cover.fontSize * 0.13)}px #5a2e0c;
        filter: drop-shadow(0 ${Math.round(cover.fontSize * 0.05)}px 0 #3a1c06);
      }
    </style><h1>${cover.lines.join('<br>')}</h1>`, { waitUntil: 'load' })
    await page.evaluate(() => document.fonts.ready)
    await page.screenshot({ path: join(out, `cover-${name}.png`) })
    await page.close()
    console.log(`cover-${name}.png`)
  }
  await browser.close()
}

/** A plain file server, because modules won't load from file://. */
function serve(root) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.ttf': 'font/ttf', '.txt': 'text/plain' }
  const server = createServer((request, response) => {
    const path = join(root, decodeURIComponent(request.url.split('?')[0]).replace(/\/$/, '/index.html'))
    if (!existsSync(path) || !statSync(path).isFile()) {
      response.writeHead(404).end()
      return
    }
    response.writeHead(200, { 'content-type': types[extname(path)] ?? 'application/octet-stream' })
    createReadStream(path).pipe(response)
  })
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)))
}

/** Replaces the page's clock, so the game only moves when the recorder says so. */
function steppedClock() {
  const base = Date.now()
  let clock = 0
  let nextId = 1
  let frames = []
  let timers = []
  performance.now = () => clock
  Date.now = () => base + clock
  // A headless tab counts as hidden on and off, and the game would greet it as a returning player.
  Object.defineProperty(document, 'hidden', { get: () => false })
  document.addEventListener('visibilitychange', (event) => event.stopImmediatePropagation(), true)
  window.requestAnimationFrame = (callback) => {
    frames.push(callback)
    return frames.length
  }
  window.setTimeout = (callback, delay = 0) => {
    timers.push({ id: nextId, at: clock + delay, callback })
    return nextId++
  }
  window.clearTimeout = (id) => {
    timers = timers.filter((timer) => timer.id !== id)
  }
  const started = new WeakMap()
  window.stepClock = (ms) => {
    clock += ms
    const due = timers.filter((timer) => timer.at <= clock)
    timers = timers.filter((timer) => timer.at > clock)
    due.forEach((timer) => timer.callback())
    const callbacks = frames
    frames = []
    callbacks.forEach((callback) => callback(clock))
    for (const animation of document.getAnimations()) {
      if (!started.has(animation)) {
        started.set(animation, clock)
        animation.pause()
      }
      const time = clock - started.get(animation)
      const end = animation.effect.getComputedTiming().endTime
      if (Number.isFinite(end) && time >= end) animation.finish()
      else animation.currentTime = time
    }
  }
}

/** Rarer than a real farm's luck would feel over a minute, but only just: one in seven or so glows. */
const RARES = [undefined, undefined, 'golden', undefined, undefined, undefined, undefined, undefined, 'rainbow', undefined,
  undefined, undefined, undefined, undefined, 'golden', undefined, undefined, undefined, undefined, undefined, undefined, 'cosmic',
  undefined, undefined, undefined, undefined, undefined, 'golden', undefined, undefined, undefined]

/** Fills every owned field with ripe crops, in rows of the given kinds. */
function fillFields(crops, rare) {
  const state = window.game.state
  const FIELDS = { home_field: [9, 6], east_meadow: [15, 6], west_field: [3, 6], mill_lot: [9, 10], goat_hill: [15, 10], south_pasture: [3, 10] }
  state.plots = {}
  let index = 0
  for (const id of state.ownedParcels) {
    const [left, top] = FIELDS[id]
    for (let y = top; y < top + 3; y++) {
      for (let x = left; x < left + 5; x++) {
        const cropId = crops[index % crops.length]
        state.plots[`${x},${y}`] = {
          x, y, wetUntil: 1e12,
          crop: { cropId, growth: 1e9, harvests: 0, mutation: rare ? rare[index % rare.length] : undefined },
        }
        index += 1
      }
    }
  }
}

/** For a full farm, where there are far more plots on screen. */
const FEW_RARES = Array.from({ length: 48 }, (_, index) => ({ 7: 'golden', 23: 'rainbow', 39: 'cosmic' })[index])

const farmland = (parcels) => ['home_field', 'east_meadow', 'west_field', 'mill_lot', 'goat_hill', 'south_pasture'].slice(0, parcels)

/** Each take is a state to start from, then what the player does, in seconds. */
const TAKES = [
  {
    seconds: 4.6,
    setup: { goalIndex: 0, money: 50 },
    crops: ['wheat', 'wheat', 'wheat', 'wheat', 'wheat', 'carrot', 'carrot', 'carrot', 'carrot', 'carrot', 'potato', 'potato', 'potato', 'potato', 'potato'],
    script: [
      { at: 0.25, drag: [[9, 6], [13, 6]], for: 0.8 },
      { at: 1.25, drag: [[13, 7], [9, 7]], for: 0.8 },
      { at: 2.25, drag: [[9, 8], [13, 8]], for: 0.8 },
      { at: 3.3, click: '.action.sell' },
    ],
  },
  {
    seconds: 5,
    setup: {
      money: 3.2e9, runCoins: 4e9, lifetimeCoins: 9e9, income: 6.4e7, level: 24, goalIndex: 33, rebirths: 2, totalRebirths: 6, storageLevel: 2,
      farmhouseLevel: 2, ownedParcels: farmland(4), automation: ['drill', 'driver', 'irrigation'], seed: 'pumpkin',
      training: { seeds: 22, fertilizer: 9, reach: 4, barn: 3, clover: 7 }, inventory: { pumpkin: 60, corn: 90 },
      workers: [{ x: 12, y: 7, progress: 0 }],
    },
    crops: ['pumpkin', 'corn', 'sunflower', 'melon', 'pumpkin'],
    rare: RARES,
    script: [
      { at: 0.2, drag: [[3, 7], [7, 7]], for: 1.0 },
      { at: 1.5, drag: [[9, 7], [13, 7]], for: 1.0 },
      { at: 2.8, drag: [[15, 7], [19, 7]], for: 1.0 },
    ],
  },
  {
    seconds: 3.4,
    setup: {
      money: 8.4e13, runCoins: 3e12, lifetimeCoins: 4.2e12, income: 2.1e9, level: 30, goalIndex: 35, rebirths: 3, totalRebirths: 11, goldenSeeds: 64,
      storageLevel: 2, farmhouseLevel: 2, ownedParcels: farmland(5), automation: ['drill', 'driver', 'irrigation', 'foreman'], seed: 'x1',
      perks: { green_thumb: 3, old_habits: 1 }, training: { seeds: 30, fertilizer: 12 },
    },
    crops: ['x0', 'x1', 'pumpkin', 'melon'],
    script: [
      { at: 0.3, click: '.rebirth-button' },
      { at: 0.95, click: '.reset' },
      { at: 1.45, click: '.reset.confirm' },
    ],
  },
  {
    seconds: 4,
    setup: {
      money: 4.2e18, runCoins: 9e18, lifetimeCoins: 8e19, income: 1.7e15, level: 52, goalIndex: 39, rebirths: 7, totalRebirths: 24, ascensions: 1, stars: 10,
      // No Foreman here: he'd max out the farmhands, and they'd clear the fields in a second.
      storageLevel: 3, farmhouseLevel: 3, windmill: true, ownedParcels: farmland(6), automation: ['drill', 'driver', 'irrigation'], seed: 'x4',
      perks: { green_thumb: 9, old_habits: 1 }, training: { seeds: 60, fertilizer: 40, reach: 12, barn: 8, clover: 14 },
      workers: [{ x: 9, y: 6, progress: 0 }, { x: 12, y: 7, progress: 0 }, { x: 16, y: 11, progress: 0 }], inventory: { x4: 400 },
    },
    crops: ['x5', 'x3', 'x4', 'x2', 'x1'],
    rare: FEW_RARES,
    script: [{ at: 1.1, click: '.action.sell' }],
  },
]

/** Clicks like a mouse, right where the element is. */
async function clickOn(page, selector) {
  const point = await page.evaluate((target) => {
    const box = document.querySelector(target)?.getBoundingClientRect()
    return box ? { x: box.x + box.width / 2, y: box.y + box.height / 2 } : null
  }, selector)
  if (!point) throw new Error(`Nothing on screen matches ${selector}`)
  await page.mouse.move(point.x, point.y)
  await page.mouse.down()
  await page.mouse.up()
}

async function recordTake(browser, url, take, size, file) {
  // A fresh profile each time, or a take would load the last one's save.
  const context = await browser.createBrowserContext()
  const page = await context.newPage()
  await page.setViewport({ width: size.width, height: size.height, deviceScaleFactor: size.zoom })
  await page.setRequestInterception(true)
  page.on('request', (request) => {
    if (request.url().includes('crazygames')) request.abort()
    else request.continue()
  })
  await page.evaluateOnNewDocument(steppedClock)
  await page.goto(url)
  await page.addStyleTag({ content: '#tooltip { display: none !important; }' })
  while (!(await page.evaluate(() => Boolean(window.game)))) await new Promise((resolve) => setTimeout(resolve, 50))
  await page.evaluate((setup) => {
    Object.assign(window.game.state, setup)
  }, take.setup)
  await page.evaluate(fillFields, take.crops, take.rare ?? null)

  const encoder = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p', '-an', file], { stdio: ['pipe', 'inherit', 'inherit'] })

  const tile = (x, y) => page.evaluate((tx, ty) => window.game.view.screenPoint(tx, ty + 0.3), x, y)
  const frameMs = 1000 / FPS
  const total = Math.round(take.seconds * FPS)
  const events = [...take.script]
  let active = null
  for (let frame = 0; frame < total; frame++) {
    const seconds = frame / FPS
    while (events.length > 0 && events[0].at <= seconds) {
      const event = events.shift()
      if (event.click) {
        await clickOn(page, event.click)
      } else {
        const [from, to] = event.drag
        const start = await tile(...from)
        const end = await tile(...to)
        await page.mouse.move(start.x, start.y)
        await page.mouse.down()
        active = { start, end, from: seconds, for: event.for }
      }
    }
    if (active) {
      const share = Math.min(1, (seconds - active.from) / active.for)
      await page.mouse.move(active.start.x + (active.end.x - active.start.x) * share, active.start.y + (active.end.y - active.start.y) * share)
      if (share >= 1) {
        await page.mouse.up()
        active = null
      }
    }
    await page.evaluate((ms) => window.stepClock(ms), frameMs)
    const jpeg = await page.screenshot({ type: 'jpeg', quality: 96 })
    if (!encoder.stdin.write(jpeg)) await new Promise((resolve) => encoder.stdin.once('drain', resolve))
    if (frame % 30 === 0) process.stdout.write('.')
  }
  encoder.stdin.end()
  await new Promise((resolve) => encoder.once('close', resolve))
  await context.close()
}

async function makeVideos() {
  execFileSync('npx', ['vite', 'build', '--outDir', buildDir, '--emptyOutDir'], {
    cwd: web, stdio: 'ignore', env: { ...process.env, VITE_PROMO: '1' },
  })
  const server = await serve(buildDir)
  const url = `http://127.0.0.1:${server.address().port}/index.html`
  const browser = await launch()
  for (const [name, size] of Object.entries(VIDEOS)) {
    if (only && only !== name) continue
    const clips = []
    for (const [index, take] of TAKES.entries()) {
      const clip = join(buildDir, `${name}-${index}.mp4`)
      await recordTake(browser, url, take, size, clip)
      clips.push(clip)
    }
    const width = size.width * size.zoom
    const height = size.height * size.zoom
    const fit = `scale=${width}:${height}:force_original_aspect_ratio=increase,crop=${width}:${height},setsar=1,fps=${FPS},format=yuv420p`
    // The docs ask for the static cover as the opening frame.
    const inputs = ['-loop', '1', '-t', String(COVER_SECONDS), '-i', join(out, `cover-${name}.png`), ...clips.flatMap((clip) => ['-i', clip])]
    const filters = [`[0:v]${fit}[c0]`, ...clips.map((_, i) => `[${i + 1}:v]${fit}[c${i + 1}]`)]
    const joined = [...Array(clips.length + 1).keys()].map((i) => `[c${i}]`).join('')
    filters.push(`${joined}concat=n=${clips.length + 1}:v=1:a=0[v]`)
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', filters.join(';'), '-map', '[v]', '-an',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', join(out, `preview-${name}.mp4`)])
    console.log(`\npreview-${name}.mp4`)
  }
  await browser.close()
  server.close()
  rmSync(buildDir, { recursive: true, force: true })
}

mkdirSync(out, { recursive: true })
mkdirSync(buildDir, { recursive: true })
const [task, only] = process.argv.slice(2)
if (task !== 'videos') await makeCovers()
if (task !== 'covers') await makeVideos()
