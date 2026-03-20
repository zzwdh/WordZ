import fs from 'node:fs/promises'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { deflateSync } from 'node:zlib'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const projectRoot = path.resolve(__dirname, '..')
const buildDir = path.join(projectRoot, 'build')

const BRAND = Object.freeze({
  deep: [15, 42, 71],
  deepAlt: [9, 24, 45],
  accent: [27, 180, 183],
  accentSoft: [122, 242, 215],
  paper: [246, 250, 253],
  white: [255, 255, 255],
  shadow: [6, 12, 22]
})

function clamp(value, min = 0, max = 1) {
  return Math.min(Math.max(value, min), max)
}

function mix(a, b, amount) {
  return a + (b - a) * amount
}

function mixColor(colorA, colorB, amount) {
  return [
    Math.round(mix(colorA[0], colorB[0], amount)),
    Math.round(mix(colorA[1], colorB[1], amount)),
    Math.round(mix(colorA[2], colorB[2], amount))
  ]
}

function smoothstep(edge0, edge1, value) {
  const t = clamp((value - edge0) / (edge1 - edge0))
  return t * t * (3 - 2 * t)
}

function roundedRectSdf(x, y, width, height, radius) {
  const dx = Math.abs(x) - width + radius
  const dy = Math.abs(y) - height + radius
  const outsideX = Math.max(dx, 0)
  const outsideY = Math.max(dy, 0)
  const inside = Math.min(Math.max(dx, dy), 0)
  return Math.hypot(outsideX, outsideY) + inside - radius
}

function segmentDistance(px, py, x1, y1, x2, y2) {
  const vx = x2 - x1
  const vy = y2 - y1
  const wx = px - x1
  const wy = py - y1
  const lengthSquared = vx * vx + vy * vy || 1
  const projection = clamp((wx * vx + wy * vy) / lengthSquared)
  const closestX = x1 + vx * projection
  const closestY = y1 + vy * projection
  return Math.hypot(px - closestX, py - closestY)
}

function circleCoverage(px, py, cx, cy, radius, blur = 0.02) {
  const distance = Math.hypot(px - cx, py - cy)
  return clamp((radius + blur - distance) / (blur * 2))
}

function strokeCoverage(px, py, x1, y1, x2, y2, thickness, blur = 0.02) {
  return clamp((thickness + blur - segmentDistance(px, py, x1, y1, x2, y2)) / (blur * 2))
}

function createImage(width, height, renderer) {
  const data = new Uint8Array(width * height * 4)
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const index = (y * width + x) * 4
      const pixel = renderer(x, y, width, height)
      data[index] = pixel[0]
      data[index + 1] = pixel[1]
      data[index + 2] = pixel[2]
      data[index + 3] = pixel[3]
    }
  }
  return { width, height, data }
}

function resizeImage(image, targetWidth, targetHeight) {
  const output = new Uint8Array(targetWidth * targetHeight * 4)
  for (let y = 0; y < targetHeight; y += 1) {
    const sourceY = Math.min(image.height - 1, Math.floor(((y + 0.5) / targetHeight) * image.height))
    for (let x = 0; x < targetWidth; x += 1) {
      const sourceX = Math.min(image.width - 1, Math.floor(((x + 0.5) / targetWidth) * image.width))
      const sourceIndex = (sourceY * image.width + sourceX) * 4
      const targetIndex = (y * targetWidth + x) * 4
      output[targetIndex] = image.data[sourceIndex]
      output[targetIndex + 1] = image.data[sourceIndex + 1]
      output[targetIndex + 2] = image.data[sourceIndex + 2]
      output[targetIndex + 3] = image.data[sourceIndex + 3]
    }
  }
  return {
    width: targetWidth,
    height: targetHeight,
    data: output
  }
}

function blendPixel(target, targetIndex, sourceColor, alpha) {
  const sourceAlpha = clamp(alpha) * (sourceColor[3] / 255)
  if (sourceAlpha <= 0) return
  const targetAlpha = target[targetIndex + 3] / 255
  const outAlpha = sourceAlpha + targetAlpha * (1 - sourceAlpha)
  if (outAlpha <= 0) return

  target[targetIndex] = Math.round(
    (sourceColor[0] * sourceAlpha + target[targetIndex] * targetAlpha * (1 - sourceAlpha)) / outAlpha
  )
  target[targetIndex + 1] = Math.round(
    (sourceColor[1] * sourceAlpha + target[targetIndex + 1] * targetAlpha * (1 - sourceAlpha)) / outAlpha
  )
  target[targetIndex + 2] = Math.round(
    (sourceColor[2] * sourceAlpha + target[targetIndex + 2] * targetAlpha * (1 - sourceAlpha)) / outAlpha
  )
  target[targetIndex + 3] = Math.round(outAlpha * 255)
}

