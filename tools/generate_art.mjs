#!/usr/bin/env node
/**
 * Deterministic, dependency-free pixel-art generator for Roots of Sacrifice.
 * Run from any directory with: node tools/generate_art.mjs
 * Only assets/art SVGs and ASSET_MANIFEST.md are written; source PNGs are preserved.
 */

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ART = path.join(ROOT, 'assets', 'art');

const USER_ICON_CACHE = new Map();
const USER_ICON_COLORS = new Set();

const P = Object.freeze({
  forest: '#173f35',
  leaf: '#4f7d42',
  lime: '#91b85c',
  turquoise: '#3aa7a0',
  brick: '#b76b45',
  cream: '#f4e4bd',
  ink: '#20352e',
  sky: '#8fd3d1',
  soil: '#5c4030',
  water: '#3a91b5',
  gold: '#c49b56',
  bark: '#8b5a34',
  barkLight: '#c08a4a',
  leafLight: '#6f9b4e',
  leafHighlight: '#8eb85d',
  rootLight: '#67c7b8',
  earth: '#234f3c',
  rose: '#c85b68',
  roseLight: '#ef98a0',
  roseDark: '#823e55',
  fruit: '#b93f3f',
  fruitLight: '#e46b52',
  white: '#ffffff',
});

const r = (x, y, w, h, fill, extra = '') =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"${extra}/>`;

const roundedRect = (x, y, w, h, radius, fill, extra = '') =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}" fill="${fill}"${extra}/>`;

const p = (d, fill, extra = '') =>
  `<path d="${d}" fill="${fill}"${extra}/>`;

const g = (body, x = 0, y = 0, extra = '') =>
  `<g transform="translate(${x} ${y})"${extra}>${body}</g>`;

const stroke = (color = P.ink, width = 2, extra = '') =>
  `stroke="${color}" stroke-width="${width}" stroke-linecap="butt" stroke-linejoin="miter"${extra}`;

const svg = (width, height, body, viewBox = `0 0 ${width} ${height}`) =>
  `<?xml version="1.0" encoding="UTF-8"?>\n` +
  `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="${viewBox}" shape-rendering="crispEdges">\n` +
  `${body}\n</svg>\n`;

function decodePng(buffer) {
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (!buffer.subarray(0, 8).equals(signature)) throw new Error('Invalid user icon PNG signature');
  let offset = 8;
  let width = 0;
  let height = 0;
  const idat = [];
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    offset += 4;
    const type = buffer.toString('ascii', offset, offset + 4);
    offset += 4;
    const data = buffer.subarray(offset, offset + length);
    offset += length + 4;
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      if (data[8] !== 8 || data[9] !== 6 || data[12] !== 0) throw new Error('User icons must be non-interlaced 8-bit RGBA PNGs');
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') {
      break;
    }
  }
  if (!width || !height || idat.length === 0) throw new Error('Incomplete user icon PNG');
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * 4;
  const pixels = Buffer.alloc(stride * height);
  let sourceOffset = 0;
  for (let y = 0; y < height; y += 1) {
    const filter = raw[sourceOffset];
    sourceOffset += 1;
    const rowOffset = y * stride;
    for (let x = 0; x < stride; x += 1) {
      const value = raw[sourceOffset];
      sourceOffset += 1;
      const left = x >= 4 ? pixels[rowOffset + x - 4] : 0;
      const up = y > 0 ? pixels[rowOffset - stride + x] : 0;
      const upperLeft = y > 0 && x >= 4 ? pixels[rowOffset - stride + x - 4] : 0;
      let predictor = 0;
      if (filter === 1) predictor = left;
      else if (filter === 2) predictor = up;
      else if (filter === 3) predictor = Math.floor((left + up) / 2);
      else if (filter === 4) {
        const estimate = left + up - upperLeft;
        const leftDistance = Math.abs(estimate - left);
        const upDistance = Math.abs(estimate - up);
        const upperLeftDistance = Math.abs(estimate - upperLeft);
        predictor = leftDistance <= upDistance && leftDistance <= upperLeftDistance ? left : (upDistance <= upperLeftDistance ? up : upperLeft);
      } else if (filter !== 0) {
        throw new Error(`Unsupported PNG filter ${filter}`);
      }
      pixels[rowOffset + x] = (value + predictor) & 255;
    }
  }
  return { width, height, pixels };
}

function loadUserIcon(fileName) {
  if (USER_ICON_CACHE.has(fileName)) return USER_ICON_CACHE.get(fileName);
  const image = decodePng(fs.readFileSync(path.join(ART, 'source', fileName)));
  for (let index = 0; index < image.pixels.length; index += 4) {
    if (image.pixels[index + 3] === 0) continue;
    const color = `#${[...image.pixels.subarray(index, index + 3)].map(value => value.toString(16).padStart(2, '0')).join('')}`;
    USER_ICON_COLORS.add(color);
  }
  USER_ICON_CACHE.set(fileName, image);
  return image;
}

function pngPixelSvg(image) {
  const rectangles = [];
  let previous = new Map();
  for (let y = 0; y < image.height; y += 1) {
    const current = new Map();
    let x = 0;
    while (x < image.width) {
      const index = (y * image.width + x) * 4;
      const alpha = image.pixels[index + 3];
      if (alpha === 0) {
        x += 1;
        continue;
      }
      const color = `#${[...image.pixels.subarray(index, index + 3)].map(value => value.toString(16).padStart(2, '0')).join('')}`;
      let end = x + 1;
      while (end < image.width) {
        const nextIndex = (y * image.width + end) * 4;
        if (image.pixels[nextIndex + 3] !== alpha || !image.pixels.subarray(nextIndex, nextIndex + 3).equals(image.pixels.subarray(index, index + 3))) break;
        end += 1;
      }
      const key = `${x}:${end - x}:${color}:${alpha}`;
      const existing = previous.get(key);
      if (existing) {
        existing.height += 1;
        current.set(key, existing);
      } else {
        const rectangle = { x, y, width: end - x, height: 1, color, alpha };
        rectangles.push(rectangle);
        current.set(key, rectangle);
      }
      x = end;
    }
    previous = current;
  }
  return rectangles.map(rectangle => {
    const opacity = rectangle.alpha === 255 ? '' : ` fill-opacity="${(rectangle.alpha / 255).toFixed(3)}"`;
    return r(rectangle.x, rectangle.y, rectangle.width, rectangle.height, rectangle.color, opacity);
  }).join('');
}

