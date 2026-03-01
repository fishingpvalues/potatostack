# Tuning Procedure — Onkyo TX-SR605 + YST-FSW050 + Fluance ES1
## Complete ordered setup — manual calibration (no Audyssey mic)

Do every step in order. Do not skip ahead.

---

## Phase 0 — Before You Connect Anything

### 0.1 — Speaker placement

The Fluance ES1 is a rear-ported tower. It needs room to breathe.

```
Minimum clearances:
  From front wall (wall behind speakers): 30–60 cm
  From side walls:                        60 cm minimum
  Between tweeters:                       1.8–2.5 m (measure this — note it down)
```

Place them symmetrically. Measure the distance from each tweeter to the centre of
the listening position — they should be equal to within 2 cm.

**Toe-in:** the ES1 has a measured 3–6 dB treble brightness. Start with **minimal
toe-in** (speakers nearly parallel or angled just 5–10° inward). Add more later if
you want a tighter centre image, but it also increases perceived treble.

**On carpet:** place a rigid MDF or granite board (30×30 cm, ≥12 mm thick) under
each speaker. Decouples the cabinet from carpet, prevents rocking, tightens bass.

### 0.2 — Subwoofer placement (do this before connecting cables)

**The subwoofer crawl — definitive placement:**

1. Place the sub at your exact listening position (on the sofa seat)
2. Play music with repeated bass in the 40–80 Hz range at moderate volume
3. Crawl slowly along the front wall and side walls, ear at floor level
4. Stop where bass sounds **loudest, fullest, most even** without obvious peaks
5. That position is where the sub goes

**Good positions:** front wall between the two ES1 towers (most integrated), or
front corner (more output but can sound boomy). Avoid behind the listening position
and inside cabinets.

**Down-firing clearance:** at least 10 cm of open floor below the driver.

---

## Phase 1 — Physical Connections

### 1.1 — Speaker cables

```
Onkyo FRONT L  →  Fluance ES1 Left
Onkyo FRONT R  →  Fluance ES1 Right
```

Minimum 16 AWG for runs up to 5 m. 14 AWG for longer.

**Polarity check — do before anything else:**

Quick battery test: touch + wire of a 1.5V AA to the red (+) binding post and −
wire to black (−). Woofer cone should push **outward**. If it pushes inward, your
wire is reversed — swap at the speaker end. Repeat for both speakers.

Or after connecting: play mono audio (a podcast). The voice should appear as a
solid, centred point between the speakers. If it seems hollow or surrounds you →
one cable is reversed in polarity.

### 1.2 — Subwoofer cable

```
Onkyo SUBWOOFER PRE OUT  →  RCA cable (single, mono)  →  YST-FSW050 LINE IN
```

### 1.3 — Le Potato audio connection

```
Option A (HDMI):    Le Potato HDMI out  →  Onkyo HDMI IN 1
Option B (optical): Le Potato 9J1 TOSLINK  →  Onkyo OPTICAL IN 1 or 2
```

Both carry identical digital PCM — no audible difference for stereo.

### 1.4 — Power on sequence

1. Onkyo TX-SR605
2. Yamaha YST-FSW050 (rear power switch)
3. Le Potato (Docker stack already running)

The YST-FSW050 has **no auto-on** — switch it on manually every session.

---

## Phase 2 — Subwoofer Physical Controls

Set these on the sub itself before touching the Onkyo.

### 2.1 — Crossover knob

```
Set to: MAXIMUM (fully clockwise)
```

The Onkyo controls the crossover via bass management. The sub's internal knob
would add a second filter on top, causing extra phase shift. Leave it at max.

### 2.2 — Volume knob

```
Set to: 50% (midpoint) for now
```

You will fine-tune this in Phase 6 after all receiver settings are done.

### 2.3 — Phase switch

```
Set to: 0° for now
```

You will calibrate this by ear in Phase 7.

---

## Phase 3 — Manual Speaker Setup on the Onkyo

Since there is no Audyssey mic, configure everything manually.
Navigate: `Remote → SETUP → Manual Setup → Speaker Setup`

### 3.1 — Speaker sizes

```
Front L / R (Fluance ES1):  Small
Center:                     None
Surround L / R:             None
Subwoofer:                  Yes
```

**Why Small for a floor-stander?** "Large" tells the Onkyo the speaker is full-range
and sends all bass to it, bypassing the sub for stereo signals. The ES1 rolls off
significantly before 100 Hz despite its size. Setting Small routes bass below the
crossover to the sub — cleaner output, no ES1 distortion in the bass range.

### 3.2 — Crossover frequency

```
Front speakers (ES1):  80 Hz
```