function compositeImage(targetImage, sourceImage, offsetX, offsetY) {
  for (let y = 0; y < sourceImage.height; y += 1) {
    const targetY = y + offsetY
    if (targetY < 0 || targetY >= targetImage.height) continue
    for (let x = 0; x < sourceImage.width; x += 1) {
      const targetX = x + offsetX
      if (targetX < 0 || targetX >= targetImage.width) continue
      const sourceIndex = (y * sourceImage.width + x) * 4
      const targetIndex = (targetY * targetImage.width + targetX) * 4
      blendPixel(targetImage.data, targetIndex, [
        sourceImage.data[sourceIndex],
        sourceImage.data[sourceIndex + 1],
        sourceImage.data[sourceIndex + 2],
        sourceImage.data[sourceIndex + 3]
      ], 1)
    }
  }
}

function renderBackground(nx, ny, maskAmount = 1) {
  const diagonal = clamp(0.15 + nx * 0.6 + (1 - ny) * 0.35)
  let color = mixColor(BRAND.deepAlt, BRAND.accent, diagonal)

  const glow = Math.pow(Math.max(0, 1 - Math.hypot(nx - 0.18, ny - 0.14) / 0.9), 1.6)
  color = mixColor(color, BRAND.accentSoft, glow * 0.55)

  const topLight = Math.pow(Math.max(0, 1 - Math.hypot(nx - 0.5, ny - 0.04) / 1.1), 2)
  color = mixColor(color, BRAND.paper, topLight * 0.08)

  return [color[0], color[1], color[2], Math.round(maskAmount * 255)]
}

function renderWordzIcon(size = 1024) {
  const segments = [
    [-0.47, -0.32, -0.47, 0.36],
    [-0.47, 0.36, -0.32, 0.04],
    [-0.32, 0.04, -0.17, 0.36],
    [-0.17, 0.36, -0.17, -0.32],
    [0.09, -0.30, 0.46, -0.30],
    [0.46, -0.30, 0.09, 0.32],
    [0.09, 0.32, 0.46, 0.32]
  ]

  return createImage(size, size, (x, y, width, height) => {
    const nx = (x + 0.5) / width
    const ny = (y + 0.5) / height
    const px = nx * 2 - 1
    const py = ny * 2 - 1
    const mask = clamp((0.025 - roundedRectSdf(px, py, 0.82, 0.82, 0.24)) / 0.035)
    const base = renderBackground(nx, ny, mask)

    const innerGlow = circleCoverage(px, py, 0.36, -0.42, 0.32, 0.18)
    const edgeAccent = circleCoverage(px, py, -0.62, 0.58, 0.24, 0.2)
    const iconColor = mixColor(BRAND.paper, BRAND.white, 0.55)
    const accentColor = mixColor(BRAND.accentSoft, BRAND.white, 0.18)

    const output = [...base]

    if (mask > 0) {
      output[0] = Math.round(mix(output[0], BRAND.paper[0], innerGlow * 0.1))
      output[1] = Math.round(mix(output[1], BRAND.paper[1], innerGlow * 0.1))
      output[2] = Math.round(mix(output[2], BRAND.paper[2], innerGlow * 0.1))

      output[0] = Math.round(mix(output[0], BRAND.accentSoft[0], edgeAccent * 0.22))
      output[1] = Math.round(mix(output[1], BRAND.accentSoft[1], edgeAccent * 0.22))
      output[2] = Math.round(mix(output[2], BRAND.accentSoft[2], edgeAccent * 0.22))
    }

    let shadowCoverage = 0
    let markCoverage = 0
    for (const [x1, y1, x2, y2] of segments) {
      shadowCoverage = Math.max(shadowCoverage, strokeCoverage(px, py, x1 + 0.03, y1 + 0.04, x2 + 0.03, y2 + 0.04, 0.072, 0.03))
      markCoverage = Math.max(markCoverage, strokeCoverage(px, py, x1, y1, x2, y2, 0.068, 0.028))
    }

    const badgeCoverage = circleCoverage(px, py, 0.56, -0.54, 0.11, 0.04) * mask
    if (shadowCoverage > 0) {
      output[0] = Math.round(mix(output[0], BRAND.shadow[0], shadowCoverage * 0.35))
      output[1] = Math.round(mix(output[1], BRAND.shadow[1], shadowCoverage * 0.35))
      output[2] = Math.round(mix(output[2], BRAND.shadow[2], shadowCoverage * 0.35))
    }

    if (markCoverage > 0) {
      output[0] = Math.round(mix(output[0], iconColor[0], markCoverage))
      output[1] = Math.round(mix(output[1], iconColor[1], markCoverage))
      output[2] = Math.round(mix(output[2], iconColor[2], markCoverage))
    }

    if (badgeCoverage > 0) {
      output[0] = Math.round(mix(output[0], accentColor[0], badgeCoverage))
      output[1] = Math.round(mix(output[1], accentColor[1], badgeCoverage))
      output[2] = Math.round(mix(output[2], accentColor[2], badgeCoverage))
    }

    return output
  })
}

