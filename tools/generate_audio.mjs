#!/usr/bin/env node
/**
 * Roots of Sacrifice — original procedural audio.
 * Run with: node tools/generate_audio.mjs
 * Dependencies: Node.js built-ins only. Output: assets/audio/*.wav + AUDIO_MANIFEST.md
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SAMPLE_RATE = 32000;
const TAU = Math.PI * 2;
const HEADER_BYTES = 44;
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUTPUT_DIR = path.join(ROOT, 'assets', 'audio');
const ROOT_FREQUENCY = 293.6647679174076; // D4, the root of every original motif.
// A five-note, pentatonic-like palette with a neutral second (16/15) and
// warm just ratios, used as a gentle Persian-inspired color, not a maqam claim.
const SCALE = Object.freeze([1, 16 / 15, 4 / 3, 3 / 2, 9 / 5]);

// Create a deterministic pseudo-random generator from a 32-bit seed.
function mulberry32(seed) {
  let state = seed >>> 0;
  // Advance the seeded state and return one normalized random value per call.
  return () => {
    state += 0x6d2b79f5;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

// Convert a duration in seconds to the nearest whole audio frame.
function frames(duration) {
  return Math.round(duration * SAMPLE_RATE);
}

// Allocate a zero-filled mono buffer for the requested duration.
function silence(duration) {
  return new Float64Array(frames(duration));
}

// Map a scale degree and octave to its just-intonation frequency.
function scaleFrequency(degree, octave = 0) {
  const wrapped = ((degree % SCALE.length) + SCALE.length) % SCALE.length;
  const octaveOffset = Math.floor(degree / SCALE.length);
  return ROOT_FREQUENCY * SCALE[wrapped] * 2 ** (octave + octaveOffset);
}

// Clamp a normalized position and return its smooth raised-cosine ramp.
function raisedCosineRise(value) {
  const x = Math.max(0, Math.min(1, value));
  return 0.5 - 0.5 * Math.cos(Math.PI * x);
}

// Combine smooth attack and release ramps into a click-free amplitude envelope.
function smoothEnvelope(time, duration, attack, release) {
  const enter = raisedCosineRise(time / attack);
  const leave = raisedCosineRise((duration - time) / release);
  return enter * leave;
}

// Wrap an event-tail sample index into the fixed-length destination buffer.
function wrapIndex(index, length) {
  return ((index % length) + length) % length;
}

// Add a soft felt-like pluck from decaying, slightly inharmonic partials.
function addPluck(buffer, start, duration, frequency, amplitude, options = {}) {
  const startFrame = Math.round(start * SAMPLE_RATE);
  const count = Math.min(frames(duration), buffer.length);
  const attack = options.attack ?? 0.014;
  const release = options.release ?? Math.min(0.5, duration * 0.24);
  const decay = options.decay ?? 1.45;
  const detune = options.detune ?? 1.0013;
  // Blend a gentle fundamental with progressively faster-decaying overtones.
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const phase = TAU * frequency * t + 0.045 * Math.sin(TAU * 0.42 * t);
    const envelope = smoothEnvelope(t, duration, attack, release);
    const body =
      Math.sin(phase) +
      0.22 * Math.sin(phase * detune + 0.35) +
      0.30 * Math.sin(phase * 2.002 + 0.2) * Math.exp(-0.7 * t) +
      0.12 * Math.sin(phase * 3.01 + 0.5) * Math.exp(-1.6 * t) +
      0.045 * Math.sin(phase * 4.017) * Math.exp(-2.8 * t);
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * body;
  }
}

// Add rounded bell partials with a soft attack instead of a metallic transient.
function addChime(buffer, start, duration, frequency, amplitude, brightness = 1) {
  const startFrame = Math.round(start * SAMPLE_RATE);
  const count = Math.min(frames(duration), buffer.length);
  const attack = 0.012;
  const release = Math.min(0.24, duration * 0.35);
  // Weight upper partials by brightness and let each decay at its own rate.
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const phase = TAU * frequency * t;
    const body =
      Math.sin(phase) +
      0.25 * brightness * Math.sin(phase * 2.001 + 0.1) * Math.exp(-1.4 * t) +
      0.10 * brightness * Math.sin(phase * 3.997 + 0.4) * Math.exp(-2.5 * t) +
      0.035 * brightness * Math.sin(phase * 5.02) * Math.exp(-4 * t);
    const envelope = smoothEnvelope(t, duration, attack, release) * Math.exp(-1.15 * t);
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * body;
  }
}

// Add a muted hand tap by combining a rounded body with low-passed noise grain.
function addHandPercussion(buffer, start, amplitude, random) {
  const duration = 0.19;
  const count = frames(duration);
  const startFrame = Math.round(start * SAMPLE_RATE);
  let lowPass = 0;
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const envelope = smoothEnvelope(t, duration, 0.009, 0.10) * Math.exp(-15 * t);
    const body = Math.sin(TAU * (174 * t - 18 * t * t)) * 0.72 +
      Math.sin(TAU * 318 * t + 0.2) * 0.14 * Math.exp(-22 * t);
    lowPass += 0.16 * ((random() * 2 - 1) - lowPass);
    const value = body + lowPass * 0.20;
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * value;
  }
}

// Add a short filtered-noise burst with configurable band limits and decay.
function addNoiseBurst(buffer, start, duration, amplitude, random, options = {}) {
  const count = frames(duration);
  const startFrame = Math.round(start * SAMPLE_RATE);
  const lowPassCutoff = options.lowPass ?? 1800;
  const highPassCutoff = options.highPass ?? 0;
  const lowCoefficient = 1 - Math.exp(-TAU * lowPassCutoff / SAMPLE_RATE);
  const highCoefficient = 1 - Math.exp(-TAU * highPassCutoff / SAMPLE_RATE);
  const attack = options.attack ?? 0.008;
  const release = options.release ?? duration * 0.55;
  const decay = options.decay ?? 0;
  let low = 0;
  let slow = 0;
  // Cascade one-pole filters so optional high-pass subtraction shapes the noise.
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const white = random() * 2 - 1;
    low += lowCoefficient * (white - low);
    slow += highCoefficient * (low - slow);
    const colored = highPassCutoff > 0 ? low - slow : low;
    const envelope = smoothEnvelope(t, duration, attack, release) * Math.exp(-decay * t);
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * colored;
  }
}

// Synthesize periodic colored noise using integer-cycle oscillators in each band.
function periodicNoise(duration, seed, bands) {
  const length = frames(duration);
  const result = new Float64Array(length);
  const random = mulberry32(seed);
  let totalAmplitude = 0;
  // Quantize each oscillator to whole cycles so every band loops seamlessly.
  for (const band of bands) {
    for (let j = 0; j < band.count; j += 1) {
      const fraction = band.count === 1 ? 0 : j / (band.count - 1);
      const frequency = band.low + (band.high - band.low) * fraction;
      const cycle = Math.max(1, Math.min(Math.floor(length / 2), Math.round(frequency * duration)));
      const amplitude = band.gain / Math.sqrt(frequency);
      const phase = random() * TAU;
      const phaseCosine = Math.cos(phase);
      const phaseSine = Math.sin(phase);
      const stepCosine = Math.cos(TAU * cycle / length);
      const stepSine = Math.sin(TAU * cycle / length);
      let cosine = phaseCosine;
      let sine = phaseSine;
      totalAmplitude += amplitude;
      for (let i = 0; i < length; i += 1) {
        result[i] += amplitude * cosine;
        const nextCosine = cosine * stepCosine - sine * stepSine;
        sine = sine * stepCosine + cosine * stepSine;
        cosine = nextCosine;
      }
    }
  }
  // Normalize by accumulated band gain to keep the noise bed at a predictable level.
  const normalization = totalAmplitude || 1;
  for (let i = 0; i < length; i += 1) result[i] /= normalization;
  return result;
}

// Mix a generated layer into a destination with optional slow amplitude movement.
function mixLayer(destination, layer, gain, options = {}) {
  const phase = options.phase ?? 0;
  const modulation = options.modulation ?? 0;
  for (let i = 0; i < destination.length; i += 1) {
    const time = i / SAMPLE_RATE;
    const movement = 1 + modulation * Math.sin(TAU * time / (destination.length / SAMPLE_RATE) + phase);
    destination[i] += layer[i] * gain * movement;
  }
}

// Add overlapping periodic chords with slow movement and quantized oscillator cycles.
function addPadChords(buffer, duration, chords, options = {}) {
  const block = duration / chords.length;
  const root = options.root ?? 146.8323839587038; // D3
  const gain = options.gain ?? 0.022;
  const length = buffer.length;
  // Start each chord early and sustain it past its block to create smooth overlap.
  for (let chordIndex = 0; chordIndex < chords.length; chordIndex += 1) {
    const degrees = chords[chordIndex];
    const start = chordIndex * block - block * 0.20;
    const noteDuration = block * 1.48;
    const attack = block * 0.30;
    const release = block * 0.34;
    for (let voice = 0; voice < degrees.length; voice += 1) {
      const rawFrequency = root * SCALE[degrees[voice]];
      const frequency = Math.round(rawFrequency * duration) / duration;
      const count = Math.min(frames(noteDuration), length);
      const startFrame = Math.round(start * SAMPLE_RATE);
      const voiceGain = gain * (voice === 0 ? 1.15 : 0.82);
      for (let i = 0; i < count; i += 1) {
        const t = i / SAMPLE_RATE;
        const globalTime = start + t;
        const phase = TAU * frequency * globalTime;
        const movement = 0.88 + 0.12 * Math.sin(TAU * globalTime / duration + voice * 1.7);
        const tone = Math.sin(phase) +
          0.30 * Math.sin(phase * 2 + 0.25) +
          0.16 * Math.sin(phase * 1.0021 + 0.6);
        const envelope = smoothEnvelope(t, noteDuration, attack, release);
        buffer[wrapIndex(startFrame + i, length)] += voiceGain * tone * movement * envelope;
      }
    }
  }
}

// Add a short water droplet with an integrated downward pitch sweep.
function addDroplet(buffer, start, duration, frequency, amplitude, random, endRatio = 0.58) {
  const count = frames(duration);
  const startFrame = Math.round(start * SAMPLE_RATE);
  const endFrequency = frequency * endRatio;
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const phase = TAU * (frequency * t + (endFrequency - frequency) * t * t / (2 * duration));
    const envelope = raisedCosineRise(t / 0.006) *
      raisedCosineRise((duration - t) / (duration * 0.75)) * Math.exp(-5 * t);
    const tone = Math.sin(phase) + 0.13 * Math.sin(phase * 2.01 + random() * 0.1);
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * tone;
  }
}

// Scatter a deterministic set of droplets evenly across an ambience loop.
function addPeriodicDroplets(buffer, duration, seed, count, amplitude) {
  const random = mulberry32(seed);
  for (let i = 0; i < count; i += 1) {
    const start = ((i + 0.15 + random() * 0.7) / count) * duration;
    const dropletDuration = 0.055 + random() * 0.075;
    addDroplet(buffer, start, dropletDuration, 720 + random() * 1050,
      amplitude * (0.55 + random() * 0.45), random);
  }
}

// Add a soft bird-like glide using an analytic pitch bend and micro-vibrato.
function addBirdCall(buffer, start, frequency, amplitude, random, duration = 0.20) {
  const count = frames(duration);
  const startFrame = Math.round(start * SAMPLE_RATE);
  const bend = 620 + random() * 280;
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const progress = t / duration;
    // Integrate the pitch bend and micro-vibrato analytically for a smooth glide.
    const phase = TAU * (frequency * t + bend * (duration / Math.PI) * (1 - Math.cos(Math.PI * progress)) -
      bend * 0.175 * t * t / duration + (42 / 17) * (1 - Math.cos(TAU * 17 * t)));
    const envelope = raisedCosineRise(t / 0.018) * raisedCosineRise((duration - t) / 0.045);
    const tone = Math.sin(phase) + 0.10 * Math.sin(phase * 2.003 + 0.2);
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * tone;
  }
}

// Subtract the mean sample value to remove DC offset before final normalization.
function removeDC(buffer) {
  let sum = 0;
  for (const sample of buffer) sum += sample;
  const mean = sum / buffer.length;
  if (Math.abs(mean) > 1e-9) {
    for (let i = 0; i < buffer.length; i += 1) buffer[i] -= mean;
  }
}

// Apply endpoint fades, validate samples, and normalize each clip to its target peak.
function finish(buffer, { peak = 0.70, fadeIn = 0, fadeOut = 0 } = {}) {
  removeDC(buffer);
  // Apply raised-cosine edge fades in frame counts so loop seams stay click-free.
  const inFrames = Math.min(buffer.length, frames(fadeIn));
  const outFrames = Math.min(buffer.length, frames(fadeOut));
  for (let i = 0; i < inFrames; i += 1) {
    buffer[i] *= raisedCosineRise(i / Math.max(1, inFrames - 1));
  }
  for (let i = 0; i < outFrames; i += 1) {
    buffer[buffer.length - 1 - i] *= raisedCosineRise(i / Math.max(1, outFrames - 1));
  }
  // Reject invalid or silent output before scaling the measured peak to the target.
  let maximum = 0;
  for (const sample of buffer) {
    if (!Number.isFinite(sample)) throw new Error('Non-finite audio sample');
    maximum = Math.max(maximum, Math.abs(sample));
  }
  if (maximum < 1e-9) throw new Error('Unexpected silent generated clip');
  const gain = peak / maximum;
  for (let i = 0; i < buffer.length; i += 1) buffer[i] *= gain;
  return buffer;
}

// Add a warm bass note with soft harmonics and a gently decaying envelope.
function addBass(buffer, start, duration, frequency, amplitude) {
  const count = Math.min(frames(duration), buffer.length);
  const startFrame = Math.round(start * SAMPLE_RATE);
  for (let i = 0; i < count; i += 1) {
    const t = i / SAMPLE_RATE;
    const phase = TAU * frequency * t;
    const envelope = smoothEnvelope(t, duration, 0.08, Math.min(0.7, duration * 0.35)) * Math.exp(-0.32 * t);
    const tone = Math.sin(phase) + 0.16 * Math.sin(phase * 2 + 0.2) + 0.05 * Math.sin(phase * 3);
    buffer[wrapIndex(startFrame + i, buffer.length)] += amplitude * envelope * tone;
  }
}

// Add a quiet shaker using fast-decaying high-band filtered noise.
function addShaker(buffer, start, amplitude, random) {
  addNoiseBurst(buffer, start, 0.085, amplitude, random, {
    lowPass: 9200, highPass: 2600, attack: 0.004, release: 0.045, decay: 24,
  });
}

// Layer two offset noise bursts to imitate a soft leaf rustle.
function addLeafRustle(buffer, start, amplitude, random, duration = 0.32) {
  addNoiseBurst(buffer, start, duration, amplitude, random, {
    lowPass: 6200, highPass: 900, attack: 0.018, release: duration * 0.7, decay: 5,
  });
  addNoiseBurst(buffer, start + 0.08, duration * 0.65, amplitude * 0.55, random, {
    lowPass: 4800, highPass: 1400, attack: 0.012, release: duration * 0.6, decay: 7,
  });
}

// Compose the main garden theme from pads, plucks, bass, and quiet hand percussion.
function makeGarden() {
  const duration = 32;
  const buffer = silence(duration);
  const chords = [[0, 2, 4], [1, 2, 3], [0, 1, 3], [3, 4, 2], [0, 2, 4], [1, 3, 4], [0, 1, 3], [0, 2, 4]];
  addPadChords(buffer, duration, chords, { gain: 0.026 });
  const melody = [
    [0.45, 0, 1, 3.2], [2.15, 2, 1, 2.7], [4.35, 4, 1, 3.4], [6.55, 3, 1, 2.8],
    [8.45, 2, 1, 3.1], [10.35, 1, 1, 2.8], [12.25, 3, 1, 3.3], [14.45, 4, 1, 3.5],
    [16.55, 2, 1, 2.9], [18.35, 0, 1, 3.4], [20.45, 1, 1, 2.8], [22.35, 3, 1, 3.2],
    [24.45, 4, 1, 3.4], [26.35, 2, 1, 2.9], [28.25, 1, 1, 3.0], [30.1, 0, 1, 2.6],
  ];
  // State the melody as evenly spaced plucked notes over the harmonic bed.
  for (const [start, degree, octave, noteDuration] of melody) {
    addPluck(buffer, start, noteDuration, scaleFrequency(degree, octave), 0.105, { decay: 1.55 });
  }
  // Anchor each four-second chord with bass and occasional upper chord tones.
  for (let chordIndex = 0; chordIndex < chords.length; chordIndex += 1) {
    const start = chordIndex * 4;
    addBass(buffer, start, 3.8, scaleFrequency(chords[chordIndex][0], -1), 0.052);
    if (chordIndex % 2 === 0) {
      addPluck(buffer, start + 1.5, 2.4, scaleFrequency(chords[chordIndex][2], 0), 0.032, { decay: 1.9 });
      addPluck(buffer, start + 2.7, 2.1, scaleFrequency(chords[chordIndex][1], 1), 0.024, { decay: 2.1 });
    }
  }
  // Add a restrained two-second rhythmic pulse without a sharp drum attack.
  const random = mulberry32(4101);
  for (let start = 1; start < duration; start += 2) {
    addHandPercussion(buffer, start, 0.018, random);
    addShaker(buffer, start + 0.9, 0.008, random);
  }
  return finish(buffer, { peak: 0.70, fadeIn: 0.18, fadeOut: 0.18 });
}

// Build a rain-themed music bed from periodic noise, distant plucks, and droplets.
function makeRainMusic() {
  const duration = 32;
  const buffer = silence(duration);
  mixLayer(buffer, periodicNoise(duration, 5101, [
    { count: 26, low: 85, high: 760, gain: 1 },
    { count: 18, low: 1200, high: 6500, gain: 0.24 },
  ]), 0.105, { modulation: 0.12, phase: 0.5 });
  addPadChords(buffer, duration, [[0, 2, 3], [1, 2, 4], [0, 1, 3], [3, 4, 2], [0, 2, 4], [1, 3, 4], [0, 1, 3], [0, 2, 3]], { gain: 0.017 });
  const distantPlucks = [
    [1.2, 2], [4.6, 1], [7.8, 3], [10.9, 2], [14.1, 4], [17.4, 1],
    [20.6, 3], [23.7, 2], [26.8, 4], [29.5, 0],
  ];
  // Keep the melody sparse and quiet so the rain texture remains prominent.
  for (const [start, degree] of distantPlucks) {
    addPluck(buffer, start, 3.4, scaleFrequency(degree, 1), 0.047, { decay: 1.85 });
  }
  for (let start = 0; start < duration; start += 8) {
    addBass(buffer, start, 7.4, scaleFrequency(0, -1), 0.032);
  }
  addPeriodicDroplets(buffer, duration, 5102, 46, 0.008);
  return finish(buffer, { peak: 0.60, fadeIn: 0.2, fadeOut: 0.2 });
}

// Compose a calm title-screen motif with long pads, plucks, bass, and two chimes.
function makeTitle() {
  const duration = 28;
  const buffer = silence(duration);
  addPadChords(buffer, duration, [[0, 2, 4], [1, 3, 4], [0, 2, 3], [3, 4, 2], [1, 2, 4], [0, 1, 3], [0, 2, 4]], { gain: 0.027 });
  const melody = [
    [0.65, 0, 1, 3.6], [3.25, 2, 1, 3.3], [5.85, 4, 1, 3.8], [8.55, 3, 1, 3.4],
    [11.25, 2, 1, 3.5], [13.75, 1, 1, 3.3], [16.15, 3, 1, 3.7], [18.65, 4, 1, 3.8],
    [21.15, 2, 1, 3.4], [23.65, 1, 1, 3.2], [25.65, 0, 1, 3.0],
  ];
  // Let overlapping plucks sustain the melody while bass marks each seven-second phrase.
  for (const [start, degree, octave, noteDuration] of melody) {
    addPluck(buffer, start, noteDuration, scaleFrequency(degree, octave), 0.098, { decay: 1.6 });
  }
  for (const [start, degree] of [[0, 0], [7, 3], [14, 1], [21, 0]]) {
    addBass(buffer, start, 6.6, scaleFrequency(degree, -1), 0.046);
  }
  addChime(buffer, 9.3, 2.8, scaleFrequency(4, 0), 0.035, 0.45);
  addChime(buffer, 19.4, 3.0, scaleFrequency(3, 0), 0.032, 0.4);
  return finish(buffer, { peak: 0.68, fadeIn: 0.22, fadeOut: 0.22 });
}

// Create a short soil-preparation cue from layered grit, a hand tap, and earth bass.
function makePrepare() {
  const buffer = silence(0.62);
  const random = mulberry32(6001);
  // Stagger two filtered soil layers to suggest breaking and smoothing the ground.
  addNoiseBurst(buffer, 0, 0.24, 0.16, random, {
    lowPass: 1500, highPass: 60, attack: 0.006, release: 0.15, decay: 6,
  });
  addNoiseBurst(buffer, 0.18, 0.26, 0.11, random, {
    lowPass: 2200, highPass: 120, attack: 0.008, release: 0.16, decay: 5,
  });
  addHandPercussion(buffer, 0.02, 0.05, random);
  addBass(buffer, 0.04, 0.28, 98, 0.05);
  return finish(buffer, { peak: 0.62, fadeIn: 0.003, fadeOut: 0.05 });
}

// Pair planting soil and leaf sounds with a quiet three-note sprout response.
function makePlant() {
  const buffer = silence(0.68);
  const random = mulberry32(6101);
  addNoiseBurst(buffer, 0, 0.22, 0.12, random, {
    lowPass: 1350, highPass: 70, attack: 0.007, release: 0.13, decay: 5,
  });
  addLeafRustle(buffer, 0.12, 0.045, random, 0.3);
  // Ascend through root, third, and fifth tones as the new plant appears.
  addChime(buffer, 0.22, 0.3, scaleFrequency(0, 1), 0.11, 0.65);
  addChime(buffer, 0.32, 0.28, scaleFrequency(3, 1), 0.095, 0.65);
  addChime(buffer, 0.41, 0.24, scaleFrequency(4, 1), 0.06, 0.55);
  return finish(buffer, { peak: 0.64, fadeIn: 0.004, fadeOut: 0.05 });
}

// Acknowledge a growth stage with leaf movement, ascending chimes, and warm bass.
function makeGrow() {
  const buffer = silence(0.92);
  const random = mulberry32(6110);
  addLeafRustle(buffer, 0, 0.07, random, 0.42);
  // Overlap three rising tones to make the short cue feel gently celebratory.
  addChime(buffer, 0.14, 0.4, scaleFrequency(0, 1), 0.1, 0.55);
  addChime(buffer, 0.29, 0.42, scaleFrequency(2, 1), 0.095, 0.6);
  addChime(buffer, 0.45, 0.44, scaleFrequency(4, 1), 0.085, 0.65);
  addBass(buffer, 0.18, 0.58, scaleFrequency(0, 0), 0.035);
  return finish(buffer, { peak: 0.62, fadeIn: 0.006, fadeOut: 0.06 });
}

function makeWater() {
  const duration = 1.05;
  const buffer = silence(duration);
  const random = mulberry32(6201);
  let low = 0;
  let slow = 0;
  const lowCoefficient = 1 - Math.exp(-TAU * 3600 / SAMPLE_RATE);
  const slowCoefficient = 1 - Math.exp(-TAU * 420 / SAMPLE_RATE);
  for (let i = 0; i < buffer.length; i += 1) {
    const t = i / SAMPLE_RATE;
    const white = random() * 2 - 1;
    low += lowCoefficient * (white - low);
    slow += slowCoefficient * (white - slow);
    const flow = low - slow;
    const modulation = 0.84 + 0.09 * Math.sin(TAU * 7.3 * t) + 0.05 * Math.sin(TAU * 13.1 * t);
    buffer[i] = flow * 0.19 * modulation * smoothEnvelope(t, duration, 0.04, 0.2);
  }
  for (let i = 0; i < 15; i += 1) {
    const start = 0.04 + random() * 0.88;
    addDroplet(buffer, start, 0.045 + random() * 0.06, 420 + random() * 620,
      0.012 + random() * 0.009, random, 0.66);
  }
  return finish(buffer, { peak: 0.56, fadeIn: 0.006, fadeOut: 0.06 });
}

function makeHarvest() {
  const buffer = silence(1.25);
  const notes = [[0, 0, 0.68], [2, 0.14, 0.66], [3, 0.29, 0.62], [4, 0.45, 0.58], [5, 0.62, 0.52]];
  for (const [degree, start, duration] of notes) {
    addChime(buffer, start, duration, scaleFrequency(degree, 1), 0.12, 0.85);
  }
  for (const degree of [0, 2, 4]) addChime(buffer, 0.66, 0.56, scaleFrequency(degree, 0), 0.04, 0.45);
  return finish(buffer, { peak: 0.70, fadeIn: 0.004, fadeOut: 0.07 });
}

function makeSave() {
  const buffer = silence(0.58);
  addChime(buffer, 0, 0.34, scaleFrequency(2, 1), 0.11, 0.55);
  addChime(buffer, 0.15, 0.4, scaleFrequency(4, 1), 0.095, 0.6);
  addBass(buffer, 0.03, 0.42, scaleFrequency(0, 0), 0.035);
  return finish(buffer, { peak: 0.58, fadeIn: 0.004, fadeOut: 0.05 });
}

function makeClick() {
  const duration = 0.105;
  const buffer = silence(duration);
  const modes = [[560, 36, 0.09], [880, 58, 0.046], [1320, 88, 0.02]];
  for (const [frequency, decay, amplitude] of modes) {
    for (let i = 0; i < buffer.length; i += 1) {
      const t = i / SAMPLE_RATE;
      const envelope = raisedCosineRise(t / 0.002) * raisedCosineRise((duration - t) / 0.045);
      buffer[i] += amplitude * Math.sin(TAU * frequency * t + 0.1) * envelope * Math.exp(-decay * t);
    }
  }
  addNoiseBurst(buffer, 0, 0.035, 0.02, mulberry32(6401), {
    lowPass: 2600, highPass: 200, attack: 0.001, release: 0.022, decay: 34,
  });
  return finish(buffer, { peak: 0.50, fadeIn: 0.001, fadeOut: 0.015 });
}

function makeQuizCorrect() {
  const buffer = silence(0.82);
  addChime(buffer, 0, 0.6, scaleFrequency(0, 1), 0.14, 0.75);
  addChime(buffer, 0.17, 0.54, scaleFrequency(3, 1), 0.12, 0.75);
  addChime(buffer, 0.33, 0.46, scaleFrequency(4, 1), 0.075, 0.6);
  addBass(buffer, 0.02, 0.62, scaleFrequency(0, 0), 0.03);
  return finish(buffer, { peak: 0.66, fadeIn: 0.005, fadeOut: 0.06 });
}

function makeQuizWrong() {
  const buffer = silence(0.5);
  addPluck(buffer, 0, 0.32, scaleFrequency(0, -1), 0.14, { attack: 0.022, release: 0.16, decay: 3.4 });
  addPluck(buffer, 0.18, 0.3, scaleFrequency(3, -2), 0.115, { attack: 0.024, release: 0.16, decay: 3.7 });
  return finish(buffer, { peak: 0.46, fadeIn: 0.008, fadeOut: 0.055 });
}

function makeUnlock() {
  const buffer = silence(1.42);
  const notes = [[0, 0], [1, 0.14], [2, 0.29], [3, 0.45], [4, 0.62], [5, 0.81]];
  for (const [degree, start] of notes) {
    addChime(buffer, start, 0.5 + (5 - degree) * 0.025, scaleFrequency(degree, 1), 0.115, 0.9);
  }
  for (const degree of [0, 2, 4]) addChime(buffer, 0.86, 0.5, scaleFrequency(degree, 0), 0.038, 0.5);
  addBass(buffer, 0.7, 0.66, scaleFrequency(0, -1), 0.04);
  return finish(buffer, { peak: 0.72, fadeIn: 0.005, fadeOut: 0.08 });
}

function makeBirds() {
  const duration = 6.4;
  const buffer = silence(duration);
  const random = mulberry32(6801);
  const calls = [[0.42, 2050], [2.05, 2320], [3.78, 1960], [5.35, 2180]];
  for (const [start, frequency] of calls) {
    addBirdCall(buffer, start, frequency, 0.1, random, 0.18);
    addBirdCall(buffer, start + 0.24, frequency * 1.08, 0.078, random, 0.15);
  }
  return finish(buffer, { peak: 0.48, fadeIn: 0.015, fadeOut: 0.04 });
}

function makeWind() {
  const duration = 8;
  const buffer = periodicNoise(duration, 6901, [
    { count: 28, low: 50, high: 620, gain: 1 },
    { count: 18, low: 560, high: 2800, gain: 0.18 },
  ]);
  for (let i = 0; i < buffer.length; i += 1) {
    const t = i / SAMPLE_RATE;
    buffer[i] *= 0.74 + 0.16 * Math.cos(TAU * t / duration - 0.7) +
      0.07 * Math.cos(2 * TAU * t / duration + 0.4);
    buffer[i] += 0.005 * Math.sin(TAU * Math.round(413 * duration) / duration * t);
  }
  return finish(buffer, { peak: 0.40, fadeIn: 0.1, fadeOut: 0.1 });
}

function makeRainLoop() {
  const duration = 8;
  const buffer = periodicNoise(duration, 6102, [
    { count: 26, low: 100, high: 980, gain: 1 },
    { count: 18, low: 1400, high: 6800, gain: 0.24 },
  ]);
  for (let i = 0; i < buffer.length; i += 1) {
    const movement = 1 + 0.055 * Math.sin(TAU * (i / SAMPLE_RATE) / duration + 0.8);
    buffer[i] *= movement;
  }
  addPeriodicDroplets(buffer, duration, 6103, 15, 0.008);
  return finish(buffer, { peak: 0.46, fadeIn: 0.09, fadeOut: 0.09 });
}

function makeWaterLoop() {
  const duration = 4;
  const buffer = periodicNoise(duration, 6301, [
    { count: 20, low: 120, high: 1120, gain: 1 },
    { count: 14, low: 1100, high: 4800, gain: 0.15 },
  ]);
  for (let i = 0; i < buffer.length; i += 1) {
    const movement = 1 + 0.11 * Math.sin(TAU * (i / SAMPLE_RATE) / duration + 1.2);
    buffer[i] *= movement;
  }
  addPeriodicDroplets(buffer, duration, 6302, 9, 0.005);
  return finish(buffer, { peak: 0.39, fadeIn: 0.08, fadeOut: 0.08 });
}

function makeSteps() {
  const duration = 0.22;
  const buffer = silence(duration);
  for (let i = 0; i < buffer.length; i += 1) {
    const t = i / SAMPLE_RATE;
    const phase = TAU * (132 * t - 118 * t * t);
    const envelope = raisedCosineRise(t / 0.006) * raisedCosineRise((duration - t) / 0.1) * Math.exp(-13 * t);
    buffer[i] = 0.13 * Math.sin(phase) * envelope + 0.03 * Math.sin(phase * 1.8) * envelope;
  }
  addNoiseBurst(buffer, 0, 0.12, 0.052, mulberry32(6151), {
    lowPass: 1150, highPass: 65, attack: 0.003, release: 0.075, decay: 16,
  });
  return finish(buffer, { peak: 0.45, fadeIn: 0.003, fadeOut: 0.05 });
}

const USER_MUSIC = [
  { file: 'music_title.mp3', source: 'Garden Air at Night.mp3', purpose: 'Title screen and evening menu' },
  { file: 'music_garden.mp3', source: 'Morning in the Persian Garden.mp3', purpose: 'Garden, memorial garden and city exploration' },
  { file: 'music_rain.mp3', source: 'Garden Night.mp3', purpose: 'Rainy weather and night scenes' },
  { file: 'music_path.mp3', source: 'Morning Garden Path.mp3', purpose: 'School and neighborhood park paths' },
];

const CLIPS = [
  {
    file: 'sfx_prepare.wav', duration: 0.62, loop: false, purpose: 'Breaking and smoothing garden soil',
    parameters: 'Two filtered-noise soil layers; muted 174 Hz hand tap; rounded 98 Hz earth body',
    generate: makePrepare,
  },
  {
    file: 'sfx_plant.wav', duration: 0.68, loop: false, purpose: 'Planting a seed with a soft sprout response',
    parameters: 'Filtered soil disturbance; two leaf-rustle layers; three rising rounded sine chimes',
    generate: makePlant,
  },
  {
    file: 'sfx_grow.wav', duration: 0.92, loop: false, purpose: 'Acknowledging a plant growth stage',
    parameters: 'Layered leaf rustle; three ascending chimes; warm root bass',
    generate: makeGrow,
  },
  {
    file: 'sfx_water.wav', duration: 1.05, loop: false, purpose: 'Gentle watering-can pour',
    parameters: '360–3600 Hz flowing noise with amplitude ripple; 15 short descending bubble chirps',
    generate: makeWater,
  },
  {
    file: 'sfx_harvest.wav', duration: 1.25, loop: false, purpose: 'Ascending harvest reward',
    parameters: 'Five ascending scale chimes with rounded partials and a warm three-note final chord',
    generate: makeHarvest,
  },
  {
    file: 'sfx_save.wav', duration: 0.58, loop: false, purpose: 'Quiet successful-save confirmation',
    parameters: 'Two overlapping rounded chimes and a warm root bass',
    generate: makeSave,
  },
  {
    file: 'sfx_click.wav', duration: 0.105, loop: false, purpose: 'Gentle wooden UI feedback',
    parameters: 'Three damped wooden modes at 560, 880 and 1320 Hz plus a short filtered-noise grain',
    generate: makeClick,
  },
  {
    file: 'sfx_quiz_correct.wav', duration: 0.82, loop: false, purpose: 'Warm, encouraging correct-answer chime',
    parameters: 'Three overlapping rounded chimes on root, fifth and upper scale tone with soft root bass',
    generate: makeQuizCorrect,
  },
  {
    file: 'sfx_quiz_wrong.wav', duration: 0.5, loop: false, purpose: 'Gentle non-punitive incorrect-answer tone',
    parameters: 'Two soft descending plucked tones (D3 to A2), long attacks and no buzzer or error transient',
    generate: makeQuizWrong,
  },
  {
    file: 'sfx_unlock.wav', duration: 1.42, loop: false, purpose: 'Bright chapter-unlock flourish',
    parameters: 'Six-note ascending scale flourish, rounded bell partials, final chord and warm bass',
    generate: makeUnlock,
  },
  {
    file: 'sfx_birds.wav', duration: 6.4, loop: false, purpose: 'Occasional distant bird calls with quiet gaps',
    parameters: 'Four original two-syllable chirps; sine glides and 17 Hz micro-vibrato; silence between calls',
    generate: makeBirds,
  },
  {
    file: 'sfx_wind.wav', duration: 8, loop: true, purpose: 'Gentle outdoor wind bed',
    parameters: 'Periodic 50–2800 Hz colored noise; slow gust modulation; quiet 413 Hz air tone',
    generate: makeWind,
  },
  {
    file: 'sfx_rain.wav', duration: 8, loop: true, purpose: 'Light rain ambience',
    parameters: 'Periodic 100–6800 Hz colored noise, slow modulation and 15 soft droplets',
    generate: makeRainLoop,
  },
  {
    file: 'sfx_water_loop.wav', duration: 4, loop: true, purpose: 'Subtle flowing-water ambience',
    parameters: 'Periodic 120–4800 Hz colored noise, gentle movement and nine bubbles',
    generate: makeWaterLoop,
  },
  {
    file: 'sfx_steps.wav', duration: 0.22, loop: false, purpose: 'Soft footstep on garden soil',
    parameters: 'Rounded 132-to-approximately-14 Hz body sweep plus quiet 65–1150 Hz soil grit',
    generate: makeSteps,
  },
];

function writeWav(filePath, samples) {
  const dataBytes = samples.length * 2;
  const wav = Buffer.alloc(HEADER_BYTES + dataBytes);
  wav.write('RIFF', 0, 'ascii');
  wav.writeUInt32LE(36 + dataBytes, 4);
  wav.write('WAVE', 8, 'ascii');
  wav.write('fmt ', 12, 'ascii');
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20); // PCM
  wav.writeUInt16LE(1, 22); // Mono
  wav.writeUInt32LE(SAMPLE_RATE, 24);
  wav.writeUInt32LE(SAMPLE_RATE * 2, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write('data', 36, 'ascii');
  wav.writeUInt32LE(dataBytes, 40);
  for (let i = 0; i < samples.length; i += 1) {
    const clamped = Math.max(-1, Math.min(1, samples[i]));
    wav.writeInt16LE(Math.round(clamped * 32767), HEADER_BYTES + i * 2);
  }
  fs.writeFileSync(filePath, wav);
}

function validateWav(filePath, clip) {
  const wav = fs.readFileSync(filePath);
  const expectedFrames = frames(clip.duration);
  const expectedSize = HEADER_BYTES + expectedFrames * 2;
  const checks = [
    [wav.length >= HEADER_BYTES, 'file is shorter than a WAV header'],
    [wav.toString('ascii', 0, 4) === 'RIFF', 'missing RIFF signature'],
    [wav.toString('ascii', 8, 12) === 'WAVE', 'missing WAVE signature'],
    [wav.readUInt32LE(4) === wav.length - 8, 'RIFF size does not match file size'],
    [wav.toString('ascii', 12, 16) === 'fmt ', 'missing fmt chunk'],
    [wav.readUInt32LE(16) === 16, 'fmt chunk is not 16 bytes'],
    [wav.readUInt16LE(20) === 1, 'encoding is not integer PCM'],
    [wav.readUInt16LE(22) === 1, 'audio is not mono'],
    [wav.readUInt32LE(24) === SAMPLE_RATE, 'sample rate is not 32000 Hz'],
    [wav.readUInt32LE(28) === SAMPLE_RATE * 2, 'byte rate is incorrect'],
    [wav.readUInt16LE(32) === 2, 'block alignment is incorrect'],
    [wav.readUInt16LE(34) === 16, 'bit depth is not 16'],
    [wav.toString('ascii', 36, 40) === 'data', 'missing data chunk'],
    [wav.readUInt32LE(40) === expectedFrames * 2, 'data size does not match duration'],
    [wav.length === expectedSize, 'total file size does not match 44-byte header plus PCM data'],
  ];
  for (const [passed, message] of checks) {
    if (!passed) throw new Error(`${clip.file}: ${message}`);
  }
  let peak = 0;
  let sumSquares = 0;
  let first = 0;
  let last = 0;
  for (let i = 0; i < expectedFrames; i += 1) {
    const sample = wav.readInt16LE(HEADER_BYTES + i * 2);
    const normalized = sample / 32768;
    peak = Math.max(peak, Math.abs(normalized));
    sumSquares += normalized * normalized;
    if (i === 0) first = normalized;
    if (i === expectedFrames - 1) last = normalized;
  }
  if (peak > 0.75) throw new Error(`${clip.file}: peak exceeds the -2.5 dBFS safety ceiling`);
  if (first !== 0 || last !== 0) throw new Error(`${clip.file}: endpoints are not silent`);
  if (clip.loop && Math.abs(first - last) > 1 / 32768) throw new Error(`${clip.file}: loop seam jumps`);
  return {
    bytes: wav.length,
    samples: expectedFrames,
    peakDb: 20 * Math.log10(peak),
    rmsDb: 10 * Math.log10(Math.sqrt(sumSquares / expectedFrames)),
  };
}

function formatDb(value) {
  return `${value.toFixed(1)} dBFS`;
}

function writeManifest(results) {
  const totalBytes = results.reduce((sum, result) => sum + result.bytes, 0);
  const rows = CLIPS.map((clip, index) => {
    const result = results[index];
    return `| \`${clip.file}\` | ${clip.duration.toFixed(2)} s | ${result.samples.toLocaleString('en-US')} | ${clip.loop ? 'Yes' : 'No'} | ${clip.purpose} | ${clip.parameters} | ${result.bytes.toLocaleString('en-US')} | ${formatDb(result.peakDb)} / ${formatDb(result.rmsDb)} |`;
  }).join('\n');
  const musicRows = USER_MUSIC.map((music) => {
    const musicPath = path.join(OUTPUT_DIR, music.file);
    const bytes = fs.existsSync(musicPath) ? fs.statSync(musicPath).size.toLocaleString('en-US') : 'missing';
    return `| \`${music.file}\` | \`${music.source}\` | ${music.purpose} | ${bytes} |`;
  }).join('\n');
  const musicBytes = USER_MUSIC.reduce((sum, music) => {
    const musicPath = path.join(OUTPUT_DIR, music.file);
    return sum + (fs.existsSync(musicPath) ? fs.statSync(musicPath).size : 0);
  }, 0);
  const manifest = `# Roots of Sacrifice — Audio Manifest

## Provenance

The sound effects are procedurally generated for **Roots of Sacrifice** by \`tools/generate_audio.mjs\`, using original compositions and pure Node.js mathematics. The four music tracks were supplied by the project owner and are used in the game with their permission; they are not claimed as original compositions of this project.

The generated sound-effect palette uses a five-note, pentatonic-like set built from just ratios (1, 16/15, 4/3, 3/2, 9/5) around D. The neutral second and warm just-intonation color provide a gentle Persian-inspired quality; the motifs are original and are not transcriptions of traditional melodies.

## Global format and synthesis

- Sound-effect container: WAV, canonical 44-byte RIFF/WAVE header, 16-bit signed integer PCM, mono.
- Sound-effect sample rate: **32,000 Hz**; byte rate: 64,000 bytes/s; block alignment: 2 bytes.
- Music container: MP3 files supplied by the project owner; Godot imports them as AudioStreamMP3 and loops them at runtime.
- Deterministic sound-effect synthesis: seeded noise, integer-cycle periodic noise, additive plucks/chimes, filtered noise, sine droplets/chirps, and rounded modal percussion.
- Generated clips have zero-valued first and last PCM samples. Loop clips use short raised-cosine fade-in/out to prevent boundary clicks. Event tails wrap where appropriate.
- Generated levels are normalized per clip, with measured peaks at or below approximately -2.5 dBFS. No external DSP libraries, samples, or dependencies are required.
- Godot 4: enable **Loop** on the generated WAV files marked below and on all four user-supplied music tracks; leave one-shots unlooped.

## Files and measured validation

Durations and file sizes are exact; PCM sample counts are at 32,000 Hz. Levels show peak / RMS.

| File | Duration | Samples | Loop | Purpose | Synthesis parameters | Bytes | Peak / RMS |
| --- | ---: | ---: | :---: | --- | --- | ---: | ---: |
${rows}

## User-supplied music

These four MP3 files replace the former procedurally generated music loops. They are preserved by the generator and are not regenerated.

| Game file | Original supplied file | Use in game | Bytes |
| --- | --- | --- | ---: |
${musicRows}

## Validation and regeneration

The generator re-reads every generated WAV and checks RIFF/WAVE signatures, PCM format, mono channel count, 32,000 Hz sample rate, 16-bit depth, byte rate, block alignment, data length, exact total file size, duration, non-clipping levels, silent endpoints, and loop-seam continuity. User-supplied MP3 files are left untouched. A failed check stops generation with an error.

Regenerate from the project root with:

\`\`\`sh
node tools/generate_audio.mjs
\`\`\`

Generated WAV payload: **${(totalBytes / (1024 * 1024)).toFixed(2)} MiB** across **${CLIPS.length} files**. User-supplied music payload: **${(musicBytes / (1024 * 1024)).toFixed(2)} MiB** across **${USER_MUSIC.length} MP3 files**. This manifest is generated alongside the sound effects and records the preserved music inventory.
`;
  fs.writeFileSync(path.join(OUTPUT_DIR, 'AUDIO_MANIFEST.md'), manifest, 'utf8');
  return totalBytes;
}

function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const results = [];
  for (const clip of CLIPS) {
    const samples = clip.generate();
    if (samples.length !== frames(clip.duration)) {
      throw new Error(`${clip.file}: generated ${samples.length} frames, expected ${frames(clip.duration)}`);
    }
    const filePath = path.join(OUTPUT_DIR, clip.file);
    writeWav(filePath, samples);
    const result = validateWav(filePath, clip);
    results.push(result);
    console.log(`OK ${clip.file.padEnd(21)} ${clip.duration.toFixed(2).padStart(5)} s  ${String(result.bytes).padStart(8)} bytes  peak ${formatDb(result.peakDb)}  RMS ${formatDb(result.rmsDb)}`);
  }
  const totalBytes = writeManifest(results);
  console.log(`Validated ${CLIPS.length} WAVs; total ${(totalBytes / (1024 * 1024)).toFixed(2)} MiB.`);
  console.log(`Manifest: ${path.join(OUTPUT_DIR, 'AUDIO_MANIFEST.md')}`);
}

main();
