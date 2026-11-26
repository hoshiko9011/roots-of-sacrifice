# Roots of Sacrifice — Audio Manifest

## Provenance

The sound effects are procedurally generated for **Roots of Sacrifice** by `tools/generate_audio.mjs`, using original compositions and pure Node.js mathematics. The four music tracks were supplied by the project owner and are used in the game with their permission; they are not claimed as original compositions of this project.

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
| `sfx_prepare.wav` | 0.62 s | 19,840 | No | Breaking and smoothing garden soil | Two filtered-noise soil layers; muted 174 Hz hand tap; rounded 98 Hz earth body | 39,724 | -4.2 dBFS / -8.8 dBFS |
| `sfx_plant.wav` | 0.68 s | 21,760 | No | Planting a seed with a soft sprout response | Filtered soil disturbance; two leaf-rustle layers; three rising rounded sine chimes | 43,564 | -3.9 dBFS / -7.5 dBFS |
| `sfx_grow.wav` | 0.92 s | 29,440 | No | Acknowledging a plant growth stage | Layered leaf rustle; three ascending chimes; warm root bass | 58,924 | -4.2 dBFS / -7.5 dBFS |
| `sfx_water.wav` | 1.05 s | 33,600 | No | Gentle watering-can pour | 360–3600 Hz flowing noise with amplitude ripple; 15 short descending bubble chirps | 67,244 | -5.0 dBFS / -7.9 dBFS |
| `sfx_harvest.wav` | 1.25 s | 40,000 | No | Ascending harvest reward | Five ascending scale chimes with rounded partials and a warm three-note final chord | 80,044 | -3.1 dBFS / -7.6 dBFS |
| `sfx_save.wav` | 0.58 s | 18,560 | No | Quiet successful-save confirmation | Two overlapping rounded chimes and a warm root bass | 37,164 | -4.7 dBFS / -7.9 dBFS |
| `sfx_click.wav` | 0.10 s | 3,360 | No | Gentle wooden UI feedback | Three damped wooden modes at 560, 880 and 1320 Hz plus a short filtered-noise grain | 6,764 | -6.0 dBFS / -10.0 dBFS |
| `sfx_quiz_correct.wav` | 0.82 s | 26,240 | No | Warm, encouraging correct-answer chime | Three overlapping rounded chimes on root, fifth and upper scale tone with soft root bass | 52,524 | -3.6 dBFS / -7.2 dBFS |
| `sfx_quiz_wrong.wav` | 0.50 s | 16,000 | No | Gentle non-punitive incorrect-answer tone | Two soft descending plucked tones (D3 to A2), long attacks and no buzzer or error transient | 32,044 | -6.7 dBFS / -7.9 dBFS |
| `sfx_unlock.wav` | 1.42 s | 45,440 | No | Bright chapter-unlock flourish | Six-note ascending scale flourish, rounded bell partials, final chord and warm bass | 90,924 | -2.9 dBFS / -7.1 dBFS |
| `sfx_birds.wav` | 6.40 s | 204,800 | No | Occasional distant bird calls with quiet gaps | Four original two-syllable chirps; sine glides and 17 Hz micro-vibrato; silence between calls | 409,644 | -6.4 dBFS / -9.5 dBFS |
| `sfx_wind.wav` | 8.00 s | 256,000 | Yes | Gentle outdoor wind bed | Periodic 50–2800 Hz colored noise; slow gust modulation; quiet 413 Hz air tone | 512,044 | -8.0 dBFS / -9.5 dBFS |
| `sfx_rain.wav` | 8.00 s | 256,000 | Yes | Light rain ambience | Periodic 100–6800 Hz colored noise, slow modulation and 15 soft droplets | 512,044 | -6.7 dBFS / -8.6 dBFS |
| `sfx_water_loop.wav` | 4.00 s | 128,000 | Yes | Subtle flowing-water ambience | Periodic 120–4800 Hz colored noise, gentle movement and nine bubbles | 256,044 | -8.2 dBFS / -8.8 dBFS |
| `sfx_steps.wav` | 0.22 s | 7,040 | No | Soft footstep on garden soil | Rounded 132-to-approximately-14 Hz body sweep plus quiet 65–1150 Hz soil grit | 14,124 | -6.9 dBFS / -9.6 dBFS |

## User-supplied music

These four MP3 files replace the former procedurally generated music loops. They are preserved by the generator and are not regenerated.

| Game file | Original supplied file | Use in game | Bytes |
| --- | --- | --- | ---: |
| `music_title.mp3` | `Garden Air at Night.mp3` | Title screen and evening menu | 3,523,398 |
| `music_garden.mp3` | `Morning in the Persian Garden.mp3` | Garden, memorial garden and city exploration | 3,597,339 |
| `music_rain.mp3` | `Garden Night.mp3` | Rainy weather and night scenes | 3,557,297 |
| `music_path.mp3` | `Morning Garden Path.mp3` | School and neighborhood park paths | 4,544,839 |

## Validation and regeneration

The generator re-reads every generated WAV and checks RIFF/WAVE signatures, PCM format, mono channel count, 32,000 Hz sample rate, 16-bit depth, byte rate, block alignment, data length, exact total file size, duration, non-clipping levels, silent endpoints, and loop-seam continuity. User-supplied MP3 files are left untouched. A failed check stops generation with an error.

Regenerate from the project root with:

```sh
node tools/generate_audio.mjs
```

Generated WAV payload: **2.11 MiB** across **15 files**. User-supplied music payload: **14.52 MiB** across **4 MP3 files**. This manifest is generated alongside the sound effects and records the preserved music inventory.