The THX standard crossover. The YST-FSW050 handles 35–160 Hz cleanly, and 80 Hz
is within both drivers' overlap range. If bass sounds disconnected after tuning,
try 100 Hz.

### 3.3 — LPF for LFE

```
SETUP → Manual Setup → Speaker Setup → LPF for LFE
Set to: 120 Hz
```

Maximum sub frequency for the LFE channel. 120 Hz = Dolby standard. Leave here.

### 3.4 — Speaker distances

Measure the actual distance from each speaker to your listening position with a
tape measure. Enter the values in:

```
SETUP → Manual Setup → Speaker Setup → Distance

Front L:    ___ m  (tape measure: your tweeter → your ear position)
Front R:    ___ m  (should be the same as Front L if placed symmetrically)
Subwoofer:  ___ m  (tape measure: sub driver → your ear position)
```

**Sub distance matters for phase alignment.** Measure from the sub's driver (the
cone, not the cabinet face) to your listening position.

### 3.5 — Speaker levels (manual calibration)

#### With a smartphone SPL meter app (most accurate):

Apps: NIOSH SLM (iOS, free, NIST-validated), Decibel X, or any free SPL meter.
Set meter to: **C-weighting, Slow response**.

```
SETUP → Manual Setup → Test Tone
```

The Onkyo plays pink noise through each channel in turn.

1. Set master volume so Front L reads **75 dB** on the meter at your listening seat
2. Note that level — this is your calibration volume, use it for all channels
3. Navigate to Front R test tone → adjust `SETUP → Levels → Front R` until meter
   reads 75 dB
4. Navigate to Subwoofer test tone → adjust `SETUP → Levels → Subwoofer` until
   meter reads 75 dB
5. Done — all channels are matched at the 75 dB SPL reference level

#### Without SPL meter (by ear):

1. `SETUP → Manual Setup → Test Tone → Front L` — note the pink noise volume
2. Switch to Front R — adjust `Levels → Front R` until it sounds the same loudness
3. Switch to Subwoofer — adjust `Levels → Subwoofer` until it sounds the same
   loudness as the front channels

**Starting point for subwoofer level:** 0 dB. Fine-tune in Phase 6 with music.

---

## Phase 4 — Listening Mode

```
Press LISTENING MODE on remote → select: DIRECT
```

**Mode comparison for this setup:**

| Mode | Bass management | Room EQ | Sub works for stereo |
|---|---|---|---|
| Pure Audio | OFF | OFF | NO — sub silent |
| Direct | ON | OFF | YES |
| Stereo | ON | ON (none without mic) | YES |

Without Audyssey, there is **no room EQ stored** in either Direct or Stereo mode —
both modes sound the same for EQ. The difference is only the signal processing chain.

**Use Direct for all music.** It keeps bass management active (sub works), has a
clean signal path, and since there is no Audyssey EQ to speak of, there is no
reason to use Stereo over Direct.

---

## Phase 5 — Turn Off All DSP

Navigate: `Remote → SETUP → Audio Adjust`

```
Audyssey Dynamic EQ:    OFF
Audyssey Dynamic Vol:   OFF
Re-EQ:                  OFF
Late Night:             OFF
```

Without an Audyssey calibration, Dynamic EQ has no valid calibration reference
and will distort the frequency balance. All these options add processing you do
not want. Turn them all off.

---

## Phase 6 — Subwoofer Level Fine-Tuning (With Music)

Use music you know well with steady, repeated bass (bass guitar, kick drum,
electronic bassline). Play it at your normal listening volume in **Direct** mode.

Navigate: `SETUP → Manual Setup → Levels → Subwoofer`

Adjust in 0.5 dB steps until:
- You cannot locate the subwoofer by listening — bass seems to come from the
  Fluance ES1 towers, not from the box in the corner
- Bass is present and full but not dominant
- You feel it in the room without hearing it as a separate "woof"

**Common mistake:** sub too loud. If you can point to where the sub is, reduce
by 2–3 dB. The goal is seamless integration, not more bass.

Write down your result: `Sub level: ___ dB`

---

## Phase 7 — Subwoofer Phase Calibration

Phase determines whether the sub reinforces or cancels the ES1's bass output at
the crossover frequency (80 Hz). Wrong phase = thin, weak bass.

**Procedure:**

1. Play bass-heavy music in **Direct** mode at moderate volume
2. Sit at your listening position
3. Toggle the **phase switch on the YST-FSW050** between 0° and 180°
4. Wait 5–10 seconds in each position
5. Choose the position where bass sounds **louder, fuller, more present**

That is the correct phase.

**Typical result:** 0° for subs placed near the front wall. 180° sometimes correct
when the sub is to the side of or behind the listening position.