function renderInstallerSidebar(width = 164, height = 314, iconImage) {
  const sidebar = createImage(width, height, (x, y, totalWidth, totalHeight) => {
    const nx = (x + 0.5) / totalWidth
    const ny = (y + 0.5) / totalHeight
    const base = renderBackground(nx * 0.9, ny, 1)
    const wave = Math.pow(Math.max(0, 1 - Math.abs(nx - 0.5) * 1.8), 2) * Math.max(0, ny - 0.55)
    base[0] = Math.round(mix(base[0], BRAND.paper[0], wave * 0.08))
    base[1] = Math.round(mix(base[1], BRAND.paper[1], wave * 0.08))
    base[2] = Math.round(mix(base[2], BRAND.paper[2], wave * 0.08))
    return base
  })

  const icon = resizeImage(iconImage, 92, 92)
  compositeImage(sidebar, icon, Math.round((width - icon.width) / 2), 44)

  return sidebar
}

function renderInstallerHeader(width = 150, height = 57, iconImage) {
  const header = createImage(width, height, (x, y, totalWidth, totalHeight) => {
    const nx = (x + 0.5) / totalWidth
    const ny = (y + 0.5) / totalHeight
    const base = renderBackground(nx, ny * 0.7 + 0.15, 1)
    const line = smoothstep(0.82, 0.12, Math.abs(ny - 0.82))
    base[0] = Math.round(mix(base[0], BRAND.accentSoft[0], line * 0.18))
    base[1] = Math.round(mix(base[1], BRAND.accentSoft[1], line * 0.18))
    base[2] = Math.round(mix(base[2], BRAND.accentSoft[2], line * 0.18))
    return base
  })

  const icon = resizeImage(iconImage, 36, 36)
  compositeImage(header, icon, 12, Math.round((height - icon.height) / 2))

  return header
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let index = 0; index < 256; index += 1) {
    let value = index
    for (let bit = 0; bit < 8; bit += 1) {
      value = (value & 1) ? 0xedb88320 ^ (value >>> 1) : value >>> 1
    }
    table[index] = value >>> 0
  }
  return table
})()

function crc32(buffer) {
  let value = 0xffffffff
  for (const byte of buffer) {
    value = CRC_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8)
  }
  return (value ^ 0xffffffff) >>> 0
}

function encodePng(image) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(image.width, 0)
  ihdr.writeUInt32BE(image.height, 4)
  ihdr[8] = 8
  ihdr[9] = 6
  ihdr[10] = 0
  ihdr[11] = 0
  ihdr[12] = 0

  const rows = []
  for (let y = 0; y < image.height; y += 1) {
    const row = Buffer.alloc(1 + image.width * 4)
    row[0] = 0
    const start = y * image.width * 4
    Buffer.from(image.data.subarray(start, start + image.width * 4)).copy(row, 1)
    rows.push(row)
  }
  const compressed = deflateSync(Buffer.concat(rows), { level: 9 })

  return Buffer.concat([
    signature,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', compressed),
    pngChunk('IEND', Buffer.alloc(0))
  ])
}

function pngChunk(type, payload) {
  const payloadBuffer = Buffer.from(payload)
  const typeBuffer = Buffer.from(type, 'ascii')
  const sizeBuffer = Buffer.alloc(4)
  sizeBuffer.writeUInt32BE(payloadBuffer.length, 0)
  const crcBuffer = Buffer.alloc(4)
  crcBuffer.writeUInt32BE(crc32(Buffer.concat([typeBuffer, payloadBuffer])), 0)
  return Buffer.concat([sizeBuffer, typeBuffer, payloadBuffer, crcBuffer])
}

