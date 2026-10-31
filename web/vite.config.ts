import { defineConfig } from 'vite'

export default defineConfig({
  // Portals serve the game from a subfolder, so every URL must be relative.
  base: './',
  build: {
    // Most sprites are under 8 KB: inlining them means far fewer requests.
    assetsInlineLimit: 8192,
    chunkSizeWarningLimit: 2000,
  },
})