Write down your result: `Phase: ___ °`

---

## Phase 8 — Treble Adjustment (Optional)

The ES1 tweeter has a measured 3–6 dB peak above the midrange. If treble sounds
harsh, bright, or fatiguing:

Tone controls are only active in **Stereo** mode. If you want them:

```
SETUP → Audio Adjust → Treble → −2 dB
SETUP → Audio Adjust → Bass   →  0 dB
```

In **Direct** mode, tone controls are bypassed. Direct mode is recommended.

**Alternative to tone controls in Direct:** reduce ES1 toe-in (angle them slightly
away from you). Less direct tweeter energy on-axis softens the perceived brightness
without touching any EQ settings.

---

## Phase 9 — Signal Verification

Start playback from Le Potato and check the Onkyo's front display.

```
Expected during FLAC playback (MPD):     PCM 44.1K
Expected during Apple Music (AirPlay 2): PCM 48K
Expected during hi-res FLAC (96 kHz):   PCM 96K

Wrong:   DD, DTS, or NO SIGNAL
```

If showing DD or DTS: Le Potato ALSA is sending compressed passthrough instead of
decoded PCM. Check `/etc/asound.conf` on Le Potato, restart containers.

If showing NO SIGNAL on optical:
- `sudo ldto status | grep spdif` — check SPDIF overlay active
- `amixer sset "AIU SPDIF SRC SEL" I2S` — route ALSA to SPDIF
- TOSLINK cable must click in fully

---

## Phase 10 — Verification Tests

**Test 1 — sub is actually contributing:**
1. Play bass music in Direct mode at normal volume
2. Temporarily reduce `Levels → Subwoofer` to −10 dB
3. Note how the sound changes (bass should get thinner and less powerful)
4. Restore to your calibrated level
5. If you cannot hear a difference: sub placement may be in a bass null, or phase
   cancellation — redo Phase 2 (sub crawl) and Phase 7

**Test 2 — polarity correct:**
1. Play spoken-word audio (podcast) in Direct mode
2. Voice should appear as a solid, focused point between the two speakers
3. If voice seems to surround you or has no fixed position → one cable is reversed

**Test 3 — tactile check:**
1. Play bass-heavy music at normal volume
2. Hand flat on the floor near the sub → feel vibration (sub working)
3. Hand near the base of an ES1 → feel vibration above 80 Hz (ES1 working above crossover)
4. If only the sub vibrates: crossover may be too high, or ES1 polarity issue

---

## Complete Settings Reference

```
SETUP → Manual Setup → Speaker Setup:
  Front L / R:           Small
  Crossover:             80 Hz
  Subwoofer:             Yes
  LPF for LFE:           120 Hz
  Center:                None
  Surround:              None

SETUP → Manual Setup → Distance:
  Front L:               ___ m
  Front R:               ___ m
  Subwoofer:             ___ m

SETUP → Manual Setup → Levels:
  Front L:               0 dB (adjust if one speaker seems louder than the other)
  Front R:               0 dB
  Subwoofer:             ___ dB (from Phase 6)

SETUP → Audio Adjust:
  Dynamic EQ:            OFF
  Dynamic Vol:           OFF
  Re-EQ:                 OFF
  Late Night:            OFF
  Treble:                0 dB (or −2 dB in Stereo mode if ES1 is bright)
  Bass:                  0 dB

Listening mode:          DIRECT (all music)

Subwoofer physical:
  Volume knob:           50% (don't touch after setting)
  Phase:                 ___ ° (from Phase 7)
  Crossover knob:        MAX
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────┐
│  ONKYO TX-SR605 — DAILY SETTINGS                    │
├─────────────────────────────────────────────────────┤
│  Listening mode:             DIRECT                 │
│  Speaker size:               SMALL                  │
│  Crossover:                  80 Hz                  │
│  LPF for LFE:                120 Hz                 │
│  Sub level:                  ___ dB (your value)    │
│  Dynamic EQ:                 OFF                    │
│  Re-EQ:                      OFF                    │
│  Late Night:                 OFF                    │
├─────────────────────────────────────────────────────┤
│  SUBWOOFER (YST-FSW050)                             │
│  Volume knob:                50% (set once)         │
│  Phase:                      ___ ° (your value)     │
│  Crossover knob:             MAX                    │
│  Power:                      ON (manual)            │
├─────────────────────────────────────────────────────┤
│  DISPLAY SHOULD SHOW                                │
│  FLAC via MPD:               PCM 44.1K              │
│  Apple Music (AirPlay 2):    PCM 48K                │
│  Hi-res FLAC:                PCM 96K                │
└─────────────────────────────────────────────────────┘
```