function encodeIco(images) {
  const header = Buffer.alloc(6)
  header.writeUInt16LE(0, 0)
  header.writeUInt16LE(1, 2)
  header.writeUInt16LE(images.length, 4)

  let offset = 6 + images.length * 16
  const directoryEntries = []
  const payloads = []

  for (const image of images) {
    const pngBuffer = encodePng(image)
    const entry = Buffer.alloc(16)
    entry[0] = image.width >= 256 ? 0 : image.width
    entry[1] = image.height >= 256 ? 0 : image.height
    entry[2] = 0
    entry[3] = 0
    entry.writeUInt16LE(1, 4)
    entry.writeUInt16LE(32, 6)
    entry.writeUInt32LE(pngBuffer.length, 8)
    entry.writeUInt32LE(offset, 12)
    directoryEntries.push(entry)
    payloads.push(pngBuffer)
    offset += pngBuffer.length
  }

  return Buffer.concat([header, ...directoryEntries, ...payloads])
}

function encodeBmp(image) {
  const rowStride = image.width * 3
  const paddedStride = Math.ceil(rowStride / 4) * 4
  const pixelBytes = paddedStride * image.height
  const header = Buffer.alloc(54)
  header.write('BM', 0, 'ascii')
  header.writeUInt32LE(54 + pixelBytes, 2)
  header.writeUInt32LE(54, 10)
  header.writeUInt32LE(40, 14)
  header.writeInt32LE(image.width, 18)
  header.writeInt32LE(image.height, 22)
  header.writeUInt16LE(1, 26)
  header.writeUInt16LE(24, 28)
  header.writeUInt32LE(pixelBytes, 34)

  const pixels = Buffer.alloc(pixelBytes)
  for (let y = 0; y < image.height; y += 1) {
    const targetRow = image.height - y - 1
    for (let x = 0; x < image.width; x += 1) {
      const sourceIndex = (y * image.width + x) * 4
      const targetIndex = targetRow * paddedStride + x * 3
      const alpha = image.data[sourceIndex + 3] / 255
      const red = image.data[sourceIndex]
      const green = image.data[sourceIndex + 1]
      const blue = image.data[sourceIndex + 2]
      pixels[targetIndex] = Math.round(mix(255, blue, alpha))
      pixels[targetIndex + 1] = Math.round(mix(255, green, alpha))
      pixels[targetIndex + 2] = Math.round(mix(255, red, alpha))
    }
  }

  return Buffer.concat([header, pixels])
}

async function writeFile(outputPath, buffer) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true })
  await fs.writeFile(outputPath, buffer)
  process.stdout.write(`${path.relative(projectRoot, outputPath)}\n`)
}

async function generateIcns(iconImage) {
  if (process.platform !== 'darwin') return false

  const iconsetDir = path.join(buildDir, 'icon.iconset')
  await fs.rm(iconsetDir, { recursive: true, force: true }).catch(() => {})
  await fs.mkdir(iconsetDir, { recursive: true })

  const iconsetEntries = [
    ['icon_16x16.png', 16],
    ['icon_16x16@2x.png', 32],
    ['icon_32x32.png', 32],
    ['icon_32x32@2x.png', 64],
    ['icon_128x128.png', 128],
    ['icon_128x128@2x.png', 256],
    ['icon_256x256.png', 256],
    ['icon_256x256@2x.png', 512],
    ['icon_512x512.png', 512],
    ['icon_512x512@2x.png', 1024]
  ]

  for (const [filename, size] of iconsetEntries) {
    await fs.writeFile(path.join(iconsetDir, filename), encodePng(resizeImage(iconImage, size, size)))
  }

  const outputPath = path.join(buildDir, 'icon.icns')
  execFileSync('iconutil', ['-c', 'icns', iconsetDir, '-o', outputPath], {
    cwd: projectRoot,
    stdio: 'inherit'
  })
  await fs.rm(iconsetDir, { recursive: true, force: true })
  process.stdout.write(`${path.relative(projectRoot, outputPath)}\n`)
  return true
}

async function main() {
  const iconImage = renderWordzIcon()
  const sidebarImage = renderInstallerSidebar(164, 314, iconImage)
  const headerImage = renderInstallerHeader(150, 57, iconImage)

  await writeFile(path.join(buildDir, 'icon.png'), encodePng(iconImage))
  await writeFile(
    path.join(buildDir, 'icon.ico'),
    encodeIco([16, 24, 32, 48, 64, 128, 256].map(size => resizeImage(iconImage, size, size)))
  )
  await writeFile(path.join(buildDir, 'installer-sidebar.bmp'), encodeBmp(sidebarImage))
  await writeFile(path.join(buildDir, 'installer-header.bmp'), encodeBmp(headerImage))
  await generateIcns(iconImage)
}

main().catch(error => {
  console.error('[generate-build-assets]', error)
  process.exit(1)
})