function rng(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function texture(base, seed, colors, count = 32, size = 2) {
  const random = rng(seed);
  let out = r(0, 0, 64, 64, base);
  for (let i = 0; i < count; i += 1) {
    const x = Math.floor(random() * 32) * 2;
    const y = Math.floor(random() * 32) * 2;
    const w = size * (random() > 0.76 ? 2 : 1);
    const h = size * (random() > 0.84 ? 2 : 1);
    out += r(x, y, w, h, colors[Math.floor(random() * colors.length)]);
  }
  return out;
}

function grass(seed, dry = false) {
  let out = r(0, 0, 64, 64, dry ? P.soil : P.leaf);
  const random = rng(seed);
  const colors = dry ? [P.brick, P.lime, P.ink] : [P.lime, P.forest, P.turquoise];
  for (let i = 0; i < 42; i += 1) {
    const x = Math.floor(random() * 31) * 2;
    const y = Math.floor(random() * 31) * 2;
    out += r(x, y, 2, 2, colors[Math.floor(random() * colors.length)]);
  }
  const blades = dry
    ? [[8, 12], [24, 30], [44, 10], [52, 40], [16, 50]]
    : [[8, 12], [24, 30], [44, 10], [52, 40], [16, 50], [36, 52]];
  for (const [x, y] of blades) {
    out += r(x, y, 2, 6, dry ? P.lime : P.lime);
    out += r(x + 4, y + 2, 2, 4, dry ? P.brick : P.forest);
  }
  return out;
}

function blob(x, y, w, h, fill) {
  if (w <= 8 || h <= 16) return r(x, y, w, h, fill);
  return r(x + 4, y, w - 8, h, fill) +
    r(x + 2, y + 4, w - 4, h - 8, fill) +
    r(x, y + 8, w, h - 16, fill);
}

function leaf(x, y, size, fill, vein = false) {
  const half = Math.floor(size / 2);
  let out = r(x - half, y - 1, size, 4, fill) +
    r(x - half + 2, y - 3, Math.max(2, size - 4), 8, fill);
  if (vein) out += r(x, y - 1, 2, 4, P.cream);
  return out;
}

function paved(seed, base = P.cream) {
  let out = r(0, 0, 64, 64, base);
  out += r(0, 15, 64, 2, P.ink) + r(0, 31, 64, 2, P.ink) + r(0, 47, 64, 2, P.ink);
  out += r(15, 0, 2, 15, P.ink) + r(47, 0, 2, 15, P.ink);
  out += r(7, 17, 2, 14, P.ink) + r(39, 17, 2, 14, P.ink);
  out += r(23, 33, 2, 14, P.ink) + r(55, 33, 2, 14, P.ink);
  out += r(7, 49, 2, 15, P.ink) + r(39, 49, 2, 15, P.ink);
  const random = rng(seed);
  for (let i = 0; i < 10; i += 1) {
    out += r(Math.floor(random() * 30) * 2, Math.floor(random() * 30) * 2, 4, 2, P.sky);
  }
  return out;
}

function tileArt(index) {
  switch (index) {
    case 0: return grass(101);
    case 1: {
      let out = grass(102);
      out += r(6, 8, 8, 4, P.leaf) + r(10, 4, 8, 4, P.leaf);
      out += r(42, 42, 10, 4, P.leaf) + r(46, 38, 8, 4, P.leaf);
      return out;
    }
    case 2: {
      let out = grass(103);
      out += r(10, 14, 3, 12, P.bark) + leaf(11, 12, 16, P.leaf, true);
      out += r(44, 38, 3, 12, P.bark) + leaf(45, 36, 16, P.lime, true);
      out += r(50, 8, 3, 10, P.bark) + leaf(51, 7, 14, P.forest, true);
      return out;
    }
    case 3: {
      let out = r(0, 0, 64, 64, P.soil);
      for (let row = 0; row < 4; row += 1) {
        for (let col = 0; col < 3; col += 1) {
          const x = col * 22 + (row % 2 ? -8 : 2);
          const y = row * 16 + 2;
          out += r(x, y, 18, 12, P.ink);
          out += r(x + 2, y + 2, 14, 8, row % 2 ? P.sky : P.cream);
          out += r(x + 2, y + 2, 10, 2, P.cream);
        }
      }
      out += r(0, 0, 8, 64, P.soil) + r(56, 0, 8, 64, P.soil);
      return out;
    }
    case 4: {
      let out = texture(P.soil, 104, [P.ink, P.brick, P.cream], 38);
      out += r(10, 18, 12, 2, P.ink) + r(18, 20, 2, 6, P.ink);
      out += r(40, 42, 14, 2, P.brick) + r(50, 44, 2, 6, P.brick);
      return out;
    }
    case 5: {
      let out = texture(P.soil, 105, [P.ink, P.brick], 34);
      out += r(8, 12, 14, 4, P.forest) + r(36, 26, 18, 4, P.forest);
      out += r(12, 8, 6, 2, P.water) + r(42, 22, 6, 2, P.turquoise);
      out += r(22, 46, 8, 2, P.water);
      return out;
    }
    case 6: {
      let out = texture(P.water, 106, [P.turquoise, P.sky, P.forest], 24, 4);
      out += r(4, 12, 18, 2, P.sky) + r(12, 16, 10, 2, P.sky);
      out += r(38, 34, 20, 2, P.turquoise) + r(44, 38, 10, 2, P.turquoise);
      out += r(8, 52, 16, 2, P.sky);
      return out;
    }
    case 7: {
      let out = r(0, 0, 64, 64, P.ink);
      for (let row = 0; row < 5; row += 1) {
        const y = row * 13;
        const offset = row % 2 ? -10 : 0;
        for (let col = 0; col < 5; col += 1) {
          const x = col * 22 + offset;
          out += r(x + 2, y + 2, 18, 9, P.brick);
          out += r(x + 2, y + 2, 14, 2, P.cream);
        }
      }
      return out;
    }
    case 8: {
      let out = grass(108);
      out += r(12, 16, 3, 13, P.bark) + leaf(13, 14, 18, P.leaf, true);
      out += r(44, 14, 3, 13, P.bark) + leaf(45, 12, 18, P.lime, true);
      out += r(29, 36, 3, 13, P.bark) + leaf(30, 34, 18, P.forest, true);
      return out;
    }
    case 9: {
      let out = grass(109);
      out += r(9, 40, 3, 12, P.bark) + leaf(10, 38, 16, P.leaf, true);
      out += r(21, 46, 3, 12, P.bark) + leaf(22, 44, 16, P.lime, true);
      out += r(49, 9, 3, 13, P.bark) + leaf(50, 7, 18, P.forest, true);
      out += leaf(42, 34, 10, P.lime, true) + leaf(18, 24, 10, P.turquoise, true);
      return out;
    }
    case 10: {
      let out = r(0, 0, 64, 64, P.leaf);
      out += r(4, 8, 56, 48, P.ink) + r(8, 12, 48, 40, P.soil);
      out += r(4, 4, 56, 6, P.brick) + r(4, 54, 56, 6, P.brick);
      out += r(4, 4, 6, 56, P.brick) + r(54, 4, 6, 56, P.brick);
      for (const [x, y] of [[18, 24], [32, 34], [46, 24]]) {
        out += leaf(x, y, 10, P.lime, true) + r(x, y + 4, 2, 8, P.forest);
      }
      return out;
    }
    case 11: {
      let out = paved(111, P.sky);
      out += r(6, 6, 52, 52, P.forest);
      out += r(10, 10, 44, 44, P.turquoise);
      out += r(30, 10, 4, 44, P.cream) + r(10, 30, 44, 4, P.cream);
      out += r(14, 14, 12, 12, P.forest) + r(14, 38, 12, 12, P.forest);
      out += r(38, 14, 12, 12, P.forest) + r(38, 38, 12, 12, P.forest);
      return out;
    }
    case 12: {
      let out = r(0, 0, 64, 64, P.leaf);
      out += r(0, 0, 64, 20, P.cream) + r(0, 44, 64, 20, P.cream);
      out += r(0, 18, 64, 4, P.soil) + r(0, 42, 64, 4, P.soil);
      out += r(14, 0, 2, 20, P.brick) + r(46, 0, 2, 20, P.brick);
      out += r(14, 44, 2, 20, P.brick) + r(46, 44, 2, 20, P.brick);
      return out;
    }
    case 13: {
      let out = grass(113);
      out += r(24, 56, 24, 4, P.ink, ' opacity="0.35"');
      out += r(22, 30, 24, 4, P.ink) + r(18, 34, 32, 18, P.ink);
      out += r(22, 32, 24, 18, P.forest) + r(26, 28, 12, 6, P.forest);
      out += r(26, 36, 8, 4, P.lime) + r(38, 44, 6, 4, P.cream);
      out += r(30, 26, 6, 4, P.brick);
      return out;
    }
    case 14: {
      let out = paved(114, P.soil);
      out += r(18, 18, 30, 38, P.ink) + r(22, 14, 22, 6, P.ink);
      out += r(22, 20, 22, 34, P.turquoise) + r(26, 16, 14, 4, P.turquoise);
      out += r(26, 26, 14, 4, P.forest) + r(26, 34, 14, 4, P.forest);
      out += r(26, 42, 14, 4, P.forest);
      out += r(20, 52, 8, 6, P.ink) + r(38, 52, 8, 6, P.ink);
      return out;
    }
    case 15: {
      let out = r(0, 0, 64, 64, P.leaf);
      out += r(6, 10, 52, 46, P.soil);
      for (const [x, y] of [[14, 30], [28, 24], [44, 34], [32, 44], [50, 18]]) {
        out += r(x, y + 4, 2, 10, P.forest);
        out += r(x - 4, y, 6, 4, P.lime) + r(x + 2, y - 4, 6, 4, P.turquoise);
      }
      out += r(6, 10, 52, 4, P.brick);
      return out;
    }
    case 16: {
      let out = texture(P.water, 116, [P.turquoise, P.sky], 24, 4);
      out += r(0, 0, 20, 64, P.soil) + r(0, 0, 16, 64, P.leaf);
      out += r(0, 8, 8, 48, P.leaf) + r(16, 0, 4, 64, P.brick);
      out += r(24, 14, 16, 2, P.sky) + r(36, 42, 18, 2, P.turquoise);
      out += leaf(8, 20, 8, P.lime) + leaf(8, 44, 8, P.lime);
      return out;
    }
    case 17: return paved(117);
    case 18: {
      let out = r(0, 0, 64, 64, P.forest);
      for (let y = 4; y < 64; y += 12) {
        for (let x = 2; x < 64; x += 14) {
          out += blob(x, y, 16, 18, P.leaf);
          out += r(x + 4, y + 4, 8, 4, P.lime);
          out += r(x + 8, y + 10, 4, 4, P.turquoise);
        }
      }
      return out;
    }
    case 19: {
      let out = grass(119);
      out += r(18, 48, 32, 10, P.ink, ' opacity="0.35"');
      out += r(22, 42, 22, 16, P.soil);
      out += r(28, 24, 10, 32, P.ink) + r(30, 24, 6, 30, P.soil);
      out += r(30, 28, 2, 22, P.brick);
      out += r(22, 50, 12, 4, P.soil) + r(36, 50, 14, 4, P.soil);
      out += r(24, 54, 8, 2, P.ink) + r(40, 54, 8, 2, P.ink);
      return out;
    }
    case 20: {
      let out = grass(120);
      out += r(28, 20, 8, 38, P.ink) + r(30, 22, 4, 34, P.brick);
      out += r(10, 14, 42, 20, P.ink) + r(14, 18, 34, 12, P.cream);
      out += r(30, 20, 4, 8, P.soil) + r(26, 18, 12, 4, P.leaf);
      out += r(24, 20, 4, 4, P.leaf) + r(36, 20, 4, 4, P.lime);
      return out;
    }
    case 21: {
      let out = grass(121);
      out += r(12, 46, 42, 10, P.ink) + r(16, 42, 34, 10, P.brick);
      out += r(16, 42, 28, 3, P.cream);
      out += r(12, 22, 40, 12, P.ink) + r(16, 24, 32, 8, P.brick);
      out += r(14, 34, 4, 22, P.ink) + r(46, 34, 4, 22, P.ink);
      return out;
    }
    case 22: {
      let out = paved(122, P.soil);
      out += r(8, 8, 8, 48, P.ink) + r(48, 8, 8, 48, P.ink);
      out += r(10, 10, 4, 44, P.brick) + r(50, 10, 4, 44, P.brick);
      for (let x = 18; x <= 46; x += 8) {
        out += r(x, 18, 3, 38, P.forest);
      }
      out += r(16, 24, 36, 3, P.forest) + r(16, 48, 36, 3, P.forest);
      out += r(28, 10, 8, 6, P.cream);
      return out;
    }
    case 23: {
      let out = paved(123, P.soil);
      out += r(12, 20, 40, 36, P.ink) + r(16, 16, 32, 44, P.ink);
      out += r(20, 20, 24, 36, P.cream) + r(20, 24, 24, 28, P.water);
      out += r(16, 20, 32, 4, P.cream) + r(24, 12, 16, 12, P.ink);
      out += r(28, 8, 8, 12, P.turquoise) + r(30, 4, 4, 8, P.sky);
      out += r(24, 30, 8, 2, P.sky) + r(34, 38, 6, 2, P.sky);
      return out;
    }
    case 24: {
      let out = texture(P.soil, 124, [P.brick, P.ink], 34);
      out += p('M8 12h12v4h4v8h4v-4h8v4h4v-8h4V12h12', 'none', ` ${stroke(P.brick, 2)}`);
      out += p('M12 42h10v4h4v8h6v-4h8v4h6v-8h4v-4h8', 'none', ` ${stroke(P.ink, 2)}`);
      return out;
    }
    case 25: {
      let out = texture(P.soil, 125, [P.ink, P.brick], 30);
      out += r(6, 8, 22, 14, P.brick) + r(36, 38, 22, 14, P.brick);
      out += r(6, 8, 22, 4, P.cream) + r(36, 38, 22, 4, P.cream);
      out += r(32, 6, 4, 50, P.forest) + r(34, 6, 2, 50, P.lime);
      out += r(10, 28, 8, 8, P.ink) + r(46, 20, 8, 8, P.ink);
      return out;
    }
    case 26: {
      let out = paved(126, P.sky);
      out += r(10, 10, 44, 44, P.ink) + r(14, 14, 36, 36, P.leaf);
      out += r(22, 22, 20, 20, P.soil) + r(28, 18, 8, 28, P.forest);
      out += blob(20, 16, 24, 24, P.leaf) + r(24, 20, 12, 6, P.lime);
      return out;
    }
    case 27: {
      let out = paved(127, P.cream);
      out += r(8, 8, 48, 48, P.brick) + r(12, 12, 40, 40, P.sky);
      out += r(20, 20, 24, 24, P.forest) + r(24, 24, 16, 16, P.turquoise);
      out += r(30, 12, 4, 40, P.cream) + r(12, 30, 40, 4, P.cream);
      return out;
    }
    case 28: {
      let out = grass(128, true);
      out += r(8, 30, 16, 2, P.cream) + r(40, 18, 14, 2, P.cream);
      out += r(22, 52, 18, 2, P.brick);
      return out;
    }
    case 29: {
      let out = texture(P.water, 129, [P.forest, P.turquoise], 32, 4);
      out += r(6, 8, 22, 4, P.forest) + r(36, 24, 20, 4, P.forest);
      out += r(16, 40, 16, 2, P.sky) + r(40, 52, 12, 2, P.sky);
      return out;
    }
    case 30: {
      let out = r(0, 0, 64, 64, P.ink);
      for (let row = 0; row < 6; row += 1) {
        const y = row * 11;
        const offset = row % 2 ? -8 : 0;
        for (let col = 0; col < 6; col += 1) {
          const x = col * 16 + offset;
          out += r(x + 2, y + 2, 12, 7, P.brick);
          out += r(x + 2, y + 2, 10, 2, P.cream);
          out += r(x + 2, y + 7, 12, 2, P.soil);
        }
      }
      return out;
    }
    case 31: {
      let out = paved(131, P.soil);
      out += r(4, 8, 8, 48, P.ink) + r(52, 8, 8, 48, P.ink);
      out += r(6, 10, 4, 44, P.brick) + r(54, 10, 4, 44, P.brick);
      out += r(12, 16, 6, 40, P.forest) + r(46, 16, 6, 40, P.forest);
      out += r(18, 20, 22, 4, P.forest) + r(24, 24, 20, 4, P.forest);
      out += r(30, 28, 18, 4, P.forest);
      out += r(28, 10, 8, 6, P.cream);
      return out;
    }
    default: throw new Error(`Unknown tile index ${index}`);
  }
}

function buildTiles() {
  let body = '';
  for (let i = 0; i < 32; i += 1) {
    const col = i % 8;
    const row = Math.floor(i / 8);
    body += g(tileArt(i), col * 64, row * 64, ` data-cell="${row},${col}"`) + '\n';
  }
  return { name: 'tiles.svg', width: 512, height: 256, usedCells: 32, source: svg(512, 256, body.trimEnd()) };
}

function shadow() {
  return r(18, 56, 28, 4, P.ink, ' opacity="0.22"');
}

function characterPalette(config = {}) {
  const colors = {
    edge: '#293238', skin: '#dfac82', skinLight: '#f3cca1', skinShade: '#b97b59',
    blush: '#cd8b70', hair: '#654638', hairLight: '#997050', hairShade: '#3e3431',
    coat: '#467fa3', coatLight: '#73adc1', coatShade: '#33566f', coatDeep: '#293f55',
    red: '#bd4c4f', redLight: '#e07b69', redShade: '#853d46',
    leather: '#8b6146', leatherLight: '#ba8a59', leatherShade: '#5b4437',
    brass: '#ddbc78', cream: '#efdfbb', pants: '#495e59', pantsLight: '#728279',
    shoe: '#594840', shoeLight: '#93715a', sole: '#30383b',
    teal: '#428c89', tealLight: '#79b9ad', tealShade: '#305c63',
    pink: '#c67d90', pinkLight: '#e8abb1', pinkShade: '#895869',
    silver: '#c8cabb', silverLight: '#eee6ce', silverShade: '#8a9e95',
  };
  if (config.beard) Object.assign(colors, {
    coat: '#526f50', coatLight: '#8aa373', coatShade: '#3b5343', coatDeep: '#30433a',
    hair: colors.silver, hairLight: colors.silverLight, hairShade: colors.silverShade,
    skin: '#d4a078', skinLight: '#ebbf90', skinShade: '#a46e52',
  });
  else if (config.headscarf) Object.assign(colors, {
    coat: '#e0d0ad', coatLight: '#f4e5c5', coatShade: '#b4aa8d', coatDeep: '#827f70',
    skin: '#bf875f', skinLight: '#e0af80', skinShade: '#925b46', pants: '#356967',
  });
  else if (config.longHair) Object.assign(colors, {
    coat: '#96b9bb', coatLight: '#ccdbcb', coatShade: '#66868e', coatDeep: '#4c636f',
    hair: '#624039', hairLight: '#a06c50', hairShade: '#3e3033', pants: '#555262',
  });
  else if (config.cap) Object.assign(colors, {
    coat: '#be8c48', coatLight: '#e0b667', coatShade: '#8f683e', coatDeep: '#624d38',
    hair: '#403734', hairLight: '#725747', hairShade: '#2e3032',
    skin: '#d3a071', skinLight: '#ecc190', skinShade: '#a57250', pants: '#53634f',
  });
  return colors;
}

function characterPixels(pixels, colors = characterPalette()) {
  // Local SVG swatches leave the shared environment palette untouched.
  return pixels.map(([x, y, w, h, shade]) =>
    r(x, y, w, h, P.ink, ` style="fill:${colors[shade]}"`)).join('');
}

function characterHand(x, y, colors = characterPalette(), open = false) {
  let out = characterPixels([
    [x + 1, y, 3, 5, 'edge'], [x, y + 1, 5, 3, 'edge'],
    [x + 1, y + 1, 3, 3, 'skin'], [x + 1, y + 1, 2, 1, 'skinLight'],
    [x + 3, y + 3, 1, 1, 'skinShade'], [x + 4, y + 1, 1, 2, 'skin'],
  ], colors);
  if (open) out += characterPixels([
    [x + 1, y - 3, 1, 4, 'skinLight'], [x + 3, y - 2, 1, 3, 'skin'],
    [x, y - 1, 1, 3, 'skin'], [x + 4, y, 1, 2, 'skinShade'],
  ], colors);
  return out;
}

function playerLegs(frame, planted = false, side = false) {
  const stride = planted ? 0 : [0, 1, 0, -1][frame % 4];
  const passing = !planted && frame % 4 === 2;
  let out = '';
  for (let leg = 0; leg < 2; leg += 1) {
    const swing = stride * (leg === 0 ? 1 : -1);
    const x = (side ? 27 + leg * 5 : 24 + leg * 9) + swing * (side ? 3 : 1);
    const lift = swing < 0 ? 2 : passing && leg === 0 ? 1 : 0;
    out += characterPixels([
      [x, 47, 7, 8 - lift, 'edge'], [x + 1, 48, 5, 5 - lift, 'pants'],
      [x + 1, 49, 2, 3, 'pantsLight'], [x + 1, 53 - lift, 5, 1, 'coatShade'],
      [x - (side ? 2 : 1), 54 - lift, 8, 3, 'shoe'],
      [x - (side ? 2 : 1), 56 - lift, 8, 1, 'sole'],
      [x, 54 - lift, 4, 1, 'shoeLight'], [x + 3, 55 - lift, 2, 1, 'leatherLight'],
    ]);
  }
  return out;
}

function backpack(x = 22, y = 32, side = false) {
  const w = side ? 12 : 18;
  return characterPixels([
    [x + 2, y - 2, w - 4, 2, 'edge'], [x, y, w, 19, 'edge'],
    [x + 1, y + 1, w - 2, 16, 'leather'], [x + w - 4, y + 2, 3, 15, 'leatherShade'],
    [x + 2, y + 2, w - 6, 5, 'leatherLight'], [x + 2, y + 7, w - 4, 1, 'leatherShade'],
    [x + 3, y + 10, w - 6, 6, 'leatherShade'], [x + 4, y + 11, w - 8, 4, 'leather'],
    [x + 3, y + 10, w - 6, 1, 'leatherLight'], [x + 4, y + 4, 2, 5, 'leatherShade'],
    [x + w - 6, y + 4, 2, 5, 'leatherShade'], [x + 4, y + 6, 2, 2, 'brass'],
    [x + w - 6, y + 6, 2, 2, 'brass'], [x + 2, y + 17, w - 4, 1, 'leatherLight'],
  ]);
}

function scarf(y = 29) {
  return characterPixels([
    [23, y, 18, 5, 'edge'], [24, y, 16, 3, 'redShade'],
    [24, y + 1, 14, 2, 'red'], [25, y + 1, 7, 1, 'redLight'],
    [35, y + 2, 5, 4, 'redShade'], [36, y + 3, 3, 3, 'red'],
    [36, y + 6, 4, 6, 'edge'], [36, y + 5, 3, 6, 'red'],
    [36, y + 5, 1, 4, 'redLight'], [37, y + 10, 2, 2, 'redShade'],
    [36, y + 11, 1, 2, 'red'], [38, y + 11, 1, 2, 'red'],
  ]);
}

function playerHead(direction = 'down') {
  if (direction === 'up') return characterPixels([
    [26, 9, 12, 2, 'edge'], [23, 11, 18, 3, 'edge'], [22, 14, 21, 12, 'edge'],
    [24, 26, 17, 4, 'edge'], [23, 14, 19, 11, 'hair'], [25, 11, 14, 6, 'hair'],
    [24, 13, 7, 2, 'hairLight'], [27, 11, 7, 1, 'hairLight'],
    [23, 17, 2, 4, 'hairLight'], [25, 17, 2, 2, 'hairLight'],
    [36, 15, 5, 10, 'hairShade'], [33, 24, 8, 3, 'hairShade'],
    [25, 25, 3, 3, 'hair'], [29, 26, 3, 3, 'hair'], [35, 26, 3, 3, 'hair'],
    [21, 23, 2, 4, 'skinShade'], [42, 23, 2, 4, 'skinShade'],
    [22, 23, 1, 2, 'skinLight'], [42, 23, 1, 2, 'skin'],
    [28, 29, 9, 2, 'skinShade'], [30, 29, 5, 1, 'skin'],
  ]);
  if (direction === 'side') return characterPixels([
    [28, 9, 11, 2, 'edge'], [25, 11, 17, 3, 'edge'], [24, 14, 20, 12, 'edge'],
    [25, 26, 15, 3, 'edge'], [22, 22, 3, 4, 'edge'],
    [26, 15, 13, 11, 'skin'], [25, 19, 4, 8, 'skin'], [23, 23, 3, 2, 'skinLight'],
    [26, 17, 6, 3, 'skinLight'], [27, 25, 8, 3, 'skin'], [34, 24, 5, 4, 'skinShade'],
    [29, 28, 7, 3, 'skinShade'], [29, 28, 4, 2, 'skin'],
    [26, 12, 15, 5, 'hair'], [37, 16, 6, 9, 'hair'], [39, 25, 3, 4, 'hairShade'],
    [25, 15, 5, 3, 'hairShade'], [29, 15, 3, 3, 'hair'], [34, 15, 3, 4, 'hair'],
    [28, 12, 8, 1, 'hairLight'], [26, 13, 6, 1, 'hairLight'], [38, 15, 2, 5, 'hairLight'],
    [36, 21, 3, 4, 'skin'], [37, 22, 1, 2, 'skinShade'],
    [26, 20, 3, 1, 'hairShade'], [26, 22, 2, 2, 'edge'], [26, 22, 1, 1, 'cream'],
    [25, 26, 3, 1, 'blush'], [28, 27, 2, 1, 'skinLight'], [28, 10, 3, 1, 'hair'],
  ]);
  return characterPixels([
    [26, 9, 12, 2, 'edge'], [23, 11, 18, 3, 'edge'], [22, 14, 21, 12, 'edge'],
    [24, 26, 17, 3, 'edge'], [27, 29, 10, 2, 'edge'],
    [24, 15, 17, 11, 'skin'], [26, 25, 13, 4, 'skin'],
    [25, 17, 10, 3, 'skinLight'], [25, 20, 3, 4, 'skinLight'],
    [38, 18, 3, 9, 'skinShade'], [29, 29, 7, 2, 'skinShade'], [29, 29, 4, 1, 'skin'],
    [21, 22, 3, 4, 'skinShade'], [42, 22, 2, 4, 'skinShade'],
    [22, 22, 2, 2, 'skin'], [42, 22, 1, 2, 'skin'],
    [24, 12, 16, 4, 'hair'], [23, 15, 3, 6, 'hair'], [39, 15, 3, 6, 'hairShade'],
    [25, 15, 5, 3, 'hair'], [30, 14, 3, 3, 'hair'], [35, 15, 4, 3, 'hair'],
    [25, 12, 8, 1, 'hairLight'], [24, 13, 4, 1, 'hairLight'], [34, 13, 4, 1, 'hairLight'],
    [23, 18, 1, 3, 'hairLight'], [26, 20, 3, 1, 'hairShade'], [35, 20, 3, 1, 'hairShade'],
    [26, 22, 2, 2, 'edge'], [35, 22, 2, 2, 'edge'],
    [26, 22, 1, 1, 'cream'], [35, 22, 1, 1, 'cream'],
    [31, 23, 1, 2, 'skinShade'], [30, 25, 2, 1, 'skinLight'],
    [25, 25, 3, 1, 'blush'], [36, 25, 3, 1, 'blush'],
    [30, 27, 4, 1, 'blush'], [31, 28, 2, 1, 'skinLight'], [26, 10, 3, 1, 'hair'],
  ]);
}

function playerDown(frame, action = 'walk') {
  const swing = action === 'walk' ? [0, 1, 0, -1][frame % 4] : 0;
  let out = shadow() + playerLegs(frame, action !== 'walk');
  out += backpack(23, 32);
  out += characterPixels([
    [24, 30, 16, 3, 'edge'], [21, 33, 22, 16, 'edge'], [23, 48, 18, 3, 'edge'],
    [23, 33, 18, 16, 'coat'], [23, 34, 5, 11, 'coatLight'],
    [38, 34, 3, 14, 'coatShade'], [24, 47, 16, 2, 'coatShade'],
    [31, 34, 2, 14, 'coatDeep'], [32, 35, 1, 11, 'coatLight'],
    [25, 34, 2, 8, 'leatherShade'], [25, 34, 1, 7, 'leatherLight'],
    [38, 34, 2, 8, 'leatherShade'], [38, 34, 1, 7, 'leather'],
    [25, 39, 2, 2, 'brass'], [38, 39, 2, 2, 'brass'],
    [25, 43, 4, 4, 'coatShade'], [25, 43, 4, 1, 'coatLight'],
    [35, 43, 4, 4, 'coatShade'], [35, 43, 4, 1, 'coatLight'],
    [32, 42, 1, 1, 'brass'], [32, 46, 1, 1, 'brass'],
    [18, 34, 5, 10 + swing, 'edge'], [19, 35, 3, 8 + swing, 'coat'],
    [19, 35, 1, 6, 'coatLight'], [19, 43 + swing, 3, 2, 'coatShade'],
    [42, 34, 5, 10 - swing, 'edge'], [43, 35, 3, 8 - swing, 'coatShade'],
    [43, 36, 1, 5, 'coat'], [43, 43 - swing, 3, 2, 'coatDeep'],
  ]);
  out += characterHand(18, 45 + swing);
  if (action === 'walk') out += characterHand(42, 45 - swing);
  out += scarf() + playerHead();
  if (action === 'water') {
    out += characterPixels([
      [43, 36, 5, 5, 'coatShade'], [44, 37, 4, 3, 'coat'],
      [46, 35, 7, 5, 'edge'], [47, 36, 5, 1, 'tealLight'],
      [47, 37, 1, 3, 'teal'], [51, 37, 1, 3, 'tealShade'],
      [45, 40, 11, 9, 'edge'], [46, 41, 9, 6, 'teal'],
      [46, 41, 7, 2, 'tealLight'], [53, 43, 2, 4, 'tealShade'],
      [47, 47, 7, 1, 'tealShade'], [48, 43, 3, 2, 'cream'],
      [55, 41, 4, 3, 'edge'], [57, 43, 4, 3, 'edge'],
      [55, 42, 3, 1, 'teal'], [58, 44, 3, 1, 'tealLight'],
      [60, 44, 2, 3, 'tealShade'],
    ]);
    out += characterHand(42, 37);
    const dropY = 48 + [0, 2, 4, 1][frame % 4];
    out += characterPixels([
      [60, dropY, 1, 3, 'coatLight'], [58, dropY + 3, 1, 2, 'tealLight'],
      [61, dropY + 3, 1, 2, 'coatLight'], [56, 57, 5, 1, 'tealShade'],
      [58, 56, 2, 1, 'tealLight'],
    ]);
  }
  if (action === 'plant') {
    const reach = [0, 2, 1, 0][frame % 4];
    out += characterPixels([
      [43, 39, 4, 8, 'edge'], [44, 40, 2, 6, 'coat'],
      [44, 45, 5, 3, 'coatShade'], [42, 55, 17, 3, 'edge'],
      [44, 53, 13, 4, 'leatherShade'], [46, 53, 9, 1, 'leather'],
      [44, 56, 2, 1, 'leatherLight'], [54, 55, 2, 1, 'leatherLight'],
    ]);
    out += characterHand(46, 46 + reach);
    if (frame === 0) out += characterPixels([[50, 49, 2, 2, 'brass'], [51, 50, 1, 1, 'leather']]);
    else out += characterPixels([
      [51, 48, 1, 6, 'tealShade'], [52, 48, 1, 5, 'teal'],
      [48, 47, 3, 2, 'teal'], [49, 46, 2, 1, 'tealLight'],
      [53, 45, 3, 2, 'teal'], [54, 44, 2, 1, 'tealLight'],
      ...(frame >= 2 ? [[51, 44, 1, 5, 'teal'], [52, 43, 2, 2, 'tealLight']] : []),
    ]);
  }
  return out;
}

function playerUp(frame) {
  const swing = [0, 1, 0, -1][frame % 4];
  let out = shadow() + playerLegs(frame);
  out += characterPixels([
    [24, 30, 16, 3, 'edge'], [21, 33, 22, 17, 'edge'], [23, 33, 18, 16, 'coat'],
    [23, 34, 4, 12, 'coatLight'], [39, 34, 2, 14, 'coatShade'],
    [23, 48, 18, 2, 'coatShade'], [18, 34, 5, 11 - swing, 'edge'],
    [19, 35, 3, 9 - swing, 'coat'], [19, 35, 1, 7, 'coatLight'],
    [42, 34, 5, 11 + swing, 'edge'], [43, 35, 3, 9 + swing, 'coatShade'],
    [43, 36, 1, 6, 'coat'], [21, 32, 3, 13, 'leatherShade'],
    [22, 33, 1, 9, 'leatherLight'], [41, 32, 2, 13, 'leatherShade'],
  ]);
  out += characterHand(18, 45 - swing) + characterHand(42, 45 + swing);
  out += scarf() + backpack(24, 32) + playerHead('up');
  return out;
}

function playerSide(frame, facingRight) {
  const swing = [0, 1, 0, -1][frame % 4];
  let out = shadow() + playerLegs(frame, false, true);
  out += characterPixels([
    [24, 34, 4, 11 - swing, 'edge'], [25, 35, 2, 9 - swing, 'coatShade'],
  ]);
  out += characterHand(23, 45 - swing) + backpack(35, 32, true);
  out += characterPixels([
    [28, 30, 10, 3, 'edge'], [25, 33, 16, 17, 'edge'], [26, 33, 13, 16, 'coat'],
    [26, 34, 4, 13, 'coatLight'], [37, 34, 3, 15, 'coatShade'],
    [26, 48, 14, 2, 'coatDeep'], [26, 43, 3, 4, 'coatShade'],
    [26, 43, 3, 1, 'coatLight'], [34, 32, 2, 13, 'leatherShade'],
    [34, 33, 1, 10, 'leatherLight'], [34, 40, 2, 2, 'brass'],
    [30 + swing * 2, 35, 6, 10, 'edge'], [31 + swing * 2, 36, 4, 8, 'coat'],
    [31 + swing * 2, 36, 2, 5, 'coatLight'], [31 + swing * 2, 43, 4, 2, 'coatShade'],
    [27, 29, 12, 4, 'edge'], [27, 30, 11, 2, 'red'], [28, 30, 5, 1, 'redLight'],
    [25, 32, 3, 8, 'redShade'], [25, 32, 2, 7, 'red'], [25, 32, 1, 5, 'redLight'],
  ]);
  out += characterHand(31 + swing * 2, 45) + playerHead('side');
  return facingRight ? `<g transform="translate(64 0) scale(-1 1)">${out}</g>` : out;
}

function playerArt(row, col) {
  if (row === 0) return playerDown(col);
  if (row === 1) return playerUp(col);
  if (row === 2) return playerSide(col, false);
  if (row === 3) return playerSide(col, true);
  if (row === 4) return playerDown(col, 'water');
  return playerDown(col, 'plant');
}

function buildPlayer() {
  let body = '';
  for (let row = 0; row < 6; row += 1) {
    for (let col = 0; col < 4; col += 1) {
      body += g(playerArt(row, col), col * 64, row * 64, ` data-cell="${row},${col}"`) + '\n';
    }
  }
  return { name: 'player.svg', width: 256, height: 384, usedCells: 24, source: svg(256, 384, body.trimEnd()) };
}

function npcHead(config, pose, bob) {
  const c = characterPalette(config);
  let out = '';
  if (config.longHair) out += characterPixels([
    [22, 15, 21, 21, 'edge'], [23, 18, 4, 19, 'hair'], [39, 18, 4, 20, 'hairShade'],
    [23, 22, 1, 11, 'hairLight'], [24, 34, 4, 4, 'hairShade'], [38, 35, 4, 3, 'hair'],
  ], c);
  out += characterPixels([
    [26, 10, 12, 2, 'edge'], [23, 12, 18, 3, 'edge'], [22, 15, 21, 11, 'edge'],
    [24, 26, 17, 3, 'edge'], [28, 29, 8, 3, 'skinShade'],
    [24, 15, 17, 11, 'skin'], [26, 25, 13, 4, 'skin'],
    [25, 17, 10, 3, 'skinLight'], [25, 20, 3, 4, 'skinLight'],
    [39, 18, 2, 8, 'skinShade'], [31, 23, 1, 2, 'skinShade'], [30, 25, 2, 1, 'skinLight'],
    [21, 22, 3, 4, 'skinShade'], [42, 22, 2, 4, 'skinShade'],
    [22, 22, 2, 2, 'skin'], [42, 22, 1, 2, 'skin'],
    [24, 12, 16, 4, 'hair'], [23, 15, 3, 6, 'hairShade'], [39, 15, 3, 6, 'hairShade'],
    [25, 15, 5, 3, 'hair'], [30, 14, 3, 3, 'hair'], [35, 15, 4, 2, 'hair'],
    [25, 12, 7, 1, 'hairLight'], [24, 13, 4, 1, 'hairLight'], [35, 13, 3, 1, 'hairLight'],
  ], c);
  if (config.beard) out += characterPixels([
    [26, 13, 12, 5, 'skinLight'], [23, 15, 3, 5, 'silver'], [39, 15, 3, 6, 'silverShade'],
    [24, 12, 4, 3, 'silver'], [36, 12, 4, 3, 'silver'], [25, 12, 3, 1, 'silverLight'],
    [24, 25, 3, 5, 'silverShade'], [38, 25, 3, 5, 'silverShade'],
    [26, 27, 13, 6, 'silver'], [28, 32, 9, 3, 'silverShade'], [29, 32, 6, 2, 'silver'],
    [27, 28, 2, 4, 'silverLight'], [30, 30, 2, 3, 'silverLight'],
    [35, 29, 2, 3, 'silverShade'], [27, 26, 4, 2, 'silverLight'], [33, 26, 4, 2, 'silverLight'],
    [26, 19, 3, 1, 'silverShade'], [35, 19, 3, 1, 'silverShade'],
    [25, 24, 2, 1, 'skinShade'], [37, 24, 2, 1, 'skinShade'],
  ], c);
  if (config.headscarf) out += characterPixels([
    [27, 8, 10, 2, 'edge'], [23, 10, 18, 3, 'edge'], [21, 13, 23, 16, 'edge'],
    [22, 28, 6, 8, 'edge'], [38, 28, 6, 9, 'edge'],
    [25, 10, 14, 4, 'teal'], [23, 13, 19, 14, 'teal'],
    [25, 13, 14, 3, 'tealShade'], [24, 16, 3, 10, 'tealLight'],
    [27, 16, 12, 10, 'skin'], [28, 25, 10, 4, 'skin'],
    [28, 17, 8, 3, 'skinLight'], [37, 19, 2, 7, 'skinShade'],
    [31, 23, 1, 2, 'skinShade'], [30, 25, 2, 1, 'skinLight'],
    [27, 11, 8, 1, 'tealLight'], [24, 12, 6, 1, 'tealLight'],
    [22, 17, 2, 12, 'teal'], [23, 28, 4, 6, 'teal'], [24, 28, 1, 5, 'tealLight'],
    [40, 15, 3, 14, 'tealShade'], [39, 27, 4, 8, 'tealShade'],
    [40, 29, 2, 6, 'teal'], [28, 29, 11, 3, 'teal'], [29, 29, 8, 1, 'tealLight'],
    [34, 32, 5, 3, 'tealShade'], [35, 32, 3, 2, 'teal'],
    [24, 31, 1, 1, 'cream'], [24, 33, 1, 1, 'cream'], [40, 33, 1, 1, 'cream'],
  ], c);
  if (config.longHair) out += characterPixels([
    [26, 9, 11, 2, 'edge'], [25, 11, 14, 5, 'hair'], [24, 15, 6, 3, 'hair'],
    [24, 18, 3, 2, 'hair'], [30, 14, 3, 3, 'hair'], [37, 15, 3, 6, 'hairShade'],
    [26, 11, 7, 1, 'hairLight'], [25, 12, 4, 1, 'hairLight'], [24, 15, 2, 2, 'hairLight'],
    [38, 16, 3, 1, 'pinkLight'], [39, 17, 2, 1, 'pink'],
    [25, 25, 3, 1, 'blush'], [36, 25, 3, 1, 'blush'],
  ], c);
  if (config.cap) out += characterPixels([
    [25, 9, 14, 2, 'edge'], [23, 11, 19, 5, 'edge'], [24, 11, 17, 4, 'coat'],
    [25, 11, 9, 1, 'coatLight'], [37, 12, 4, 3, 'coatShade'],
    [22, 15, 23, 2, 'edge'], [23, 15, 20, 1, 'coatLight'],
    [30, 12, 3, 2, 'cream'], [31, 12, 1, 1, 'teal'],
    [25, 17, 2, 2, 'hairShade'], [38, 17, 3, 3, 'hairShade'],
  ], c);
  const eyeY = config.headscarf ? 22 : 21;
  out += characterPixels([
    [27, eyeY - 2, 3, 1, config.beard ? 'silverShade' : 'hairShade'],
    [35, eyeY - 2 - (pose === 'think' ? 1 : 0), 3, 1, config.beard ? 'silverShade' : 'hairShade'],
    [27, eyeY, 2, 2, 'edge'], [35, eyeY, 2, 2, 'edge'],
    [27, eyeY, 1, 1, 'cream'], [35, eyeY, 1, 1, 'cream'],
  ], c);
  if (config.longHair) out += characterPixels([[26, eyeY, 1, 1, 'hairShade'], [37, eyeY, 1, 1, 'hairShade']], c);
  if (config.beard) out += characterPixels([
    [25, 20, 6, 1, 'edge'], [25, 20, 1, 4, 'edge'], [30, 20, 1, 4, 'edge'],
    [25, 24, 6, 1, 'edge'], [34, 20, 6, 1, 'edge'], [34, 20, 1, 4, 'edge'],
    [39, 20, 1, 4, 'edge'], [34, 24, 6, 1, 'edge'], [31, 21, 3, 1, 'leatherShade'],
    [23, 21, 2, 1, 'edge'], [40, 21, 2, 1, 'edge'], [26, 20, 2, 1, 'silverLight'],
    [35, 20, 2, 1, 'silverLight'],
  ], c);
  const mouthY = config.beard ? 29 : 27;
  if (pose === 'talk') out += characterPixels([
    [30, mouthY, 4, 2, 'edge'], [31, mouthY, 2, 1, 'cream'], [31, mouthY + 1, 2, 1, 'blush'],
  ], c);
  else if (pose === 'happy' || pose === 'wave') out += characterPixels([
    [29, mouthY, 1, 1, 'blush'], [30, mouthY + 1, 4, 1, config.beard ? 'edge' : 'blush'],
    [34, mouthY, 1, 1, 'blush'], [31, mouthY, 2, 1, 'skinLight'],
  ], c);
  else out += characterPixels([[30, mouthY, 4, 1, config.beard ? 'edge' : 'blush']], c);
  return out;
}

function npcArms(config, pose, bob) {
  const c = characterPalette(config);
  const left = config.beard ? 17 : 18;
  const right = config.beard ? 43 : 42;
  const cuff = config.cap ? 'cream' : config.headscarf ? 'teal' : 'coatShade';
  const idleArm = (x, light) => characterPixels([
    [x, 34 + bob, 5, 12, 'edge'], [x + 1, 35 + bob, 3, 10, light ? 'coat' : 'coatShade'],
    [x + 1, 35 + bob, 1, 7, light ? 'coatLight' : 'coat'],
    [x + 1, 43 + bob, 3, 3, cuff], [x + 1, 43 + bob, 2, 1, 'coatLight'],
  ], c) + characterHand(x, 46 + bob, c);
  if (pose === 'wave') return characterPixels([
    [16, 22, 5, 14, 'edge'], [17, 23, 3, 11, 'coat'], [17, 23, 1, 9, 'coatLight'],
    [18, 33, 6, 5, 'edge'], [19, 33, 4, 3, 'coat'], [17, 22, 3, 2, cuff],
  ], c) + characterHand(16, 18, c, true) + idleArm(right, false);
  if (pose === 'happy') return characterPixels([
    [16, 32, 7, 6, 'edge'], [17, 33, 6, 4, 'coat'], [16, 30, 5, 5, 'edge'],
    [17, 31, 3, 3, 'coatLight'], [42, 32, 7, 6, 'edge'], [42, 33, 6, 4, 'coatShade'],
    [45, 30, 5, 5, 'edge'], [46, 31, 3, 3, 'coat'],
  ], c) + characterHand(16, 27, c, true) + characterHand(45, 27, c, true);
  if (pose === 'talk') return idleArm(left, true) + characterPixels([
    [42, 34, 5, 9, 'edge'], [43, 35, 3, 7, 'coatShade'], [45, 37, 5, 5, 'edge'],
    [45, 38, 4, 3, 'coat'], [47, 36, 3, 2, cuff], [43, 35, 1, 4, 'coat'],
  ], c) + characterHand(47, 32, c, true);
  if (pose === 'think') return idleArm(left, true) + characterPixels([
    [42, 34, 5, 10, 'edge'], [43, 35, 3, 8, 'coatShade'], [39, 37, 5, 5, 'edge'],
    [40, 37, 3, 4, 'coat'], [38, 33, 5, 6, 'edge'], [39, 34, 3, 4, 'coatLight'],
    [39, 33, 3, 2, cuff],
  ], c);
  return idleArm(left, true) + idleArm(right, false);
}

function npcArt(config, pose) {
  const c = characterPalette(config);
  const bob = pose === 'idle1' ? -1 : 0;
  const x = config.beard ? 21 : 23;
  const w = config.beard ? 22 : 18;
  let out = shadow();
  for (const legX of [25, 34]) out += characterPixels([
    [legX, 47, 6, 9, 'edge'], [legX + 1, 48, 4, 7, 'pants'],
    [legX + 1, 50, 1, 4, 'pantsLight'], [legX - 1, 54, 8, 3, 'shoe'],
    [legX - 1, 56, 8, 1, 'sole'], [legX, 54, 4, 1, 'shoeLight'],
    [legX + 3, 55, 2, 1, 'leatherLight'],
  ], c);
  out += characterPixels([
    [x + 2, 30, w - 4, 3, 'edge'], [x - 1, 33 + bob, w + 2, 16 - bob, 'edge'],
    [x, 33 + bob, w, 16 - bob, 'coat'], [x, 34 + bob, 5, 12, 'coatLight'],
    [x + w - 3, 34 + bob, 3, 15, 'coatShade'], [x, 48, w, 2, 'coatShade'],
    [31, 34, 2, 14, 'coatShade'], [32, 34, 1, 13, 'coatLight'],
    [32, 39, 1, 1, 'brass'], [32, 44, 1, 1, 'brass'],
  ], c);
  if (config.beard) out += characterPixels([
    [24, 33, 4, 3, 'coatLight'], [26, 36, 3, 3, 'coatLight'], [28, 39, 3, 3, 'coatShade'],
    [36, 33, 4, 3, 'coatShade'], [34, 36, 3, 3, 'coatLight'], [33, 39, 2, 3, 'coatShade'],
    [24, 43, 5, 4, 'coatShade'], [24, 42, 5, 1, 'coatLight'],
    [36, 41, 4, 5, 'leatherShade'], [36, 40, 3, 4, 'cream'], [37, 40, 1, 4, 'brass'],
    [25, 47, 1, 1, 'brass'], [32, 47, 1, 1, 'brass'],
  ], c);
  if (config.headscarf) out += characterPixels([
    [22, 45, 20, 8, 'edge'], [23, 45, 18, 7, 'coat'], [24, 46, 3, 5, 'coatLight'],
    [37, 45, 3, 7, 'coatShade'], [23, 50, 18, 2, 'teal'], [24, 50, 16, 1, 'tealLight'],
    [26, 35, 2, 13, 'teal'], [26, 36, 1, 11, 'tealLight'], [36, 35, 2, 13, 'tealShade'],
    [31, 35, 3, 3, 'brass'], [32, 35, 1, 1, 'cream'],
    [29, 50, 1, 1, 'cream'], [33, 50, 1, 1, 'cream'], [37, 50, 1, 1, 'cream'],
  ], c);
  if (config.longHair) out += characterPixels([
    [24, 31, 6, 4, 'cream'], [34, 31, 6, 4, 'cream'], [28, 34, 3, 2, 'cream'],
    [33, 34, 3, 2, 'cream'], [30, 35, 4, 2, 'pinkShade'], [31, 35, 2, 1, 'pinkLight'],
    [23, 46, 18, 7, 'edge'], [24, 46, 16, 6, 'pants'], [24, 47, 2, 4, 'pinkShade'],
    [29, 47, 1, 5, 'coatDeep'], [35, 47, 1, 5, 'coatDeep'], [24, 51, 16, 1, 'pinkShade'],
    [26, 37, 3, 4, 'coatShade'], [26, 37, 3, 1, 'cream'],
  ], c);
  if (config.cap) out += characterPixels([
    [25, 32, 2, 15, 'coatDeep'], [36, 32, 2, 15, 'coatDeep'],
    [25, 33, 1, 12, 'leatherLight'], [36, 33, 1, 12, 'leatherLight'],
    [25, 36, 2, 2, 'brass'], [36, 36, 2, 2, 'brass'],
    [28, 38, 8, 7, 'coatShade'], [29, 39, 6, 5, 'coat'], [29, 39, 6, 1, 'coatLight'],
    [23, 47, 18, 2, 'leatherShade'], [31, 47, 3, 2, 'brass'], [32, 47, 1, 1, 'cream'],
    [39, 45, 3, 7, 'edge'], [40, 46, 1, 5, 'silver'], [39, 45, 3, 1, 'silverLight'],
    [24, 49, 3, 3, 'coatShade'], [24, 49, 3, 1, 'coatLight'],
  ], c);
  out += npcArms(config, pose, bob);
  if (config.longHair) out += characterPixels([
    [25, 33, 2, 3, 'pinkShade'], [27, 35, 2, 3, 'pinkShade'], [29, 37, 2, 2, 'pinkShade'],
    [31, 39, 2, 2, 'pinkShade'], [33, 41, 2, 2, 'pinkShade'], [35, 43, 4, 2, 'pinkShade'],
    [26, 33, 1, 2, 'pinkLight'], [28, 35, 1, 2, 'pinkLight'], [32, 39, 1, 2, 'pinkLight'],
    [39, 42, 6, 2, 'edge'], [38, 44, 8, 7, 'edge'], [39, 44, 6, 6, 'pink'],
    [39, 44, 6, 2, 'pinkLight'], [44, 46, 1, 4, 'pinkShade'], [41, 46, 2, 2, 'brass'],
    [40, 49, 3, 1, 'pinkLight'],
  ], c);
  out += npcHead(config, pose, bob);
  if (pose === 'think') out += characterHand(38, 29, c);
  return out;
}

function buildNpcs() {
  const configs = [
    { hair: P.sky, outfit: P.leaf, highlight: P.lime, beard: true, lapels: true },
    { hair: P.ink, outfit: P.brick, highlight: P.cream, headscarf: true },
    { hair: P.ink, outfit: P.sky, highlight: P.cream, longHair: true, skirt: true, backpack: true },
    { hair: P.ink, outfit: P.turquoise, highlight: P.sky, cap: P.brick, backpack: true },
  ];
  const poses = ['idle0', 'idle1', 'talk', 'happy', 'think', 'wave'];
  let body = '';
  for (let row = 0; row < 4; row += 1) {
    for (let col = 0; col < 6; col += 1) {
      body += g(npcArt(configs[row], poses[col]), col * 64, row * 64, ` data-cell="${row},${col}"`) + '\n';
    }
  }
  return { name: 'npcs.svg', width: 384, height: 256, usedCells: 24, source: svg(384, 256, body.trimEnd()) };
}

function soilBaseline(seed) {
  let out = r(18, 56, 28, 4, P.ink, ' opacity="0.18"');
  out += blob(20, 52, 24, 8, P.ink);
  out += blob(22, 52, 20, 6, P.soil);
  out += r(24, 53, 12, 2, P.bark) + r(28, 57, 8, 2, P.forest);
  const random = rng(seed);
  for (let i = 0; i < 6; i += 1) {
    out += r(22 + Math.floor(random() * 9) * 2, 52 + Math.floor(random() * 3) * 2, 2, 2,
      i % 2 ? P.brick : P.cream);
  }
  return out;
}

function stem(x, y0, y1, color = P.leaf, width = 4) {
  return p(`M${x} ${y0}V${y1}`, 'none', ` ${stroke(color, width)}`);
}

function branch(x0, y0, x1, y1, color = P.soil, width = 4) {
  return p(`M${x0} ${y0}V${y0 + (y1 - y0) * 0.55}H${x1}V${y1}`, 'none', ` ${stroke(color, width)}`);
}

function detailLeaf(x, y, size, fill = P.leaf, light = P.lime) {
  const half = Math.floor(size / 2);
  let out = r(x - half - 1, y - 2, size + 2, 5, P.ink);
  out += r(x - half + 1, y - 4, Math.max(2, size - 2), 9, P.ink);
  out += r(x - half, y - 1, size, 4, fill);
  out += r(x - half + 2, y - 3, Math.max(2, size - 4), 7, fill);
  out += r(x - half + 2, y - 2, Math.max(2, size - 6), 2, light);
  out += r(x, y - 2, 2, 5, P.cream);
  return out;
}

function foliage(x, y, w, h, base = P.leaf, light = P.lime, highlight = P.turquoise, seed = 1) {
  let out = blob(x, y, w, h, P.ink);
  out += blob(x + 2, y + 2, w - 4, h - 4, base);
  const random = rng(seed);
  const clusters = Math.max(5, Math.floor(w * h / 70));
  for (let i = 0; i < clusters; i += 1) {
    const cx = x + 4 + Math.floor(random() * Math.max(1, (w - 10) / 2)) * 2;
    const cy = y + 4 + Math.floor(random() * Math.max(1, (h - 10) / 2)) * 2;
    const color = i % 4 === 0 ? highlight : i % 2 === 0 ? light : base;
    out += r(cx, cy, 4 + Math.floor(random() * 3) * 2, 2 + Math.floor(random() * 2) * 2, color);
  }
  out += r(x + 6, y + 3, Math.max(4, w - 18), 2, light);
  return out;
}

function blossom(x, y, petal = P.rose, light = P.roseLight, size = 8) {
  const half = Math.floor(size / 2);
  let out = r(x - half - 1, y - 2, size + 2, 5, P.ink);
  out += r(x - 2, y - half - 1, 5, size + 2, P.ink);
  out += r(x - half, y - 1, size, 4, petal);
  out += r(x - 1, y - half, 4, size, petal);
  out += r(x - half + 1, y - 2, size - 2, 2, light);
  out += r(x, y - half + 1, 2, size - 2, light);
  out += r(x - 1, y - 1, 3, 3, P.gold);
  return out;
}

function seedling(seed) {
  return soilBaseline(seed) + r(29, 48, 7, 4, P.brick) + r(30, 48, 3, 2, P.cream) +
    r(32, 54, 2, 6, P.forest);
}

function sprout(seed) {
  return soilBaseline(seed) + stem(32, 54, 43, P.forest, 3) +
    detailLeaf(27, 44, 9, P.leaf, P.lime) + detailLeaf(37, 41, 10, P.lime, P.cream);
}

function cypress(stage) {
  if (stage === 0) return seedling(201);
  if (stage === 1) return sprout(201);
  let out = soilBaseline(201) + r(30, 30, 4, 26, P.soil);
  const heights = [24, 34, 42, 48];
  const height = heights[stage - 2];
  const top = 54 - height;
  for (let y = top; y < 52; y += 6) {
    const spread = Math.min(18, Math.floor((y - top) / 3) + 4);
    out += p(`M32 ${y - 2}H${32 + spread}V${y + 2}H${32 + spread + 2}V${y + 6}H${32 - spread - 2}V${y + 2}H${32 - spread}Z`, P.ink);
    out += p(`M32 ${y}H${32 + spread - 2}V${y + 2}H${32 + spread}V${y + 4}H${32 - spread}V${y + 2}H${32 - spread + 2}Z`, P.forest);
    out += r(32 - spread + 3, y + 1, Math.max(4, spread), 2, P.leaf);
    out += r(30, y, 3, 2, P.lime);
  }
  if (stage === 5) {
    out += r(29, top + 12, 3, 5, P.gold) + r(35, top + 21, 3, 5, P.barkLight);
    out += r(31, top + 2, 3, 3, P.turquoise);
  }
  return out;
}

function oak(stage) {
  if (stage === 0) return seedling(202);
  if (stage === 1) return sprout(202);
  const scale = stage === 2 ? 0.56 : stage === 3 ? 0.76 : stage === 4 ? 0.9 : 1;
  const trunkTop = Math.round(52 - 28 * scale);
  let out = soilBaseline(202);
  out += r(29, trunkTop, 6, 54 - trunkTop, P.ink) + r(31, trunkTop + 2, 2, 52 - trunkTop, P.soil);
  out += branch(32, trunkTop + 13, 23, trunkTop + 2, P.soil, 4);
  out += branch(32, trunkTop + 16, 42, trunkTop + 4, P.soil, 4);
  const cy = Math.round(40 - 26 * scale);
  const w = Math.round(42 * scale);
  const h = Math.round(30 * scale);
  const x = 32 - Math.round(w / 2);
  out += foliage(x, cy, w, h, P.leaf, P.lime, P.turquoise, 202);
  out += foliage(x - 3, cy + 5, Math.round(w * 0.55), Math.round(h * 0.68), P.forest, P.leaf, P.lime, 220);
  out += foliage(x + Math.round(w * 0.48), cy + 4, Math.round(w * 0.52), Math.round(h * 0.7), P.leaf, P.lime, P.turquoise, 221);
  if (stage === 5) {
    out += r(19, cy + 16, 5, 7, P.ink) + r(20, cy + 17, 3, 5, P.bark) + r(19, cy + 15, 5, 3, P.soil);
    out += r(41, cy + 19, 5, 7, P.ink) + r(42, cy + 20, 3, 5, P.bark) + r(41, cy + 18, 5, 3, P.soil);
  }
  return out;
}

function pomegranate(stage) {
  if (stage === 0) return seedling(203);
  if (stage === 1) return sprout(203);
  const top = stage === 2 ? 30 : stage === 3 ? 22 : 14;
  let out = soilBaseline(203);
  out += r(30, top + 7, 4, 47 - top, P.ink) + r(31, top + 8, 2, 45 - top, P.soil);
  out += branch(32, top + 17, 21, top + 5, P.soil, 4);
  out += branch(32, top + 20, 43, top + 7, P.soil, 4);
  const cy = top + 1;
  out += foliage(10, cy + 4, 23, 19, P.leaf, P.lime, P.turquoise, 231);
  out += foliage(31, cy, 23, 21, P.leaf, P.lime, P.turquoise, 232);
  out += foliage(20, cy + 15, 24, 17, P.forest, P.leaf, P.lime, 233);
  out += detailLeaf(14, cy + 13, 9, P.leaf, P.lime) + detailLeaf(40, cy + 15, 9, P.lime, P.cream);
  if (stage >= 4) out += blossom(21, cy + 7, P.rose, P.roseLight, 7) + blossom(42, cy + 10, P.roseLight, P.cream, 6);
  if (stage === 5) {
    out += r(17, cy + 20, 11, 12, P.ink) + r(19, cy + 21, 7, 10, P.fruit);
    out += r(20, cy + 21, 3, 3, P.fruitLight) + r(21, cy + 18, 4, 3, P.bark);
    out += r(38, cy + 23, 10, 11, P.ink) + r(40, cy + 24, 6, 9, P.fruit);
    out += r(41, cy + 24, 2, 3, P.fruitLight) + r(42, cy + 21, 4, 3, P.bark);
  }
  return out;
}

function arghavan(stage) {
  if (stage === 0) return seedling(204);
  if (stage === 1) return sprout(204);
  const scale = stage === 2 ? 0.56 : stage === 3 ? 0.76 : stage === 4 ? 0.9 : 1;
  const top = Math.round(50 - 30 * scale);
  let out = soilBaseline(204);
  out += r(29, top + 8, 6, 46 - top, P.ink) + r(31, top + 9, 2, 44 - top, P.soil);
  out += branch(32, top + 18, 20, top + 6, P.soil, 4);
  out += branch(32, top + 21, 45, top + 8, P.soil, 4);
  const cy = Math.round(35 - 23 * scale);
  const w = Math.round(40 * scale);
  const x = 32 - Math.round(w / 2);
  out += foliage(x, cy, w, Math.round(25 * scale), P.leaf, P.lime, P.turquoise, 204);
  out += foliage(x + 3, cy + 8, Math.round(w * 0.7), Math.round(18 * scale), P.forest, P.leaf, P.lime, 205);
  out += detailLeaf(18, cy + 10, 8, P.lime, P.cream) + detailLeaf(42, cy + 6, 8, P.leaf, P.cream);
  if (stage >= 4) {
    out += blossom(20, top + 8, P.roseDark, P.rose, 6);
    out += blossom(43, top + 11, P.rose, P.roseLight, 6);
    out += blossom(31, top + 3, P.roseLight, P.cream, 5);
  }
  if (stage === 5) {
    out += r(20, top + 17, 3, 8, P.bark) + r(42, top + 19, 3, 7, P.bark);
    out += r(19, top + 23, 5, 3, P.soil) + r(41, top + 24, 5, 3, P.soil);
  }
  return out;
}

function olive(stage) {
  if (stage === 0) return seedling(205);
  if (stage === 1) return sprout(205);
  const scale = stage === 2 ? 0.56 : stage === 3 ? 0.76 : stage === 4 ? 0.9 : 1;
  const top = Math.round(48 - 28 * scale);
  let out = soilBaseline(205);
  out += r(29, top + 9, 6, 45 - top, P.ink) + r(31, top + 10, 2, 43 - top, P.soil);
  out += branch(32, top + 18, 19, top + 7, P.soil, 4);
  out += branch(32, top + 22, 45, top + 10, P.soil, 4);
  const cy = Math.round(32 - 20 * scale);
  const w = Math.round(38 * scale);
  const x = 32 - Math.round(w / 2);
  out += foliage(x, cy, w, Math.round(26 * scale), P.leaf, P.cream, P.lime, 206);
  out += foliage(x + 5, cy + 7, Math.round(w * 0.72), Math.round(18 * scale), P.forest, P.leaf, P.cream, 207);
  for (let i = 0; i < 6; i += 1) {
    out += detailLeaf(14 + i * 6, cy + 4 + (i % 2) * 5, 7, i % 2 ? P.cream : P.lime, P.cream);
  }
  if (stage === 5) {
    out += r(18, cy + 13, 4, 5, P.ink) + r(19, cy + 14, 2, 3, P.forest);
    out += r(41, cy + 10, 4, 5, P.ink) + r(42, cy + 11, 2, 3, P.forest);
    out += r(28, cy + 18, 4, 5, P.ink) + r(29, cy + 19, 2, 3, P.forest);
  }
  return out;
}

function willow(stage) {
  if (stage === 0) return seedling(206);
  if (stage === 1) return sprout(206);
  const top = stage === 2 ? 30 : stage === 3 ? 20 : 9;
  let out = soilBaseline(206);
  out += r(28, top + 12, 7, 42 - top, P.ink) + r(30, top + 13, 3, 40 - top, P.soil);
  out += branch(31, top + 19, 19, top + 8, P.soil, 4);
  out += branch(32, top + 21, 45, top + 9, P.soil, 4);
  out += foliage(10, top, 44, 19, P.leaf, P.lime, P.turquoise, 241);
  out += foliage(19, top - 4, 27, 17, P.leaf, P.lime, P.cream, 242);
  const strands = stage === 2 ? 4 : stage === 3 ? 6 : 8;
  for (let i = 0; i < strands; i += 1) {
    const x = 12 + i * 5;
    const length = 10 + ((i * 7) % 12);
    out += r(x, top + 13, 2, length, i % 2 ? P.forest : P.leaf);
    out += r(x + 1, top + 15, 1, Math.max(4, length - 4), P.lime);
    out += detailLeaf(x, top + 14 + length, 6, P.lime, P.cream);
  }
  if (stage === 5) {
    out += r(18, top + 5, 4, 3, P.gold) + r(38, top + 3, 4, 3, P.barkLight);
  }
  return out;
}

function buildPlants() {
  const draws = [cypress, oak, pomegranate, arghavan, olive, willow];
  let body = '';
  for (let row = 0; row < 6; row += 1) {
    for (let col = 0; col < 6; col += 1) {
      body += g(draws[row](col), col * 64, row * 64, ` data-cell="${row},${col}"`) + '\n';
    }
  }
  return { name: 'plants.svg', width: 512, height: 384, usedCells: 36, source: svg(512, 384, body.trimEnd()) };
}
function propShadow() {
  return r(16, 56, 32, 4, P.ink, ' opacity="0.20"');
}

function drawBench() {
  let out = propShadow();
  out += r(10, 26, 44, 12, P.ink) + r(14, 28, 36, 8, P.brick);
  out += r(14, 28, 28, 3, P.cream);
  out += r(8, 40, 48, 10, P.ink) + r(12, 42, 40, 6, P.brick);
  out += r(12, 42, 32, 2, P.cream);
  out += r(12, 48, 4, 10, P.ink) + r(48, 48, 4, 10, P.ink);
  return out;
}

function drawFountain() {
  let out = propShadow();
  out += r(12, 26, 40, 30, P.ink) + r(16, 22, 32, 38, P.ink);
  out += r(20, 26, 24, 30, P.cream) + r(20, 30, 24, 22, P.water);
  out += r(16, 26, 32, 4, P.cream) + r(28, 14, 8, 16, P.ink);
  out += r(30, 12, 4, 16, P.turquoise) + r(28, 10, 8, 4, P.sky);
  out += r(24, 34, 8, 2, P.sky) + r(34, 40, 6, 2, P.sky);
  return out;
}

function recycleMark(x, y, scale = 1, color = P.cream) {
  const arrow = p('M11 1h6v4h4v5h-4v-2H9v5H5V6h4V4h2z', color);
  return `<g transform="translate(${x} ${y}) scale(${scale})">` +
    arrow +
    `<g transform="rotate(120 12 12)">${arrow}</g>` +
    `<g transform="rotate(240 12 12)">${arrow}</g>` +
    '</g>';
}

function propArt(row, col) {
  if (row === 0) {
    switch (col) {
      case 0:
        return propShadow() + r(20, 28, 24, 22, P.ink) + r(22, 30, 20, 18, P.turquoise) +
          r(26, 32, 12, 6, P.sky) + p('M42 34h8v4h6v10h-4v4h-8', 'none', ` ${stroke(P.ink, 6)}`) +
          p('M42 36h8v4h6v8h-4', 'none', ` ${stroke(P.turquoise, 2)}`) +
          p('M22 32h-4v14h4', 'none', ` ${stroke(P.ink, 4)}`) + r(58, 50, 2, 6, P.water);
      case 1:
        return propShadow() + r(28, 8, 8, 32, P.ink) + r(30, 10, 4, 28, P.brick) +
          r(24, 4, 16, 8, P.ink) + r(26, 6, 12, 4, P.brick) +
          p('M26 38h12v4h4v12h-4v4H22v-4h-4V42h4v-4z', P.ink) +
          p('M28 40h8v4h4v8h-4v2H24v-2h-4v-8h4v-4z', P.cream) + r(28, 42, 4, 8, P.sky);
      case 2:
        return propShadow() + r(14, 28, 14, 22, P.ink) + r(16, 30, 10, 18, P.brick) +
          r(10, 22, 10, 16, P.ink) + r(12, 24, 6, 12, P.brick) +
          r(36, 28, 14, 22, P.ink) + r(38, 30, 10, 18, P.brick) +
          r(40, 22, 10, 16, P.ink) + r(42, 24, 6, 12, P.brick) +
          r(16, 48, 10, 6, P.cream) + r(38, 48, 10, 6, P.cream);
      case 3:
        return propShadow() + p('M22 14h20v4h4v6h4v28H14V24h4v-6h4v-4z', P.ink) +
          p('M24 18h16v4h4v6h4v20H18V28h4v-6h2v-4z', P.cream) +
          r(24, 18, 16, 4, P.brick) + leaf(32, 34, 14, P.leaf, true) + r(32, 40, 2, 10, P.forest);
      case 4:
        return propShadow() + p('M22 14h20v4h4v6h4v28H14V24h4v-6h4v-4z', P.ink) +
          p('M24 18h16v4h4v6h4v20H18V28h4v-6h2v-4z', P.soil) +
          r(24, 18, 16, 4, P.cream) + r(22, 32, 20, 12, P.brick) + r(26, 28, 12, 4, P.ink);
      case 5:
        return propShadow() + r(12, 18, 40, 32, P.ink) + r(16, 22, 32, 24, P.cream) +
          r(20, 26, 24, 16, P.forest) + leaf(30, 32, 12, P.lime, true) + r(30, 38, 2, 4, P.leaf) +
          r(18, 46, 4, 8, P.ink) + r(42, 46, 4, 8, P.ink);
      case 6:
        return propShadow() + p('M24 20h16v4h4v8h4v24H16V32h4v-8h4v-4z', P.ink) +
          p('M26 24h12v4h4v8h4v16H20V36h4v-8h2v-4z', P.forest) +
          r(28, 18, 8, 8, P.lime) + r(24, 26, 16, 4, P.leaf) + r(26, 34, 4, 4, P.turquoise);
      default:
        return propShadow() + p('M32 8h8v6h6v8h6v8h6v18H8V30h6v-8h6v-8h6V8h6z', P.ink) +
          p('M32 14h6v6h6v8h6v12H16V28h6v-8h6v-6h4z', P.turquoise) +
          r(26, 24, 8, 8, P.sky) + r(20, 18, 4, 8, P.cream);
    }
  }
  if (row === 1) {
    switch (col) {
      case 0:
        return propShadow() + r(28, 28, 10, 22, P.ink) + r(30, 30, 6, 18, P.soil) +
          leaf(26, 26, 18, P.leaf, true) + leaf(38, 22, 14, P.lime, true) + r(30, 48, 6, 4, P.brick);
      case 1:
        return propShadow() + p('M32 8h8v8h8v8h8v16h-8v8h-8v8h-8v-8h-8v-8h-8V24h8v-8h8V8z', P.ink) +
          p('M32 14h6v8h8v8h6v12h-6v8h-8v6h-6v-6h-8v-8h-6V30h6v-8h8v-8z', P.turquoise) +
          p('M32 22h4v6h6v6h-6v6h-4v-6h-6v-6h6z', P.sky);
      case 2:
        return propShadow() + p('M12 44h8v-8h8v-6h8v-6h12v8h8v6h6v10H12z', P.ink) +
          p('M16 42h8v-6h8v-6h8v-6h8v6h8v6h6v6H16z', P.soil) +
          r(20, 34, 6, 4, P.lime) + r(34, 26, 6, 4, P.cream) + r(44, 36, 4, 4, P.brick);
      case 3:
        return propShadow() + p('M14 20h12v4h8v-8h12v8h8v24H14V20z', P.ink) +
          p('M18 24h8v4h16v-4h8v16H18V24z', P.leaf) + p('M30 26h4v16', 'none', ` ${stroke(P.lime, 2)}`) +
          p('M30 30h-8M34 36h8', 'none', ` ${stroke(P.lime, 2)}`);
      case 4:
        return propShadow() + p('M32 6h6v8h8v6h6v8h6v18h-6v6H14v-6H8V28h6v-8h6v-6h8V6h4z', P.ink) +
          p('M32 14h4v8h8v6h4v8h4v10H18V36h4v-8h4v-6h6z', P.cream) +
          p('M32 20h4v8h8v8h-8v8h-4v-8h-8v-8h8z', P.lime);
      case 5:
        return propShadow() + p('M16 16h12V8h12v8h12v10h-8v8h-6v18H24V34h-6v-8H8V16h8z', P.ink) +
          p('M20 20h8v-8h10v8h8v4h-6v8h-6v16H26V32h-6v-8h-6v-4z', P.brick) +
          r(26, 20, 6, 4, P.cream);
      case 6:
        return propShadow() + r(14, 16, 38, 34, P.ink) + r(18, 12, 30, 38, P.ink) +
          r(20, 16, 26, 28, P.cream) + r(22, 18, 22, 24, P.brick) + r(28, 18, 4, 24, P.cream) +
          r(18, 46, 30, 4, P.ink);
      default:
        return propShadow() + r(16, 16, 32, 32, P.ink) + r(20, 20, 24, 24, P.turquoise) + recycleMark(20, 20, 1, P.cream);
    }
  }
  if (row === 2) {
    switch (col) {
      case 0: return drawBench();
      case 1:
        return propShadow() + r(28, 18, 8, 40, P.ink) + r(30, 20, 4, 36, P.forest) +
          r(18, 54, 28, 4, P.ink) + r(22, 50, 20, 4, P.forest) +
          r(18, 10, 28, 16, P.ink) + r(22, 14, 20, 8, P.cream) +
          r(20, 8, 24, 6, P.ink) + r(24, 10, 16, 4, P.forest) + r(32, 22, 2, 6, P.brick);
      case 2:
        return propShadow() + r(26, 26, 12, 30, P.ink) + r(28, 28, 8, 26, P.cream) +
          r(10, 20, 44, 12, P.ink) + r(14, 24, 36, 6, P.turquoise) +
          r(18, 30, 28, 4, P.sky) + r(28, 16, 8, 8, P.ink) + r(30, 14, 4, 8, P.water);
      case 3:
        return propShadow() + r(10, 40, 42, 10, P.ink) + r(14, 42, 34, 6, P.brick) +
          r(16, 48, 4, 8, P.ink) + r(44, 48, 4, 8, P.ink) + r(48, 54, 10, 4, P.ink) +
          r(18, 28, 24, 14, P.ink) + r(22, 30, 18, 10, P.soil) +
          p('M48 34h8v4h-8', 'none', ` ${stroke(P.ink, 4)}`);
      case 4:
        return propShadow() + r(30, 26, 4, 32, P.ink) + r(22, 12, 32, 20, P.ink) +
          p('M26 16h26l-4 12H22l4-12z', P.cream) + r(36, 18, 4, 8, P.soil) +
          r(32, 16, 12, 4, P.leaf) + r(30, 18, 4, 4, P.leaf) + r(42, 18, 4, 4, P.lime);
      case 5: return drawFountain();
      case 6:
        return propShadow() + r(12, 28, 40, 26, P.ink) + r(16, 32, 32, 18, P.brick) +
          r(12, 24, 40, 8, P.turquoise) + r(16, 26, 32, 4, P.sky) + r(20, 36, 24, 10, P.soil) +
          leaf(28, 36, 12, P.leaf, true) + leaf(38, 40, 10, P.lime, true);
      default:
        return propShadow() + p('M10 42h44v14H10z', P.ink) + p('M14 46h36v6H14z', P.cream) +
          p('M16 18h32v28H16z', P.ink) + p('M20 14h24v28H20z', P.sky) +
          p('M32 14v28M20 28h24', 'none', ` ${stroke(P.cream, 2)}`) +
          leaf(26, 38, 10, P.leaf, true) + leaf(38, 40, 10, P.lime, true);
    }
  }
  switch (col) {
    case 0:
      return r(22, 8, 20, 4, P.ink) + r(18, 12, 28, 20, P.ink) + r(22, 16, 20, 12, P.cream) +
        r(14, 24, 36, 8, P.cream) + r(18, 32, 28, 4, P.sky) +
        r(10, 18, 4, 4, P.lime) + r(50, 14, 4, 4, P.lime) + r(8, 24, 4, 4, P.lime) + r(52, 22, 4, 4, P.lime);
    case 1:
      return blob(16, 20, 30, 18, P.ink) + blob(26, 14, 22, 18, P.ink) + blob(38, 22, 16, 14, P.ink) +
        blob(20, 22, 22, 12, P.sky) + blob(30, 16, 14, 12, P.cream) + r(20, 38, 28, 4, P.turquoise) +
        r(22, 46, 2, 10, P.water) + r(34, 44, 2, 12, P.water) + r(44, 48, 2, 8, P.water);
    case 2:
      return r(26, 8, 12, 12, P.ink) + r(30, 10, 4, 8, P.cream) +
        r(20, 20, 4, 8, P.lime) + r(40, 20, 4, 8, P.lime) + r(16, 28, 4, 8, P.lime) + r(44, 28, 4, 8, P.lime) +
        r(12, 36, 4, 8, P.lime) + r(48, 36, 4, 8, P.lime) + r(24, 42, 4, 8, P.lime) + r(36, 42, 4, 8, P.lime);
    case 3:
      return p('M32 8h6v10h10v6h6v10h6v16h-6v6H14v-6H8V34h6V24h6v-6h12z', P.ink) +
        p('M32 16h4v10h10v6h4v10h4v8H18v-8h4V32h4v-6h6z', P.cream) +
        r(28, 24, 8, 16, P.lime) + r(24, 28, 16, 8, P.lime);
    case 4:
      return r(28, 18, 8, 30, P.ink) + r(22, 12, 10, 20, P.ink) + r(42, 20, 10, 18, P.ink) +
        r(30, 20, 4, 24, P.brick) + r(24, 16, 6, 12, P.brick) + r(44, 24, 6, 10, P.turquoise) +
        r(26, 12, 4, 4, P.cream) + r(46, 20, 4, 4, P.cream);
    case 5:
      return r(28, 24, 8, 26, P.ink) + r(30, 26, 4, 22, P.soil) +
        r(20, 20, 8, 12, P.ink) + r(36, 20, 8, 12, P.ink) + r(22, 22, 4, 8, P.lime) + r(38, 22, 4, 8, P.lime) +
        r(26, 14, 12, 10, P.lime, ' opacity="0.30"') + r(30, 18, 4, 4, P.cream);
    case 6:
      return p('M12 18h14v-6h12v6h14v10h-4v22H16V28h-4z', P.ink) +
        p('M16 22h10v-4h12v4h10v6h-4v16H20V28h-4z', P.leaf) + p('M32 22v18', 'none', ` ${stroke(P.lime, 2)}`);
    default:
      return r(12, 20, 40, 8, P.turquoise, ' opacity="0.45"') + r(16, 28, 32, 6, P.sky, ' opacity="0.55"') +
        r(20, 36, 24, 6, P.turquoise, ' opacity="0.40"') + r(26, 44, 14, 4, P.sky, ' opacity="0.35"');
  }
}

function buildProps() {
  let body = '';
  for (let row = 0; row < 4; row += 1) {
    for (let col = 0; col < 8; col += 1) {
      body += g(propArt(row, col), col * 64, row * 64, ` data-cell="${row},${col}"`) + '\n';
    }
  }
  return { name: 'props.svg', width: 512, height: 256, usedCells: 32, source: svg(512, 256, body.trimEnd()) };
}

function iconOutlinedRect(x, y, width, height, fill, radius = 4) {
  return roundedRect(x, y, width, height, radius, P.ink) +
    roundedRect(x + 2, y + 2, width - 4, height - 4, Math.max(2, radius - 2), fill);
}

function iconOutlinedBlob(x, y, width, height, fill) {
  return blob(x, y, width, height, P.ink) + blob(x + 2, y + 2, width - 4, height - 4, fill);
}

function iconLeaf(x = 0, y = 0) {
  const body = p('M3 27h5v-4h4v-4h4v-4h4v-4h4V7h5V2h4v10h-4v4h-4v4h-4v4h-4v4H3z', P.ink) +
    p('M7 25h4v-4h4v-4h4v-4h4v-4h4V9h3V6h2v6h-4v4h-4v4h-4v4h-4v4H7z', P.leaf) +
    r(8, 24, 4, 2, P.lime) + r(12, 20, 4, 2, P.lime) + r(16, 16, 4, 2, P.lime) + r(20, 12, 4, 2, P.lime);
  return g(body, x, y);
}

function iconHeart() {
  return p('M4 4h8v4h8V4h8v4h4v10h-4v4h-4v4h-4v2h-8v-2H8v-4H4v-4H0V8h4z', P.ink) +
    p('M6 8h6v4h8V8h6v4h2v6h-4v4h-4v4h-4v2h-4v-2h-4v-4H8v-4H4v-6h2z', P.rose) +
    r(6, 10, 4, 4, P.roseLight);
}

function iconBook() {
  return iconOutlinedRect(2, 5, 28, 24, P.cream, 4) + r(4, 22, 24, 4, P.brick) +
    r(14, 7, 4, 16, P.bark) + r(6, 10, 6, 2, P.forest) + r(6, 16, 6, 2, P.forest) +
    r(20, 10, 6, 2, P.forest) + r(20, 16, 6, 2, P.forest) + r(22, 7, 4, 8, P.leaf);
}

function iconStar() {
  return p('M14 0h4v8h6v-4h4v8h8v4h-8v6h4v4h-8v-4h-6v8h-4v-8H8v4H4v-4h4v-6H0v-4h8V4h4V0z', P.ink) +
    p('M14 4h4v6h6v-2h2v6h6v2h-6v4h2v2h-6v-2h-6v6h-4v-6H8v2H6v-2h2v-4H2v-2h6V8h2V6h4z', P.gold) +
    r(14, 8, 4, 4, P.cream);
}

function iconWater() {
  return p('M14 0h4v6h4v6h4v6h4v6h-4v4H4v-4H0v-6h4v-6h4V6h4V0h2z', P.ink) +
    p('M14 6h4v6h4v6h4v4h-4v4H6v-4H4v-4h4v-6h4V6h2z', P.turquoise) +
    r(8, 18, 4, 6, P.sky);
}

function iconSoil() {
  return iconOutlinedRect(2, 9, 28, 21, P.soil, 4) + r(4, 7, 24, 6, P.leaf) + r(6, 5, 20, 4, P.lime) +
    r(6, 16, 6, 4, P.brick) + r(18, 20, 6, 4, P.cream) + r(12, 12, 4, 4, P.barkLight);
}

function iconSun() {
  let out = r(14, 0, 4, 6, P.gold) + r(14, 26, 4, 6, P.gold) + r(0, 14, 6, 4, P.gold) + r(26, 14, 6, 4, P.gold);
  out += r(4, 4, 4, 4, P.brick) + r(24, 4, 4, 4, P.brick) + r(4, 24, 4, 4, P.brick) + r(24, 24, 4, 4, P.brick);
  out += iconOutlinedBlob(6, 6, 20, 20, P.gold) + r(10, 10, 6, 4, P.cream);
  return out;
}

function iconSeed() {
  return p('M14 3h4v4h4v6h4v6h-4v6h-6v2H8v-2H4V15h4V9h6z', P.ink) +
    p('M14 7h4v4h4v6h2v4h-4v4h-4v2H9v-2H7v-8h3V9h4z', P.soil) +
    r(12, 10, 4, 12, P.cream) + r(14, 8, 4, 4, P.leaf);
}

function iconGear() {
  let out = r(12, 0, 8, 6, P.ink) + r(12, 26, 8, 6, P.ink) + r(0, 12, 6, 8, P.ink) + r(26, 12, 6, 8, P.ink);
  out += p('M4 4h6v4H6v2H4zM22 4h6v6h-2V8h-4zM4 22h2v2h2v4H4zM22 24h4v4h-2v-2h-2z', P.ink);
  out += iconOutlinedBlob(6, 6, 20, 20, P.turquoise) + iconOutlinedBlob(12, 12, 8, 8, P.cream);
  return out;
}

function iconSound(muted = false) {
  let out = p('M2 12h8l8-6v20l-8-6H2z', P.ink) + p('M4 14h6l6-4v12l-6-4H4z', P.turquoise);
  if (!muted) {
    out += p('M20 10h4v2h4v4h-2v4h-4v2h-2', 'none', ` ${stroke(P.cream, 2)}`);
    out += p('M26 6h2v4h2v4h-2v4h-2', 'none', ` ${stroke(P.cream, 2)}`);
  } else {
    out += p('M20 10l10 12M30 10L20 22', 'none', ` ${stroke(P.brick, 3)}`);
  }
  return out;
}

function iconMusic() {
  return r(10, 3, 4, 19, P.ink) + r(22, 7, 4, 15, P.ink) + r(12, 3, 12, 4, P.ink) + r(20, 7, 8, 4, P.ink) +
    r(12, 5, 2, 15, P.turquoise) + r(24, 9, 2, 11, P.turquoise) + r(14, 5, 8, 2, P.turquoise) +
    r(4, 20, 12, 7, P.ink) + r(16, 16, 12, 7, P.ink) + r(6, 20, 8, 5, P.brick) + r(18, 16, 8, 5, P.brick);
}

function iconPause() {
  return iconOutlinedRect(5, 3, 8, 26, P.cream, 3) + iconOutlinedRect(19, 3, 8, 26, P.cream, 3);
}

function iconPlay() {
  return p('M7 2h7v4h6v4h6v4h6v4h-6v4h-6v4h-6v4H7z', P.ink) +
    p('M11 8h4v4h6v4h6v-4h4v4h-6v4h-6v4h-6z', P.leaf);
}

function iconBack() {
  return p('M14 2h6v6h10v6h4v4h-4v6H20v6h-6V22H2v-6h12z', P.ink) +
    p('M14 8h4v6h10v4H18v6h-4V18H6v-4h8z', P.cream);
}

function iconClose() {
  return p('M5 5l22 22M27 5L5 27', 'none', ` ${stroke(P.ink, 7)}`) +
    p('M7 7l18 18M25 7L7 25', 'none', ` ${stroke(P.brick, 3)}`);
}

function iconCheck() {
  return p('M3 16l6 6L29 2', 'none', ` ${stroke(P.ink, 7)}`) +
    p('M5 17l5 5L27 5', 'none', ` ${stroke(P.lime, 3)}`);
}

function iconQuest() {
  return iconOutlinedRect(4, 4, 24, 26, P.cream, 4) + r(10, 2, 12, 6, P.ink) + r(12, 4, 8, 2, P.gold) +
    r(8, 11, 16, 2, P.bark) + r(8, 16, 12, 2, P.bark) +
    p('M8 23l4 4L24 15', 'none', ` ${stroke(P.leaf, 4)}`);
}

function iconMap() {
  return p('M2 5h10v4h8V5h10v23H20v-4h-8v4H2z', P.ink) + p('M5 8h7v4h8V8h7v17h-7v-4h-8v4H5z', P.cream) +
    r(13, 8, 2, 18, P.bark) + r(19, 8, 2, 18, P.bark) +
    p('M7 21h4v-4h4', 'none', ` ${stroke(P.turquoise, 3)}`) + r(17, 13, 4, 4, P.leaf);
}

function iconMemorial() {
  return iconOutlinedRect(8, 2, 16, 26, P.cream, 6) + r(11, 6, 10, 14, P.leaf) +
    p('M13 18h6v-4h-2v-2h-2v2h-2z', P.lime) + r(12, 22, 8, 2, P.gold) +
    r(5, 27, 22, 4, P.ink) + r(8, 27, 16, 2, P.bark);
}

function iconMedal() {
  return p('M8 0h6v12h4V0h6v16h-6v4h-4v-4H8z', P.ink) + p('M10 2h4v14h4V2h4v12h-4v4h-4v-4h-4z', P.brick) +
    iconOutlinedBlob(6, 14, 20, 18, P.gold) + p('M16 17h2v3h3v2h-3v3h-2v-3h-3v-2h3z', P.cream);
}

function iconLock() {
  return p('M10 1h12v4h4v11h-4v-7H10v7H6V5h4z', P.ink) + p('M12 4h8v3h3v6h-3V7h-8v6H9V7h3z', P.cream) +
    iconOutlinedRect(4, 12, 24, 18, P.turquoise, 4) + r(14, 17, 4, 7, P.cream) + r(12, 22, 8, 3, P.cream);
}

function iconInfo() {
  return iconOutlinedBlob(2, 2, 28, 28, P.turquoise) + r(14, 7, 4, 5, P.cream) +
    r(14, 15, 4, 9, P.cream) + r(12, 25, 8, 3, P.cream);
}

function iconHome() {
  return p('M2 14h6V8h6V2h4v6h6v6h6v4H2z', P.ink) + p('M6 12h4V9h6V5h2v4h6v3h4v2H6z', P.brick) +
    iconOutlinedRect(4, 16, 24, 14, P.cream, 2) + r(13, 19, 7, 11, P.leaf) + r(18, 24, 2, 2, P.gold);
}

function iconChapter() {
  return iconOutlinedRect(4, 2, 24, 28, P.cream, 4) + r(8, 2, 16, 6, P.leaf) +
    r(11, 12, 10, 12, P.gold) + r(15, 10, 2, 14, P.cream) + r(8, 25, 16, 2, P.bark);
}

function iconJoystick() {
  return iconOutlinedBlob(3, 9, 26, 22, P.turquoise) + r(14, 4, 4, 13, P.ink) + r(15, 5, 2, 10, P.cream) +
    iconOutlinedBlob(10, 2, 12, 12, P.forest) + r(12, 4, 8, 6, P.cream);
}

function iconAction() {
  return iconOutlinedBlob(2, 2, 28, 28, P.turquoise) + r(14, 7, 4, 18, P.cream) + r(7, 14, 18, 4, P.cream);
}

function iconMenu() {
  return r(3, 6, 26, 5, P.ink) + r(3, 14, 26, 5, P.ink) + r(3, 22, 26, 5, P.ink) +
    r(6, 7, 20, 3, P.cream) + r(6, 15, 20, 3, P.cream) + r(6, 23, 20, 3, P.cream);
}

function iconCloud() {
  return p('M7 14h5v-4h6V8h6v4h5v5h3v8H4v-6h3z', P.ink) +
    p('M8 16h5v-3h5v-3h5v3h5v4h3v5H7v-4h1z', P.sky) + r(9, 21, 15, 3, P.cream);
}

function iconTrash() {
  return r(9, 2, 14, 4, P.ink) + r(12, 6, 8, 3, P.turquoise) + p('M6 10h20l-2 20H8z', P.ink) +
    p('M9 13h14l-2 14H11z', P.forest) + r(14, 14, 4, 9, P.lime) + r(12, 28, 8, 2, P.ink);
}

function iconTrophy() {
  return p('M8 2h16v12h-4v6h4v6H8v-6h4v-6H8z', P.ink) + p('M11 5h10v9h-3v5h-4v-5h-3z', P.gold) +
    p('M8 6H2v8h6M24 6h6v8h-6', 'none', ` ${stroke(P.ink, 5)}`) +
    p('M8 8H4v4h4M24 8h4v4h-4', 'none', ` ${stroke(P.cream, 2)}`) + r(12, 27, 8, 4, P.ink) + r(14, 27, 4, 2, P.gold);
}

function iconSprout() {
  return `<g transform="scale(0.5)">${pngPixelSvg(loadUserIcon('user_sprout_growth.png'))}</g>`;
}

function iconTeam() {
  return r(3, 6, 11, 12, P.ink) + r(5, 8, 7, 8, P.cream) + r(5, 6, 7, 4, P.brick) +
    r(18, 6, 11, 12, P.ink) + r(20, 8, 7, 8, P.cream) + r(20, 6, 7, 4, P.barkLight) +
    r(1, 20, 15, 11, P.ink) + r(3, 21, 11, 8, P.turquoise) +
    r(16, 20, 15, 11, P.ink) + r(18, 21, 11, 8, P.leaf);
}

function iconRecycle() {
  return p('M4 5h22v7h-4V9H9v3H5z', P.ink) + p('M7 8h16v2H10v3H7z', P.lime) +
    p('M22 13h6v11h-6v-4h2v-5h-4v4h-2v-6h4z', P.ink) + p('M24 16h4v6h-4v-2h2v-2h-4v2h-2v-2h4z', P.turquoise) +
    p('M8 22h16v7H4v-7h4z', P.ink) + p('M10 25h12v2H7v-2h3z', P.cream);
}

const ICON_ROWS = [
  [iconLeaf(), iconHeart(), iconBook(), iconStar(), iconWater(), iconSoil(), iconSun(), iconSeed()],
  [iconGear(), iconSound(), iconMusic(), iconPause(), iconPlay(), iconBack(), iconClose(), iconCheck()],
  [iconQuest(), iconMap(), iconMemorial(), iconMedal(), iconLock(), iconInfo(), iconHome(), iconChapter(), iconTeam()],
  [iconJoystick(), iconAction(), iconMenu(), iconCloud(), iconRecycle(), iconTrash(), iconTrophy(), iconSprout()],
];

function iconArt(row, col) {
  return ICON_ROWS[row]?.[col] ?? '';
}

function buildIcons() {
  let body = '';
  for (let row = 0; row < 4; row += 1) {
    for (let col = 0; col < 16; col += 1) {
      body += g(iconArt(row, col), col * 32, row * 32, ` data-cell="${row},${col}"`) + '\n';
    }
  }
  return { name: 'icons.svg', width: 512, height: 128, usedCells: 64, source: svg(512, 128, body.trimEnd()) };
}

function buildSproutIcon() {
  return { name: 'sprout_icon.svg', width: 64, height: 64, usedCells: 0, source: svg(64, 64, pngPixelSvg(loadUserIcon('user_sprout_growth.png'))) };
}

function logoArt() {
  let out = '';
  out += p('M56 70h8v6h10v6h12v6h8v8h10v8h-8v8h-8v8h-8v4h-16v-4h-8v-8h-8v-8h-8v-8h10v-8h8v-6h12v-6h10v-6h-8v-10h-16z', P.forest);
  out += p('M60 48h8v38h-8z', P.forest);
  out += p('M62 58h4v26h-4z', P.turquoise);
  out += blob(18, 18, 46, 42, P.forest) + blob(64, 18, 46, 42, P.forest);
  out += blob(24, 22, 34, 30, P.leaf) + blob(70, 22, 34, 30, P.leaf);
  out += p('M26 26h10v4h6v8h-6v6H26v-6h-6V30h6z', P.turquoise);
  out += p('M92 24h10v4h6v8h-6v6H92v-6h-6v-8h6z', P.turquoise);
  out += r(28, 28, 10, 4, P.cream) + r(94, 26, 10, 4, P.cream);
  out += p('M30 34v8M96 32v8', 'none', ` ${stroke(P.cream, 2)}`);
  out += p('M58 88h-8v8h-8v8h-8v8M70 88h8v8h8v8h8v8', 'none', ` ${stroke(P.turquoise, 3)}`);
  out += p('M62 88h4v16h-8v8M66 88h4v16h8v8', 'none', ` ${stroke(P.turquoise, 3)}`);
  out += r(62, 118, 4, 4, P.cream);
  return `<g transform="translate(192 -12) scale(2)">${out}</g>`;
}

function buildLogo() {
  return { name: 'logo.svg', width: 640, height: 256, usedCells: 0, source: svg(640, 256, logoArt()) };
}

function androidTreeArt() {
  let out = r(146, 396, 220, 16, P.ink, ' opacity="0.24"');
  out += p('M238 208h36v176h-36z', P.ink);
  out += p('M246 218h14v154h-14z', P.bark);
  out += p('M250 232h6v126h-6z', P.barkLight);
  out += blob(122, 146, 142, 96, P.ink);
  out += blob(132, 156, 122, 76, P.leaf);
  out += blob(146, 166, 82, 48, P.leafLight);
  out += r(152, 174, 54, 8, P.lime) + r(160, 188, 42, 6, P.leafHighlight);
  out += p('M154 184h44v6h-30v6h-14z', P.cream, ' opacity="0.72"');
  out += blob(248, 138, 142, 100, P.ink);
  out += blob(258, 148, 122, 80, P.leaf);
  out += blob(272, 160, 88, 50, P.leafLight);
  out += r(306, 166, 48, 8, P.lime) + r(298, 180, 40, 6, P.leafHighlight);
  out += p('M276 176h44v6h-28v6h-16z', P.cream, ' opacity="0.72"');
  out += p('M244 344h-38v22h-30v22h-22v22M268 344h38v22h30v22h22v22', 'none', ` ${stroke(P.gold, 12)}`);
  out += p('M244 344h-20v34h-24v24M268 344h20v34h24v24', 'none', ` ${stroke(P.barkLight, 7)}`);
  out += roundedRect(146, 356, 220, 58, 18, P.ink);
  out += roundedRect(154, 364, 204, 42, 12, P.soil);
  out += r(162, 370, 188, 8, P.bark);
  out += r(174, 386, 18, 8, P.barkLight) + r(214, 394, 22, 6, P.ink) + r(274, 384, 16, 8, P.barkLight) + r(320, 396, 20, 6, P.ink);
  return out;
}

function androidBackgroundArt() {
  let out = `<defs><radialGradient id="android_ember" cx="50%" cy="36%" r="72%">` +
    `<stop offset="0" stop-color="${P.gold}"/><stop offset="0.46" stop-color="${P.brick}"/>` +
    `<stop offset="1" stop-color="${P.soil}"/></radialGradient></defs>`;
  out += r(0, 0, 512, 512, P.brick);
  out += roundedRect(26, 26, 460, 460, 104, `url(#android_ember)`);
  out += roundedRect(138, 92, 236, 236, 92, P.gold, ' opacity="0.34"');
  out += roundedRect(158, 112, 196, 196, 76, P.cream, ' opacity="0.12"');
  out += r(246, 58, 20, 54, P.cream, ' opacity="0.16"') + r(246, 402, 20, 54, P.cream, ' opacity="0.12"');
  out += r(82, 246, 54, 20, P.cream, ' opacity="0.14"') + r(376, 246, 54, 20, P.cream, ' opacity="0.14"');
  out += r(72, 392, 368, 64, P.soil, ' opacity="0.82"');
  return out;
}

function androidForegroundArt() {
  return `<g transform="translate(56 42) scale(0.78)">${androidTreeArt()}</g>`;
}

function androidMonochromeArt() {
  let out = p('M238 208h36v176h-36z', P.white);
  out += blob(122, 146, 142, 96, P.white) + blob(248, 138, 142, 100, P.white);
  out += p('M244 344h-38v22h-30v22h-22v22M268 344h38v22h30v22h22v22', 'none', ` ${stroke(P.white, 12)}`);
  out += p('M244 344h-20v34h-24v24M268 344h20v34h24v24', 'none', ` ${stroke(P.white, 7)}`);
  out += roundedRect(146, 356, 220, 58, 18, P.white);
  return `<g transform="translate(56 42) scale(0.78)">${out}</g>`;
}

function buildAndroidIcon() {
  return {
    name: 'android_icon.svg',
    width: 512,
    height: 512,
    viewBox: '0 0 256 256',
    usedCells: 0,
    source: svg(512, 512, pngPixelSvg(loadUserIcon('user_sprout_primary.png')), '0 0 256 256'),
  };
}

function buildAndroidForeground() {
  return {
    name: 'android_icon_foreground.svg',
    width: 432,
    height: 432,
    viewBox: '0 0 512 512',
    usedCells: 0,
    source: svg(432, 432, androidForegroundArt(), '0 0 512 512'),
  };
}

function buildAndroidBackground() {
  return {
    name: 'android_icon_background.svg',
    width: 432,
    height: 432,
    viewBox: '0 0 512 512',
    usedCells: 0,
    source: svg(432, 432, androidBackgroundArt(), '0 0 512 512'),
  };
}

function buildAndroidMonochrome() {
  return {
    name: 'android_icon_monochrome.svg',
    width: 432,
    height: 432,
    viewBox: '0 0 512 512',
    usedCells: 0,
    source: svg(432, 432, androidMonochromeArt(), '0 0 512 512'),
  };
}
function weatherArt() {
  const random = rng(301);
  let out = '';
  const bands = [
    { x0: 4, x1: 508, y0: 8, y1: 88, count: 24 },
    { x0: 4, x1: 92, y0: 104, y1: 500, count: 18 },
    { x0: 420, x1: 508, y0: 104, y1: 500, count: 18 },
    { x0: 4, x1: 508, y0: 420, y1: 500, count: 24 },
  ];
  for (const band of bands) {
    for (let i = 0; i < band.count; i += 1) {
      const x = Math.floor((band.x0 + random() * (band.x1 - band.x0)) / 2) * 2;
      const y = Math.floor((band.y0 + random() * (band.y1 - band.y0)) / 2) * 2;
      const length = 8 + Math.floor(random() * 7) * 2;
      const color = i % 3 === 0 ? P.sky : P.turquoise;
      out += r(x, y, 2, length, color, ' opacity="0.32"');
      if (i % 4 === 0) out += r(x - 2, y + 4, 2, 4, color, ' opacity="0.22"');
    }
  }
  out += r(8, 10, 40, 4, P.sky, ' opacity="0.12"') + r(452, 486, 48, 4, P.sky, ' opacity="0.12"');
  return svg(512, 512, out.trimEnd());
}

function envTree(x, y, scale = 1, seed = 1) {
  let body = r(34, 44, 12, 66, P.ink) + r(37, 46, 6, 62, P.soil);
  body += branch(40, 64, 22, 40, P.soil, 7) + branch(40, 70, 59, 43, P.soil, 7);
  body += foliage(-4, 0, 52, 42, P.leaf, P.lime, P.turquoise, seed);
  body += foliage(30, -4, 54, 46, P.leaf, P.lime, P.cream, seed + 1);
  body += foliage(12, 20, 60, 38, P.forest, P.leaf, P.lime, seed + 2);
  body += r(42, 100, 30, 6, P.ink, ' opacity="0.18"');
  return `<g transform="translate(${x} ${y}) scale(${scale})">${body}</g>`;
}

function envCypress(x, y, scale = 1) {
  let body = r(30, 42, 8, 72, P.soil) + r(32, 48, 4, 64, P.barkLight);
  for (let row = 0; row < 7; row += 1) {
    const width = 16 + row * 5;
    body += r(34 - width, row * 10, width * 2, 14, P.ink);
    body += r(36 - width, row * 10 + 2, width * 2 - 4, 10, P.forest);
    body += r(30 - width, row * 10 + 3, Math.max(6, width), 3, P.leaf);
  }
  body += r(20, 108, 32, 6, P.ink, ' opacity="0.18"');
  return `<g transform="translate(${x} ${y}) scale(${scale})">${body}</g>`;
}

function envBench(x, y, scale = 1) {
  let body = r(0, 18, 66, 10, P.ink) + r(4, 14, 58, 10, P.bark);
  body += r(4, 0, 58, 8, P.ink) + r(7, 2, 52, 5, P.barkLight);
  body += r(8, 24, 5, 18, P.ink) + r(53, 24, 5, 18, P.ink);
  body += r(10, 16, 46, 2, P.gold);
  return `<g transform="translate(${x} ${y}) scale(${scale})">${body}</g>`;
}

function envPath(points, width = 54) {
  const data = points.map((point, index) => `${index === 0 ? 'M' : 'L'}${point[0]} ${point[1]}`).join(' ');
  return p(data, 'none', ` ${stroke(P.ink, width + 6)}`) + p(data, 'none', ` ${stroke(P.cream, width)}`) +
    p(data, 'none', ` ${stroke(P.gold, 2)}`);
}

function envSaplingBed(x, y, width, seed = 1) {
  const random = rng(seed);
  let out = blob(x, y, width, 26, P.ink) + blob(x + 3, y + 3, width - 6, 20, P.soil);
  const count = Math.max(1, Math.floor(width / 48));
  for (let i = 0; i < count; i += 1) {
    const px = Math.round(x + 18 + i * ((width - 36) / Math.max(1, count - 1)));
    const py = y + 5 + Math.floor(random() * 3) * 2;
    out += r(px, py + 7, 3, 13, P.bark);
    out += leaf(px + 1, py + 5, 18, P.leaf, true);
    out += leaf(px - 4, py + 10, 14, P.lime, true);
    out += leaf(px + 6, py + 11, 14, P.forest, true);
  }
  return out;
}

function envArch(x, y, width = 92, height = 96) {
  const half = Math.floor(width / 2);
  let out = r(x, y + 28, width, height - 28, P.cream);
  out += p(`M${x + 12} ${y + height}V${y + 36}H${x + 24}V${y + 24}H${x + half - 10}V${y + 14}H${x + half + 10}V${y + 24}H${x + width - 24}V${y + 36}H${x + width - 12}V${y + height}Z`, P.forest);
  out += p(`M${x + 20} ${y + height}V${y + 42}H${x + 30}V${y + 32}H${x + half - 6}V${y + 24}H${x + half + 6}V${y + 32}H${x + width - 30}V${y + 42}H${x + width - 20}V${y + height}Z`, P.turquoise);
  out += r(x + 34, y + 58, width - 68, height - 58, P.ink);
  out += r(x + 2, y + height - 6, width - 4, 6, P.bark);
  return out;
}

function cityWindow(x, y, width = 34, height = 48) {
  return r(x - 3, y - 3, width + 6, height + 6, P.ink) + r(x, y, width, height, P.turquoise) +
    r(x + 4, y + 4, width - 8, height - 8, P.sky) + r(x + Math.floor(width / 2) - 1, y, 2, height, P.forest);
}

const CHAPTER_SCENES = [
  { scene: 'garden_overgrown', description: 'Overgrown forgotten garden with a shed, pond and six reserved planting beds' },
  { scene: 'garden_saplings', description: 'Renewed garden with repaired fences, young trees and six reserved planting beds' },
  { scene: 'garden_soil_water', description: 'Soil and water chapter garden with compost area, drainage and six reserved planting beds' },
  { scene: 'school_courtyard', description: 'School courtyard with classrooms, paths, water tank and six reserved planting beds' },
  { scene: 'memorial_garden', description: 'Quiet memorial garden with cypress trees, monument, reflecting pool and six reserved planting beds' },
  { scene: 'neighborhood_park', description: 'Neighborhood park with benches, trees, pond and six reserved planting beds' },
  { scene: 'green_city', description: 'Green city street with buildings, canal, street trees and six reserved planting beds' },
  { scene: 'city_stewardship', description: 'City stewardship celebration with bunting, mature trees, canal and six reserved planting beds' },
];

const chapterSceneManifestRows = CHAPTER_SCENES.map(({ scene, description }) =>
  `| \`assets/art/scene_${scene}.svg\` | 1280 × 720 | ${description} |`).join('\n');

function sceneSky(city = false) {
  let out = r(0, 0, 1280, 200, P.sky);
  if (city) {
    for (let x = 0; x < 1280; x += 96) {
      const height = 54 + ((x / 96) % 3) * 24;
      out += r(x, 200 - height, 82, height, x % 192 === 0 ? P.forest : P.leaf);
      out += r(x + 12, 212 - height, 12, 16, P.cream);
      out += r(x + 48, 212 - height, 12, 16, P.cream);
    }
  } else {
    out += p('M0 190V148L120 92L246 150L390 70L566 158L720 104L906 172L1080 82L1280 158V190Z', P.leaf);
    out += p('M0 190V168L180 122L338 176L520 126L706 180L892 130L1104 176L1280 136V190Z', P.forest);
  }
  out += r(0, 190, 1280, 10, P.forest);
  return out;
}

function sceneGround(seed, base = P.earth, city = false) {
  let out = sceneSky(city) + r(0, 200, 1280, 520, base);
  const random = rng(seed);
  const colors = [P.leaf, P.forest, P.lime, P.bark];
  for (let i = 0; i < 150; i += 1) {
    const x = Math.floor(random() * 640) * 2;
    const y = 208 + Math.floor(random() * 252) * 2;
    const width = random() > 0.82 ? 6 : 2;
    const height = random() > 0.88 ? 6 : 2;
    out += r(x, y, width, height, colors[Math.floor(random() * colors.length)]);
  }
  return out;
}

function scenePlantingCourt() {
  let out = roundedRect(158, 178, 364, 444, 26, P.ink);
  out += roundedRect(166, 186, 348, 428, 20, P.gold);
  out += roundedRect(174, 194, 332, 412, 16, P.bark);
  out += r(182, 202, 316, 396, P.earth);
  out += r(326, 202, 12, 396, P.cream);
  out += r(182, 354, 316, 12, P.cream);
  out += r(182, 474, 316, 12, P.cream);
  for (const [x, y] of [[245, 300], [420, 300], [245, 420], [420, 420], [245, 540], [420, 540]]) {
    out += roundedRect(x - 56, y - 30, 112, 60, 10, P.ink);
    out += roundedRect(x - 49, y - 23, 98, 46, 6, P.soil);
    out += r(x - 40, y - 15, 80, 3, P.bark);
  }
  return `<g data-planting-court="158,178,364,444">${out}</g>`;
}

function sceneFence(x, y, width, repaired = true) {
  let out = r(x, y, width, 8, P.ink) + r(x + 4, y + 2, width - 8, 4, repaired ? P.barkLight : P.bark);
  for (let post = x; post <= x + width; post += 48) {
    out += r(post, y - 12, 8, 30, P.ink) + r(post + 2, y - 10, 4, 26, repaired ? P.cream : P.soil);
  }
  return out;
}

function scenePond() {
  let out = roundedRect(962, 457, 186, 166, 30, P.ink);
  out += roundedRect(970, 465, 170, 150, 24, P.water);
  out += r(984, 479, 142, 8, P.sky) + r(994, 497, 122, 4, P.turquoise);
  out += r(1006, 552, 96, 4, P.turquoise) + r(1024, 570, 62, 4, P.sky);
  out += r(978, 473, 10, 134, P.leaf) + r(1122, 473, 10, 134, P.leaf);
  return out;
}

function sceneShed() {
  let out = r(944, 164, 286, 180, P.ink) + r(952, 172, 270, 164, P.bark);
  out += p('M936 172H1238L1214 136H960Z', P.soil);
  out += r(960, 176, 254, 8, P.barkLight);
  out += r(1000, 214, 70, 122, P.ink) + r(1008, 222, 54, 114, P.soil);
  out += r(1040, 274, 6, 6, P.gold);
  out += r(1102, 210, 72, 54, P.ink) + r(1110, 218, 56, 38, P.sky);
  out += r(1136, 218, 4, 38, P.forest) + r(1110, 235, 56, 4, P.forest);
  out += r(972, 326, 230, 10, P.cream);
  return out;
}

function sceneSchoolBuilding() {
  let out = r(0, 0, 1280, 200, P.brick) + r(0, 0, 1280, 12, P.gold);
  out += r(0, 188, 1280, 12, P.ink) + r(0, 184, 1280, 6, P.cream);
  for (let x = 18; x < 1240; x += 168) {
    out += r(x, 38, 148, 142, P.ink) + r(x + 8, 46, 132, 126, P.cream);
    out += r(x + 16, 54, 116, 110, P.brick);
    out += cityWindow(x + 28, 70, 30, 42) + cityWindow(x + 88, 70, 30, 42);
    out += r(x + 52, 126, 44, 38, P.forest) + r(x + 58, 132, 32, 32, P.turquoise);
    out += r(x + 72, 132, 4, 32, P.forest);
  }
  return out;
}

function sceneCityBuildings() {
  let out = sceneSky(true);
  out += r(0, 200, 118, 520, P.brick) + r(1162, 200, 118, 520, P.brick);
  out += r(106, 200, 12, 520, P.cream) + r(1162, 200, 12, 520, P.cream);
  for (let y = 232; y < 700; y += 96) {
    out += r(22, y, 74, 54, P.ink) + r(30, y + 8, 58, 38, P.sky);
    out += r(1176, y, 74, 54, P.ink) + r(1184, y + 8, 58, 38, P.sky);
  }
  return out;
}

function sceneMonument() {
  let out = roundedRect(579, 206, 126, 180, 18, P.ink);
  out += roundedRect(587, 214, 110, 164, 14, P.cream);
  out += r(601, 246, 82, 92, P.forest) + r(609, 254, 66, 76, P.turquoise);
  out += r(625, 270, 34, 44, P.cream) + r(633, 278, 18, 28, P.gold);
  out += r(607, 356, 70, 8, P.gold);
  return out;
}

function sceneBunting() {
  let out = p('M540 150H1180', 'none', ` ${stroke(P.ink, 4)}`);
  const colors = [P.rose, P.gold, P.turquoise, P.lime];
  for (let x = 548; x < 1170; x += 42) {
    const color = colors[Math.floor((x - 548) / 42) % colors.length];
    out += p(`M${x} 152h28l-14 26Z`, color);
  }
  return out;
}

function sceneFlowerBed(x, y, width, seed) {
  let out = blob(x, y, width, 26, P.ink) + blob(x + 4, y + 4, width - 8, 18, P.soil);
  const random = rng(seed);
  for (let i = 0; i < Math.max(3, Math.floor(width / 34)); i += 1) {
    const px = Math.round(x + 16 + random() * (width - 32));
    const py = y + 4 + Math.floor(random() * 3) * 2;
    out += r(px, py + 6, 3, 12, P.leaf);
    out += blossom(px + 1, py + 4, i % 2 ? P.rose : P.gold, P.cream, 5);
  }
  return out;
}

function chapterSceneArt(scene) {
  let out = '';
  if (scene === 'garden_overgrown') {
    out = sceneGround(401, P.earth);
    out += sceneFence(70, 182, 1140, false) + envPath([[540, 620], [900, 620], [960, 560]], 42);
    out += sceneShed() + scenePond();
    out += envTree(24, 148, 1.25, 410) + envCypress(1168, 142, 1.15);
    out += scenePlantingCourt();
    out += sceneFlowerBed(548, 566, 150, 411) + r(574, 262, 8, 4, P.bark) + r(604, 282, 6, 4, P.gold);
  } else if (scene === 'garden_saplings') {
    out = sceneGround(402, P.earth);
    out += sceneFence(70, 182, 1140, true) + envPath([[540, 620], [900, 620], [960, 560]], 42);
    out += sceneShed() + scenePond();
    out += envTree(30, 146, 1.2, 420) + envTree(1138, 144, 1.15, 421);
    out += envSaplingBed(566, 248, 164, 422) + envSaplingBed(756, 548, 150, 423);
    out += scenePlantingCourt();
    out += sceneFlowerBed(548, 566, 150, 424);
  } else if (scene === 'garden_soil_water') {
    out = sceneGround(403, P.earth);
    out += sceneFence(70, 182, 1140, true) + sceneShed() + scenePond();
    out += roundedRect(854, 266, 116, 76, 16, P.ink) + roundedRect(862, 274, 100, 60, 12, P.soil);
    out += blob(548, 250, 132, 54, P.ink) + blob(556, 258, 116, 38, P.soil);
    out += blob(742, 548, 150, 58, P.ink) + blob(750, 556, 134, 42, P.bark);
    out += p('M520 392H850L962 500', 'none', ` ${stroke(P.ink, 18)}`) + p('M520 392H850L962 500', 'none', ` ${stroke(P.water, 10)}`);
    out += scenePlantingCourt();
  } else if (scene === 'school_courtyard') {
    out = sceneGround(404, P.earth) + sceneSchoolBuilding();
    out += envPath([[540, 222], [1180, 222]], 44) + envPath([[540, 222], [540, 620]], 44);
    out += envPath([[540, 620], [1180, 620]], 44);
    out += scenePond() + envTree(28, 150, 1.15, 430) + envCypress(1190, 154, 1.1);
    out += scenePlantingCourt();
    out += sceneFlowerBed(594, 556, 168, 431);
  } else if (scene === 'memorial_garden') {
    out = sceneGround(405, P.earth);
    out += envPath([[540, 222], [1180, 222]], 44) + envPath([[540, 222], [540, 620]], 44);
    out += envPath([[540, 620], [1180, 620]], 44);
    out += envCypress(28, 126, 1.35) + envCypress(1180, 122, 1.4);
    out += envTree(30, 164, 1.1, 440) + envTree(1138, 150, 1.15, 441);
    out += envArch(548, 128, 92, 96) + envArch(820, 128, 92, 96);
    out += sceneMonument() + scenePond();
    out += scenePlantingCourt();
    out += sceneFlowerBed(716, 566, 172, 442);
  } else if (scene === 'neighborhood_park') {
    out = sceneGround(406, P.earth);
    out += envPath([[540, 222], [1180, 222]], 46) + envPath([[540, 222], [540, 620]], 46);
    out += envPath([[540, 620], [1180, 620]], 46);
    out += envTree(24, 138, 1.35, 450) + envTree(1136, 134, 1.3, 451);
    out += envCypress(1180, 168, 1.2) + envCypress(62, 178, 1.15);
    out += envBench(592, 260, 1.2) + envBench(1008, 282, 1.2) + envBench(908, 588, 1.15);
    out += scenePond() + sceneFlowerBed(584, 548, 180, 452) + sceneFlowerBed(792, 548, 150, 453);
    out += scenePlantingCourt();
  } else if (scene === 'green_city') {
    out = sceneGround(407, P.earth, true) + sceneCityBuildings();
    out += envPath([[540, 222], [1180, 222]], 44) + envPath([[540, 222], [540, 620]], 44);
    out += envPath([[540, 620], [1180, 620]], 44);
    out += envTree(128, 238, 1.05, 460) + envTree(1018, 226, 1.1, 461);
    out += envCypress(1160, 260, 1.15) + envCypress(62, 270, 1.2);
    out += scenePond() + envBench(596, 590, 1.2) + envBench(746, 260, 1.1);
    out += scenePlantingCourt();
    out += sceneFlowerBed(556, 552, 168, 462);
  } else {
    out = sceneGround(408, P.earth, true) + sceneCityBuildings();
    out += sceneBunting();
    out += envPath([[540, 222], [1180, 222]], 44) + envPath([[540, 222], [540, 620]], 44);
    out += envPath([[540, 620], [1180, 620]], 44);
    out += envTree(126, 226, 1.2, 470) + envTree(1016, 214, 1.25, 471);
    out += envCypress(1160, 244, 1.2) + envCypress(58, 258, 1.2);
    out += scenePond() + envBench(592, 590, 1.2) + envBench(744, 260, 1.1);
    out += roundedRect(724, 500, 176, 70, 18, P.ink) + roundedRect(732, 508, 160, 54, 12, P.barkLight);
    out += r(744, 516, 136, 6, P.gold) + r(756, 532, 112, 4, P.cream);
    out += scenePlantingCourt();
    out += sceneFlowerBed(556, 552, 150, 472) + sceneFlowerBed(920, 552, 150, 473);
  }
  return `<g data-scene="${scene}">${out}</g>`;
}

function buildEnvironmentScenes() {
  return CHAPTER_SCENES.map(({ scene }) => ({
    name: `scene_${scene}.svg`, width: 1280, height: 720, usedCells: 0,
    source: svg(1280, 720, chapterSceneArt(scene)),
  }));
}

function buttonLeaf(x, y, size, fill, flip = false) {
  const scale = size / 20;
  const outline = p('M0 6H4V2H10V0H16V4H20V8H16V12H10V14H4V12H0Z', P.ink);
  const inner = p('M2 7H6V4H10V2H14V6H18V9H14V11H10V13H6V11H2Z', fill) +
    r(6, 7, 10, 2, fill === P.lime ? P.cream : P.lime, ' opacity="0.55"');
  return `<g transform="translate(${x} ${y}) scale(${flip ? -scale : scale} ${scale})">${outline}${inner}</g>`;
}

function titlePanelArt() {
  let out = `<defs><linearGradient id="title_wood" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${P.barkLight}"/><stop offset="0.5" stop-color="${P.bark}"/>` +
    `<stop offset="1" stop-color="${P.soil}"/></linearGradient>` +
    `<linearGradient id="title_forest" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${P.earth}"/><stop offset="1" stop-color="${P.forest}"/></linearGradient></defs>`;
  out += roundedRect(12, 14, 816, 160, 34, P.ink, ' opacity="0.42"');
  out += roundedRect(6, 6, 828, 168, 32, P.ink);
  out += roundedRect(10, 10, 820, 160, 28, P.gold);
  out += roundedRect(16, 16, 808, 148, 24, `url(#title_wood)`);
  out += roundedRect(26, 26, 788, 128, 18, P.ink);
  out += roundedRect(30, 30, 780, 120, 14, `url(#title_forest)`);
  out += r(44, 38, 752, 3, P.leaf, ' opacity="0.48"');
  out += r(44, 139, 752, 3, P.ink, ' opacity="0.34"');
  out += roundedRect(42, 42, 108, 108, 30, P.ink);
  out += roundedRect(46, 46, 100, 100, 26, P.gold);
  out += roundedRect(52, 52, 88, 88, 22, P.forest);
  out += r(62, 60, 68, 3, P.leaf, ' opacity="0.65"');
  out += p('M92 74h8v38h-8z', P.cream);
  out += p('M90 84H72V72H60V80H70V90H84V96H90Z', P.lime);
  out += p('M100 74h10V62h14v10h-10v10h-10V84h-4Z', P.leafHighlight);
  out += p('M90 96H76V88H68V98H80V106H90Z', P.leaf);
  out += p('M92 112H84V120H76V126H86V122H94Z', P.gold);
  out += p('M100 112h8v8h8v6h-10v-4h-8z', P.gold);
  out += r(178, 50, 2, 80, P.gold, ' opacity="0.48"');
  out += p('M179 88l8 8-8 8-8-8z', P.gold);
  out += r(210, 137, 572, 2, P.gold, ' opacity="0.46"');
  out += r(210, 141, 420, 2, P.leaf, ' opacity="0.38"');
  out += buttonLeaf(14, 14, 26, P.lime) + buttonLeaf(20, 36, 17, P.leaf);
  out += buttonLeaf(826, 14, 26, P.lime, true) + buttonLeaf(820, 36, 17, P.leaf, true);
  out += buttonLeaf(14, 144, 24, P.leaf) + buttonLeaf(826, 144, 24, P.leaf, true);
  out += blossom(38, 34, P.rose, P.roseLight, 6) + blossom(802, 148, P.roseLight, P.cream, 5);
  return svg(840, 184, out.trimEnd());
}

function titleButtonArt(width, height, kind, state) {
  const green = kind === 'green';
  const dark = kind === 'dark';
  const about = kind === 'about';
  const water = kind === 'water';
  const danger = kind === 'danger';
  const pressed = state === 'pressed';
  const hover = state === 'hover';
  let top = P.barkLight;
  let middle = P.bark;
  let bottom = P.soil;
  let edge = P.gold;
  if (green) {
    top = hover ? P.leafHighlight : P.lime;
    middle = hover ? P.lime : P.leaf;
    bottom = pressed ? P.ink : P.forest;
    edge = P.cream;
  } else if (water) {
    top = hover ? P.sky : P.rootLight;
    middle = hover ? P.rootLight : P.water;
    bottom = pressed ? P.ink : P.forest;
    edge = P.cream;
  } else if (danger) {
    top = hover ? P.roseLight : P.rose;
    middle = hover ? P.rose : P.roseDark;
    bottom = pressed ? P.ink : P.roseDark;
    edge = P.cream;
  } else if (dark) {
    top = pressed ? P.soil : P.bark;
    middle = P.soil;
    bottom = P.ink;
  } else if (hover) {
    top = P.barkLight;
    middle = P.gold;
    bottom = P.bark;
  } else if (pressed) {
    top = P.bark;
    middle = P.soil;
    bottom = P.ink;
  }
  const gradientId = `button_${kind}_${state}`;
  let out = `<defs><linearGradient id="${gradientId}" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${top}"/><stop offset="0.48" stop-color="${middle}"/>` +
    `<stop offset="1" stop-color="${bottom}"/></linearGradient></defs>`;
  out += roundedRect(5, pressed ? 5 : 7, width - 10, height - 12, Math.floor(height / 3), P.ink, ' opacity="0.42"');
  out += roundedRect(3, 4, width - 6, height - 8, Math.floor(height / 3), P.ink);
  out += roundedRect(5, 6, width - 10, height - 12, Math.floor(height / 3), edge);
  const innerY = pressed ? 11 : 9;
  out += roundedRect(8, innerY, width - 16, height - innerY - 10, Math.floor(height / 3) - 4, `url(#${gradientId})`);
  out += roundedRect(17, pressed ? 14 : 12, width - 34, pressed ? 4 : 7, 3, P.cream, ` opacity="${pressed ? '0.12' : hover ? '0.46' : '0.32'}"`);
  if (!green && !water && !danger && width >= 240) {
    for (let i = 0; i < 3; i += 1) {
      out += r(34, 25 + i * 11, width - 68, 2, P.soil, ' opacity="0.24"');
      out += r(42, 28 + i * 11, width - 84, 2, P.barkLight, ' opacity="0.22"');
    }
  }
  if (green || water || danger) {
    out += r(30, 18, width - 60, 3, P.cream, ' opacity="0.24"');
    out += r(32, height - 19, width - 64, 3, P.ink, ' opacity="0.18"');
  }
  const leafColor = green ? P.forest : P.leaf;
  if (width >= 240) {
    out += buttonLeaf(5, 7, 28, leafColor, false) + buttonLeaf(12, 27, 20, P.lime, false) + buttonLeaf(3, 39, 17, P.leaf, false);
    out += buttonLeaf(width - 5, height - 35, 28, leafColor, true) + buttonLeaf(width - 12, height - 47, 20, P.lime, true) + buttonLeaf(width - 3, height - 56, 17, P.leaf, true);
    if (green || about) {
      out += blossom(width - 20, 15, P.rose, P.roseLight, 6);
      out += blossom(20, height - 15, P.roseLight, P.cream, 5);
    }
  } else if (width >= 120) {
    out += buttonLeaf(3, 7, 19, leafColor, false) + buttonLeaf(8, 24, 13, P.lime, false);
    out += buttonLeaf(width - 3, height - 26, 19, leafColor, true) + buttonLeaf(width - 8, height - 37, 13, P.lime, true);
  }
  return svg(width, height, out);
}

function buildTitleButtons() {
  const specs = [
    { key: 'start', kind: 'green', width: 360, height: 84 },
    { key: 'wood', kind: 'wood', width: 360, height: 76 },
    { key: 'wood_dark', kind: 'dark', width: 360, height: 76 },
    { key: 'settings', kind: 'wood', width: 160, height: 58 },
    { key: 'about', kind: 'about', width: 240, height: 66 },
    { key: 'hud', kind: 'wood', width: 132, height: 58 },
    { key: 'quest', kind: 'green', width: 360, height: 66 },
    { key: 'compact', kind: 'wood', width: 160, height: 64 },
    { key: 'water', kind: 'water', width: 360, height: 84 },
    { key: 'danger', kind: 'danger', width: 360, height: 84 },
  ];
  const assets = [];
  for (const spec of specs) {
    for (const state of ['normal', 'hover', 'pressed']) {
      const suffix = state === 'normal' ? '' : `_${state}`;
      assets.push({
        name: `button_${spec.key}${suffix}.svg`,
        width: spec.width,
        height: spec.height,
        usedCells: 0,
        source: titleButtonArt(spec.width, spec.height, spec.kind, state),
      });
    }
  }
  return assets;
}

function hudPanelArt() {
  let out = `<defs><linearGradient id="hud_wood" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${P.barkLight}"/><stop offset="0.5" stop-color="${P.bark}"/>` +
    `<stop offset="1" stop-color="${P.soil}"/></linearGradient></defs>`;
  out += roundedRect(7, 8, 836, 54, 22, P.ink, ' opacity="0.38"');
  out += roundedRect(5, 4, 840, 56, 22, P.ink);
  out += roundedRect(8, 7, 834, 50, 19, P.gold);
  out += roundedRect(12, 11, 826, 42, 16, `url(#hud_wood)`);
  out += roundedRect(17, 15, 816, 34, 13, P.forest);
  out += r(28, 18, 794, 3, P.leaf, ' opacity="0.55"');
  out += leaf(12, 15, 10, P.lime, true) + leaf(828, 47, 10, P.leaf, true);
  return svg(850, 64, out.trimEnd());
}

function hudChipArt() {
  let out = `<defs><linearGradient id="hud_chip" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${P.leaf}"/><stop offset="1" stop-color="${P.forest}"/></linearGradient></defs>`;
  out += roundedRect(3, 4, 86, 38, 13, P.ink, ' opacity="0.32"');
  out += roundedRect(2, 2, 88, 40, 13, P.ink);
  out += roundedRect(5, 5, 82, 34, 11, P.gold);
  out += roundedRect(8, 8, 76, 28, 9, `url(#hud_chip)`);
  out += r(14, 11, 64, 3, P.lime, ' opacity="0.42"');
  return svg(92, 44, out.trimEnd());
}

function aboutPanelArt() {
  let out = `<defs><linearGradient id="about_wood" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${P.barkLight}"/><stop offset="0.5" stop-color="${P.bark}"/>` +
    `<stop offset="1" stop-color="${P.soil}"/></linearGradient>` +
    `<linearGradient id="about_paper" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="${P.cream}"/><stop offset="1" stop-color="${P.cream}"/></linearGradient></defs>`;
  out += roundedRect(14, 16, 872, 622, 42, P.ink, ' opacity="0.42"');
  out += roundedRect(8, 8, 884, 622, 42, P.ink);
  out += roundedRect(12, 12, 876, 614, 38, P.gold);
  out += roundedRect(20, 20, 860, 598, 32, `url(#about_wood)`);
  out += roundedRect(34, 34, 832, 570, 26, P.barkLight);
  out += roundedRect(42, 42, 816, 554, 22, `url(#about_paper)`);
  out += roundedRect(250, 20, 400, 70, 24, P.forest);
  out += roundedRect(262, 28, 376, 54, 18, P.leaf);
  out += r(278, 34, 344, 4, P.lime, ' opacity="0.45"');
  const ribbonSprout = p('M14 10h4v18h-4z', P.cream)
    + p('M10 12H4v6h4v4h8v-4h4v-6h-4v2h-4v-2z', P.lime)
    + p('M18 8h6v-2h4v6h-4v4h-8v-4h-2V8h4z', P.cream)
    + r(8, 28, 16, 4, P.gold);
  out += `<g transform="translate(430 36) scale(1.25)">${ribbonSprout}</g>`;
  for (const [x, y, flip] of [[54, 58, false], [846, 58, true], [54, 592, false], [846, 592, true]]) {
    out += leaf(x, y, 26, flip ? P.leaf : P.lime, true);
    out += leaf(x + (flip ? -14 : 14), y + 12, 22, P.forest, true);
    out += leaf(x + (flip ? -20 : 20), y - 4, 18, P.leaf, true);
    out += blossom(x + (flip ? -26 : 26), y + 4, P.rose, P.roseLight, 7);
    out += blossom(x + (flip ? -8 : 8), y + 28, P.roseLight, P.cream, 5);
  }
  for (let i = 0; i < 7; i += 1) {
    out += r(48, 150 + i * 52, 8, 3, P.gold, ' opacity="0.35"');
    out += r(844, 150 + i * 52, 8, 3, P.gold, ' opacity="0.35"');
  }
  return svg(900, 650, out.trimEnd());
}

const manifest = `# Roots of Sacrifice Art Asset Manifest

The game artwork is original to Roots of Sacrifice (ریشه‌های ایثار). Most SVG assets are procedurally generated; the sprout icon sources under \`assets/art/source\` and \`assets/art/cinematic_garden.png\` were created and supplied by the project owner and are used with authorization. No other third-party artwork is incorporated. SVG geometry is deterministic; no external fonts, images, scripts, or network resources are required at runtime.

## Generated SVG assets

| File | Dimensions | Grid and contents |
| --- | ---: | --- |
| \`assets/art/tiles.svg\` | 512 × 256 | 8 × 4 atlas; 32 named 64 × 64 terrain/object tiles in the requested order |
| \`assets/art/player.svg\` | 256 × 384 | 4 × 6 sheet; 24 directional, walking, watering, and planting frames |
| \`assets/art/npcs.svg\` | 384 × 256 | 4 × 6 sheet; 24 guide, mentor, student, and volunteer poses |
| \`assets/art/plants.svg\` | 512 × 384 | 6 × 6 used cells in an 8 × 6 atlas; six stages for each of six native Iranian tree species, two transparent spare columns |
| \`assets/art/props.svg\` | 512 × 256 | 8 × 4 atlas; 32 tools, collectibles, environment props, and effects |
| \`assets/art/icons.svg\` | 512 × 128 | 16 × 4 atlas; 33 defined 32-pixel game icons and 31 transparent spare cells |
| \`assets/art/sprout_icon.svg\` | 64 × 64 | User-created growth sprout icon converted losslessly to crisp SVG pixel runs |
| \`assets/art/logo.svg\` | 640 × 256 | Transparent centered tree/heart-root logo mark |
| \`assets/art/weather_overlay.svg\` | 512 × 512 | Transparent edge-weighted light-rain overlay with a clear center |
| \`assets/art/android_icon.svg\` | 512 × 512 | User-created primary sprout icon converted losslessly to crisp SVG pixel runs |
| \`assets/art/android_icon_foreground.svg\` | 432 × 432 | Transparent two-leaf sprout and soil foreground matching the user icon |
| \`assets/art/android_icon_background.svg\` | 432 × 432 | Warm ember, gold halo and earth adaptive-icon background |
| \`assets/art/android_icon_monochrome.svg\` | 432 × 432 | Transparent sprout, root and soil silhouette for themed Android launcher icons |
${chapterSceneManifestRows}
| \`assets/art/button_start.svg\` | 360 × 84 | Leaf-framed green primary button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_wood.svg\` | 360 × 76 | Leaf-framed wooden menu button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_wood_dark.svg\` | 360 × 76 | Leaf-framed dark wooden exit button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_settings.svg\` | 160 × 58 | Compact leaf-framed wooden settings button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_about.svg\` | 240 × 66 | Compact leaf-framed wooden about-team button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_hud.svg\` | 132 × 58 | Compact leaf-framed wooden map/pause button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_quest.svg\` | 360 × 66 | Leaf-framed green mission tracker button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_compact.svg\` | 160 × 64 | Leaf-framed wooden memorial/plants/achievement button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_water.svg\` | 360 × 84 | Leaf-framed blue water/action button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/button_danger.svg\` | 360 × 84 | Leaf-framed red danger button; matching \`_hover\` and \`_pressed\` variants |
| \`assets/art/hud_panel.svg\` | 850 × 64 | Wooden resource HUD frame with gold border and leaf details |
| \`assets/art/hud_chip.svg\` | 92 × 44 | Green resource chip for scores, heart, water, seeds, compost and clock |
| \`assets/art/title_panel.svg\` | 840 × 184 | Forest-green title banner with wooden frame, gold trim, sprout-and-roots medallion and leaf corners |
| \`assets/art/about_panel.svg\` | 900 × 650 | Dedicated pixel-art team panel with wooden frame, cream paper, sprout emblem, green leaves and small blossoms |
| \`assets/art/ASSET_MANIFEST.md\` | — | This inventory and regeneration guide |

## User-supplied source art

- \`assets/art/source/user_sprout_primary.png\` — 256 × 256 RGBA icon created by the project owner; source for the legacy launcher icon.
- \`assets/art/source/user_sprout_growth.png\` — 64 × 64 RGBA icon created by the project owner; source for the in-game sprout icon and icon-atlas cell.
- \`assets/art/cinematic_garden.png\` — 1792 × 1024 RGBA scene created by the project owner; source for the animated title and ending background.

The icon sources are preserved unchanged, excluded from Android exports, and converted to deterministic SVG pixel geometry by the generator. The cinematic source is preserved unchanged and animated at runtime by \`cinematic_garden.gdshader\`.

## Existing protected asset

\`assets/art/title_art.png\` already exists and is intentionally not generated or overwritten. The generator verifies that its checksum remains unchanged.

## Regeneration

From the project root:

\`\`\`sh
node tools/generate_art.mjs
\`\`\`

The command rewrites only the generated SVG files and this manifest, then validates XML structure, dimensions, palette usage, cell coverage, chapter-scene count, reserved planting-court metadata, and file existence. In Godot, keep SVG import filtering set to nearest so the chunky pixels remain crisp when scaled.
`;

function validateSvg(asset) {
  const { name, width, height, usedCells, source, viewBox = `0 0 ${width} ${height}` } = asset;
  const errors = [];
  if (!source.startsWith('<?xml version="1.0" encoding="UTF-8"?>\n<svg ')) errors.push('missing XML declaration/root');
  if (!source.includes(`width="${width}" height="${height}" viewBox="${viewBox}"`)) errors.push('dimension mismatch');
  if (!source.includes('shape-rendering="crispEdges"')) errors.push('crisp rendering missing');
  if (/<(?:text|image|foreignObject)\b/i.test(source)) errors.push('text or external image element found');
  if (/&(?!(?:amp|lt|gt|quot|apos);)/.test(source)) errors.push('unescaped ampersand');

  const stack = [];
  const tags = source.match(/<\/?[A-Za-z][^>]*>/g) || [];
  for (const tag of tags) {
    const match = tag.match(/^<\/?([A-Za-z][\w:-]*)/);
    if (!match) {
      errors.push(`invalid tag ${tag}`);
      continue;
    }
    const tagName = match[1];
    const attributeNames = [...tag.matchAll(/\s([A-Za-z_:][\w:.-]*)="/g)].map((attribute) => attribute[1]);
    if (new Set(attributeNames).size !== attributeNames.length) errors.push(`duplicate attribute in ${tagName}`);
    if (tag.startsWith('</')) {
      const open = stack.pop();
      if (open !== tagName) errors.push(`mismatched closing tag ${tagName}`);
    } else if (!/\/\s*>$/.test(tag)) {
      stack.push(tagName);
    }
  }
  if (stack.length) errors.push(`unclosed tags: ${stack.join(', ')}`);

  const allowedColors = new Set([...Object.values(P), ...USER_ICON_COLORS, 'none']);
  for (const match of source.matchAll(/\b(?:fill|stroke)="([^"]+)"/g)) {
    if (!allowedColors.has(match[1]) && !/^url\(#[A-Za-z_][\w-]*\)$/.test(match[1])) errors.push(`unexpected paint color ${match[1]}`);
  }
  for (const match of source.matchAll(/<rect x="(-?\d+)" y="(-?\d+)" width="(-?\d+)" height="(-?\d+)"/g)) {
    if (Number(match[3]) <= 0 || Number(match[4]) <= 0) errors.push('non-positive rectangle dimensions');
  }
  const cells = [...source.matchAll(/data-cell="(\d+),(\d+)"/g)].map((match) => `${match[1]},${match[2]}`);
  if (new Set(cells).size !== cells.length) errors.push('duplicate grid cell');
  if (cells.length !== usedCells) errors.push(`expected ${usedCells} used cells, found ${cells.length}`);
  if (name === 'tiles.svg') {
    const fullTileBases = (source.match(/<rect x="0" y="0" width="64" height="64"/g) || []).length;
    if (fullTileBases !== 32) errors.push(`expected 32 full tile bases, found ${fullTileBases}`);
  }
  if (name === 'weather_overlay.svg') {
    for (const match of source.matchAll(/<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)"/g)) {
      const [x, y, w, h] = match.slice(1).map(Number);
      const intersectsCenter = x < 400 && x + w > 112 && y < 400 && y + h > 112;
      if (intersectsCenter) errors.push('rain geometry enters transparent center');
    }
  }
  if (name.startsWith('scene_')) {
    if (!source.includes('data-planting-court="158,178,364,444"')) errors.push('reserved planting court missing');
    if (!/data-scene="[a-z_]+"/.test(source)) errors.push('chapter scene metadata missing');
  }
  if (errors.length) throw new Error(`${name}: ${errors.join('; ')}`);
}

function titleChecksum() {
  const titlePath = path.join(ART, 'title_art.png');
  return fs.existsSync(titlePath) ? crypto.createHash('sha256').update(fs.readFileSync(titlePath)).digest('hex') : null;
}

function main() {
  fs.mkdirSync(ART, { recursive: true });
  const beforeTitle = titleChecksum();
  const weatherSource = weatherArt();
  const assets = [
    buildTiles(),
    buildPlayer(),
    buildNpcs(),
    buildPlants(),
    buildProps(),
    buildIcons(),
    buildSproutIcon(),
    buildLogo(),
    { name: 'weather_overlay.svg', width: 512, height: 512, usedCells: 0, source: weatherSource },
    buildAndroidIcon(),
    buildAndroidForeground(),
    buildAndroidBackground(),
    buildAndroidMonochrome(),
    ...buildEnvironmentScenes(),
    ...buildTitleButtons(),
    { name: 'hud_panel.svg', width: 850, height: 64, usedCells: 0, source: hudPanelArt() },
    { name: 'hud_chip.svg', width: 92, height: 44, usedCells: 0, source: hudChipArt() },
    { name: 'title_panel.svg', width: 840, height: 184, usedCells: 0, source: titlePanelArt() },
    { name: 'about_panel.svg', width: 900, height: 650, usedCells: 0, source: aboutPanelArt() },
  ];

  for (const asset of assets) validateSvg(asset);
  const sceneAssets = assets.filter((asset) => asset.name.startsWith('scene_'));
  if (sceneAssets.length !== 8 || new Set(sceneAssets.map((asset) => asset.name)).size !== 8) {
    throw new Error('Expected eight unique chapter scene backgrounds');
  }
  for (const asset of assets) {
    const outputPath = path.join(ART, asset.name);
    fs.writeFileSync(outputPath, asset.source, 'utf8');
    if (!fs.existsSync(outputPath) || fs.statSync(outputPath).size === 0) {
      throw new Error(`Failed to write ${outputPath}`);
    }
    console.log(`Generated ${asset.name} (${asset.width}x${asset.height})`);
  }
  fs.writeFileSync(path.join(ART, 'ASSET_MANIFEST.md'), manifest, 'utf8');

  for (const asset of assets) {
    const written = fs.readFileSync(path.join(ART, asset.name), 'utf8');
    validateSvg({ ...asset, source: written });
  }
  const manifestPath = path.join(ART, 'ASSET_MANIFEST.md');
  if (!fs.existsSync(manifestPath) || fs.statSync(manifestPath).size === 0) throw new Error('Manifest missing');
  const afterTitle = titleChecksum();
  if (beforeTitle !== afterTitle) throw new Error('title_art.png changed during generation');
  console.log(`Validated ${assets.length} SVG files and manifest; title_art.png preserved.`);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}
