# Onkyo TX-SR605 — Complete Setup Guide
## For: Yamaha YST-FSW050 + Fluance ES1 + Le Potato Audio Stack

---

## Your Hardware at a Glance

### Onkyo TX-SR605
| Spec | Value |
|---|---|
| Channels | 7.1 |
| Power | 100W × 7 (6Ω), 85W × 7 (8Ω) |
| Room correction | Audyssey 2EQ (entry-level, 1 measurement point) |
| Crossover options | Full Band, 40 / 50 / 60 / **80** / 100 / 120 / 150 / 200 Hz |
| LPF for LFE | 40–120 Hz |
| HDMI | 1.3a — 3 in / 1 out, passes PCM audio |
| Digital inputs | 2× optical (TOSLINK), 2× coaxial |
| Video circuits | Active in all modes **except** Pure Audio |

### Fluance ES1 (your "speakers")
> **Note:** The ES1 is a **floorstanding tower**, not a bookshelf — 51 inches tall, four 5-inch woofers + 1-inch silk dome tweeter.

| Spec | Value |
|---|---|
| Type | 2-way floorstanding tower |
| Drivers | 4× 5" woven fiberglass woofer + 1" silk dome tweeter |
| Internal crossover | 3,500 Hz (woofer → tweeter) |
| Rated frequency response | 72 Hz – 20 kHz |
| Actual usable bass | Rolls off significantly above 100 Hz — **subwoofer is not optional** |
| Sensitivity | 87.6 dB measured (Audioholics) — 90 dB rated |
| Impedance | 8 Ω nominal, 6.4 Ω minimum — easy load for any amp |
| Power handling | 40–160 W recommended |
| Known quirk | Brightness peak in treble — tweeter is forward/bright sounding. Audyssey helps tame this. |

### Yamaha YST-FSW050
| Spec | Value |
|---|---|
| Type | Powered subwoofer, down-firing, compact |
| Driver | 6.5" reinforced multi-range cone |
| Power | 100 W dynamic |
| Frequency response | 35–160 Hz |
| Technology | Advanced YST II (Active Servo Technology) + QD-Bass + Linear Port |
| Controls | Volume knob, Phase switch (0°/180°), Power switch |
| Auto power | **No auto-on** — must be switched on manually or left on |
| Dimensions | 13¾" × 6⁷⁄₁₆" × 13¾" (W × H × D) |
| Weight | 8.5 kg / 18.7 lbs |

---

## Critical Facts Before You Start

**1. The ES1 needs a subwoofer.** The Audioholics review is explicit: *"this loudspeaker requires a subwoofer for music."* Its four 5-inch woofers roll off before 100 Hz in real conditions. Without the sub working, your music has no bass.

**2. Pure Audio mode silences your subwoofer for stereo music.** Pure Audio is often recommended for lossless listening but on the TX-SR605 it disables bass management entirely — the sub only receives the LFE (.1) channel. Stereo music has no LFE channel. **Result: sub is silent in Pure Audio with stereo sources.** Use **Direct mode** instead (explained below).

**3. Audyssey 2EQ on the 605 sets crossovers too high for the ES1.** Independent testing shows Audyssey can set the ES1's crossover as high as 150 Hz automatically because it correctly measures the speaker's weak bass. After running Audyssey you must manually lower the crossover to 80 Hz.

**4. The ES1 tweeter is bright.** Measurements show a consistent 3–6 dB treble rise above the midrange. At loud volumes this can cause listening fatigue. The Audyssey EQ curve helps — do NOT use Pure Audio if this bothers you. Direct mode keeps the Audyssey correction active.

---

## Part 1 — Physical Connections

### Speaker Wiring

```
Onkyo FRONT L (red/black) ──── Fluance ES1 Left  (match +/- polarity)
Onkyo FRONT R (red/black) ──── Fluance ES1 Right (match +/- polarity)
```

**Wire gauge:** Use at least 16 AWG for runs under 5m. 14 AWG for longer. Thinner wire adds resistance and reduces damping factor — audible in the bass.

**Polarity is critical:** Red (+) to red (+), black (−) to black (−). Reversed polarity on one speaker cancels bass and shifts the stereo image. After wiring, play mono music (a podcast) and the centre image should be solid and centred. If it seems hollow or diffuse, check polarity.

### Subwoofer Connection

```
Onkyo SUBWOOFER PRE OUT ──── RCA cable ──── Yamaha YST-FSW050 LINE IN
```

Use a single RCA cable (sub is mono). The Onkyo has one dedicated sub pre-out jack — this is line-level signal. Do NOT connect to the speaker-level inputs on the sub.

### Le Potato Audio Connection — Pick One

```
Option A (HDMI):    Le Potato HDMI ──────────── Onkyo HDMI IN 1
Option B (optical): Le Potato 9J1 TOSLINK ────── Onkyo OPTICAL IN 1
```

See `TUTORIAL.md` Part 5 for hardware details on both options. HDMI is recommended unless you specifically want galvanic isolation.

---

## Part 2 — Subwoofer Physical Setup

### Placement

The YST-FSW050 is down-firing with a Linear Port. Placement significantly affects bass quality.

**Best positions (try in this order):**

1. **Front corner** (left or right of speakers) — reinforces bass, adds output. Can sound "boomy" in some rooms.
2. **Along the front wall** between the two Fluance ES1 towers — most integrated, sounds like bass is coming from the speakers themselves.
3. **Against a side wall** — works if corners are impractical.

**Avoid:**
- Directly between the listening position and the back wall — causes bass build-up
- Inside a cabinet or cupboard — blocks the down-firing port, chokes output
- Floating in the middle of the room — lacks reinforcement, sounds thin

**The subwoofer crawl (definitive placement method):**
1. Place the sub at your listening position (on the sofa or chair)
2. Play music with steady bass (a bassline song you know well)
3. Crawl around the floor near where you'd normally put the sub
4. The spot where bass sounds fullest and most even = where the sub goes
5. Move sub to that spot

**Floor surface:** Place on a solid, non-carpeted surface if possible. On carpet, the down-firing port partially loses efficiency. Optional: sub isolation platform or feet (prevents vibration transfer into floor/ceiling).

---

## Part 3 — Subwoofer Controls

The YST-FSW050 has three physical controls. Set them **before** running Audyssey:

### Volume Knob
Set to **50–60%** before Audyssey calibration. Audyssey will measure and trim the sub level itself. After Audyssey, do fine adjustments via the Onkyo's sub level control, not the sub's knob.

### Phase Switch (0° / 180°)
This aligns the subwoofer's bass output with your main speakers. Wrong phase = bass cancellation (thin, weak sound).

**How to set:**
1. Play a track with heavy bass between 60–100 Hz (e.g., bass guitar or kick drum)
2. Switch between 0° and 180°
3. Use the position where bass sounds **louder, fuller, more present**

There is no universally correct answer — it depends on sub placement and room acoustics. Most setups end up at 0°. If the sub seems to add nothing at 0°, try 180°.

### Crossover Knob (if present)
Set to **maximum position** — you want the Onkyo receiver to control the crossover via bass management, not the sub's internal filter. The YST-FSW050's LPF knob adds its own rolloff on top of the Onkyo's — using both is wrong.

### Power
The YST-FSW050 has no auto-on. Leave it powered on whenever the Onkyo is in use. You can place it on a smart plug and control it with the system power switch.

---

## Part 4 — Running Audyssey 2EQ

Audyssey 2EQ is the TX-SR605's automatic room calibration. It measures speaker output, sets levels, distances, and applies EQ. Run it once before doing anything else — then override specific settings.

### Prepare the Room

- Move furniture away from the mic position if possible
- Turn off fans, AC units, dishwasher — anything that makes background noise
- Make the room as quiet as possible (Audyssey's test tones are loud)
- Put pets and people outside the room

### Place the Calibration Microphone

Connect the supplied Audyssey mic to the front panel **SETUP MIC** jack.

Place the mic:
- At ear height at the main listening position (where you actually sit)
- On a mic stand or stack of books — not in your hand
- Pointing straight up (omnidirectional — direction doesn't matter much)

### Run Auto Setup

```
Remote: SETUP → Auto Setup → Next
```

Follow the on-screen steps:
1. Audyssey plays test tones for each speaker channel
2. It detects whether speakers are present/absent
3. It plays swept tones through each detected speaker
4. Takes about 3–5 minutes

When complete, Audyssey will show what it measured:
- Speaker sizes (Large/Small — almost certainly all Small)
- Distances (in meters or feet)
- Levels (dB)
- Crossover frequencies

**Write down everything Audyssey set** — you'll be overriding some of it.

### Audyssey Results for Your Setup

Expected results for the Fluance ES1 + Yamaha YST-FSW050:

| Speaker | Expected Audyssey result | Why |
|---|---|---|
| Front L/R (ES1) | Small, 80–150 Hz crossover | Audyssey correctly sees weak bass in ES1 |
| Subwoofer | Present, level varies | Should be at around +0 to +3 dB relative |

If Audyssey sets crossover above 80 Hz (e.g., 120 Hz or 150 Hz) — do NOT accept it. It means Audyssey thinks your ES1 needs extra sub support at a high frequency. Override to 80 Hz (next section).

---

## Part 5 — Post-Audyssey Manual Overrides

These are the most important settings. Navigate to:
```
Remote: SETUP → Manual Setup → Speaker Setup
```

### 5.1 — Speaker Size

| Channel | Set to | Reason |
|---|---|---|
| Front L/R (Fluance ES1) | **Small** | Forces bass below crossover to the sub. ES1 cannot cleanly reproduce below ~80 Hz despite being a tower. |
| Center | None (unused) | No centre speaker in this setup |
| Surround | None (unused) | No surrounds |
| Subwoofer | Yes | YST-FSW050 is connected |

> **Why not "Large" for the ES1?**
> "Large" tells the Onkyo the speaker is full-range and sends all bass to it. The ES1's four 5-inch woofers struggle below 80 Hz. Setting them Large and skipping bass management means the ES1 distorts at bass frequencies and the sub does nothing useful for stereo music. Small + 80 Hz crossover = cleaner sound, better dynamics.

### 5.2 — Crossover Frequency

```
Front speakers (ES1): 80 Hz
```

The Fluance ES1 is rated to 72 Hz but reliably usable only above ~100 Hz. The THX standard 80 Hz crossover is the correct choice — it:
- Relieves the ES1 from the deepest bass (least distortion)
- Hands bass to the YST-FSW050 which handles 35–160 Hz
- Places the crossover where the ES1 has overlap with the sub (80–100 Hz range)

If after listening the bass/mid-bass sounds slightly disconnected, try 100 Hz. If it sounds like two separate sound sources, drop back to 80 Hz.

### 5.3 — LPF for LFE (Low-Pass Filter for subwoofer)

```
SETUP → Manual Setup → Speaker Setup → LPF for LFE
Set to: 120 Hz
```

This is the maximum frequency the Onkyo will send to the sub from the LFE channel. 120 Hz is the standard home theater setting and matches what Dolby and DTS specify.

### 5.4 — Subwoofer Level

```
SETUP → Manual Setup → Levels → Subwoofer
```

Start at **0 dB** (flat, Audyssey calibrated it). Fine-tune by ear after everything else is set.

---

## Part 6 — Listening Modes Explained (For This Setup)

This is the most misunderstood part of the TX-SR605. Here is exactly what each mode does and which one to use when:

### PURE AUDIO

**What it does:**
- Disables ALL digital signal processing
- Disables Audyssey EQ
- Disables tone controls (bass/treble)
- Disables Dynamic EQ, Late Night, Re-EQ
- **Turns off the video circuits** (HDMI output goes dark — normal, not broken)
- Puts the amp in a pure 2-channel analog path
- Bass management is **OFF** — sub only receives LFE channel

**Effect on your setup:**
- Fluance ES1 plays full range (no sub support for bass below ~80 Hz)
- YST-FSW050 is **silent** for all stereo music (no LFE in stereo)
- Audyssey EQ is **off** — ES1 tweeter brightness is uncontrolled

**When to use:**
- Never for stereo music with this setup (sub goes silent, ES1 strains)
- Only if you have full-range speakers with no subwoofer

---

### DIRECT ✅ Recommended for Music

**What it does:**
- Disables Audyssey EQ
- Disables tone controls (bass/treble/loudness)
- **Keeps bass management active** — sub still works
- Video circuits remain active (HDMI works normally)
- Multi-channel sources play through assigned channels

**Effect on your setup:**
- ES1s play above 80 Hz (crossover active)
- YST-FSW050 receives bass below 80 Hz — **sub is fully working**
- Clean signal path without the coloration of EQ
- Audyssey level corrections still applied (distances, levels set by calibration)

**When to use:** Primary music listening mode. Best balance of signal cleanliness and bass management.

---

### STEREO

**What it does:**
- Full signal processing active (Audyssey EQ, tone controls)
- Bass management active
- Only front L/R speakers used for stereo sources
- Sub receives redirected bass

**Effect on your setup:**
- Same as Direct but Audyssey EQ corrects the ES1's treble brightness
- Good if the ES1 sounds harsh or bright in Direct mode

**When to use:** If the ES1 treble brightness bothers you in Direct mode. Audyssey's EQ will tame the 3–6 dB treble peak on the ES1.

---

### DOLBY PRO LOGIC II MUSIC

**What it does:**
- Matrix-decodes stereo to 5.1 surround
- Adds spatial width and depth processing
- Bass management active, all DSP active
- Widens the stereo image using surrounds (you don't have surrounds — ignore)

**When to use:** Not applicable for your 2.1 setup (no surrounds). Ignore.

---

### MULTICHANNEL STEREO

**What it does:**
- Plays stereo signal through all active speakers simultaneously
- With your setup: just front L/R + sub (same as Stereo)

**When to use:** Not useful for your setup. Ignore.

---

### Mode Summary for Your Setup

| Source | Best mode | Reason |
|---|---|---|
| FLAC/ALAC via MPD | **Direct** | Clean path, sub active, no EQ coloration |
| Apple Music via AirPlay 2 | **Direct** | Same — lossless needs clean path |
| Spotify Connect | **Stereo** | Audyssey EQ adds no harm to lossy source, tames brightness |
| Snapcast multi-room | **Direct** | Same as MPD |
| Background music | **Stereo** | Audyssey + loudness compensation helps at low volumes |
| Very loud listening | **Direct** | Avoid loudness/EQ at reference levels |

---

## Part 7 — Tone Controls and Audio Adjustments

### Bass and Treble

Located in: `Remote: SETUP → Audio Adjust → Bass / Treble`

These only work in **Stereo** and **Multichannel Stereo** modes (not Direct, not Pure Audio).

For the Fluance ES1's known treble brightness:
```
Treble: −2 to −3 dB    ← compensates for ES1's measured treble peak
Bass:   0 dB           ← let the sub handle bass, don't add EQ bass on the amp
```

Set treble to taste. Some people prefer the ES1's brightness (it sounds "detailed"). Others find it fatiguing over time. The only way to know is to listen.

### Audyssey Dynamic EQ

```
SETUP → Audio Adjust → Audyssey Dynamic EQ → Off (for music)
```

Dynamic EQ boosts bass and surround at low listening volumes (similar to loudness compensation). Useful for late-night TV at low volume. Distracting for critical music listening. **Turn off for music.**

### Re-EQ

```
SETUP → Audio Adjust → Re-EQ → Off
```

Re-EQ is designed to reduce treble harshness in badly mastered movie soundtracks. It hurts music. **Always off for music.**

### Late Night

```
SETUP → Audio Adjust → Late Night → Off
```

Compresses dynamic range (loud = quieter, quiet = louder). Useful for movies at 1am. **Off for music.**

---

## Part 8 — Subwoofer Fine-Tuning

After running Audyssey and setting crossover to 80 Hz, fine-tune by ear with music you know well. Use something with steady bass — a bass guitar recording or electronic music with a consistent kick drum pattern.

### Level (volume)

```
Onkyo: SETUP → Manual Setup → Levels → Subwoofer
```

Adjust in 0.5 dB steps. The sub level is correct when:
- You cannot hear the sub as a separate object ("I hear bass coming from that box")
- Bass sounds like it's coming from the Fluance ES1 towers themselves
- Bass is present but not dominant — the same volume as bass in a well-mixed recording

Common mistake: sub too loud. "Can you hear the sub?" = it's too loud. "Where is the sub?" = level is correct.

Starting point after Audyssey: **0 dB** (Audyssey's calibrated value). Adjust from there.

### Phase (on sub)

**Test procedure:**
1. Play a bass-heavy track in Direct mode at moderate volume
2. Toggle the phase switch 0°/180°
3. Position that sounds **louder and fuller = correct phase**

With typical placement (sub near front wall, listener 2–3m away):
- 0° is usually correct
- 180° is sometimes better if sub is behind or beside the listening position

### Crossover dial on the YST-FSW050

**Leave at maximum (fully clockwise).** The Onkyo controls the crossover. Adding a second filter from the sub creates phase problems and rolls off bass prematurely.

### Placement verification

With music playing in Direct mode at moderate volume, press your knee against the floor near the subwoofer. You should feel vibration. Now press your knee against the floor near the Fluance ES1 towers. You should also feel vibration — the ES1's four woofers produce tangible vibration above 80 Hz. If only the sub vibrates and the ES1s feel dead, the crossover is too low or the sub level is too high.

---

## Part 9 — Speaker Placement

The Fluance ES1 towers need correct placement to image properly and avoid early reflections.

### Distance from walls

```
Front wall (behind speakers):  30–60 cm minimum
Side walls:                    60 cm minimum
Between tweeters:              1.8–2.5 m for typical rooms
```

The ES1 is rear-ported (check the back of the speaker). With rear ports, being too close to the front wall (< 20 cm) boosts and muddies the bass. Move them out.

### Toe-in

Point the speakers toward your listening position. For the ES1's forward/bright tweeter, experiment with:
- **Moderate toe-in:** tweeters angled toward you. Focused centre image, more treble presence.
- **Less toe-in:** speakers pointing slightly outward. Wider, airier soundstage, slightly softer treble.

Given the ES1's measured treble brightness, **less toe-in** often sounds more natural.

### Height

The ES1 at 51 inches (130 cm) places the tweeter at roughly ear height for a standing adult, about 10–15 cm above ear height when seated. This is correct — no adjustment needed.

### Equilateral triangle rule

For best stereo imaging, the distance between the two tweeters should equal the distance from each tweeter to your ears. If the speakers are 2m apart, sit approximately 2m from each speaker.

```
        [Left ES1]  ←—— 2m ——→  [Right ES1]
               \                 /
                \               /
                 \             /
                  ↓           ↓
                       2m
                    [You here]
```

---

## Part 10 — Receiver Audio Settings Reference

All settings, one place, for copy/reference:

```
SETUP → Speaker Setup:
  Front speakers (ES1):  Small
  Crossover:             80 Hz
  Subwoofer:             Yes
  LPF for LFE:           120 Hz
  Center:                None
  Surround:              None

SETUP → Manual Setup → Levels:
  Front L:               0 dB (Audyssey calibrated)
  Front R:               0 dB (Audyssey calibrated)
  Subwoofer:             0 dB (start here, adjust by ear ±3 dB)

SETUP → Audio Adjust:
  Audyssey Dynamic EQ:   Off
  Audyssey Dynamic Vol:  Off
  Re-EQ:                 Off
  Late Night:            Off
  Bass:                  0 dB (or −2 dB if too boomy)
  Treble:                −2 to −3 dB (for ES1 brightness) or 0 dB to taste

Listening Mode for music: DIRECT
Listening Mode for casual/background: STEREO
```

---

## Part 11 — Input-by-Input Setup

### HDMI input (Le Potato)

1. Press **HDMI** input selector → **HDMI 1** (or whichever port Le Potato is connected to)
2. The Onkyo shows the HDMI signal type on the front display:
   - `PCM` = correct, lossless stereo from Linux
   - `DD` or `DTS` = something is wrong, ALSA is outputting compressed audio
3. If showing DD instead of PCM: restart the shairport-sync and mpd containers, check `asound.conf`

### Optical input (Le Potato SPDIF)

1. Press the input selector assigned to OPTICAL IN 1 (usually **CD** or **DVD**)
2. Front display should show `PCM 44.1K` or `PCM 48K`
3. Sampling rate shown corresponds to the music file's sample rate — confirms bit-perfect delivery

### HDMI vs Optical — Audible Difference

For stereo PCM there is **no audible difference** between HDMI and optical on this receiver. Both carry identical digital PCM data. Any claim that one "sounds better" than the other for digital audio is not supported by measurement.

---

## Part 12 — Common Problems and Fixes

### Sub is silent during music playback

**Cause:** Listening mode is Pure Audio or Direct with speakers set to Large.

**Fix:**
1. Switch to **Direct** mode (press Listening Mode until Direct shows)
2. Confirm: `SETUP → Speaker Setup → Front = Small, Crossover = 80 Hz`
3. Sub should now receive bass below 80 Hz

---

### Bass sounds boomy or slow

**Causes and fixes:**

| Cause | Fix |
|---|---|
| Sub crossover too high | Lower from 120 Hz to 80 Hz (already done above) |
| Sub too close to corner | Move sub away from corner by 10–20 cm and re-test |
| Sub level too loud | Reduce sub level in Onkyo Manual Setup by 2–3 dB |
| Phase wrong | Toggle sub's phase switch 0°/180° |
| Floor resonance | Try an isolation platform under the sub |

---

### Treble is harsh or fatiguing

**Cause:** Fluance ES1 has a measured 3–6 dB treble peak.

**Fixes (try in order):**
1. Switch from **Direct** to **Stereo** — Audyssey EQ corrects the peak
2. In Stereo mode: `Audio Adjust → Treble → −2 dB`
3. Reduce toe-in (angle speakers slightly away from listening position)
4. Check listening volume — the ES1 tweeter becomes more prominent at high SPL

---

### Onkyo front display shows "NO SIGNAL" on optical

**Causes:**
- SPDIF overlay not enabled on Le Potato (`sudo ldto merge spdif`)
- ALSA source not routed to SPDIF (`amixer sset "AIU SPDIF SRC SEL" I2S`)
- TOSLINK cable not clicked in fully (click = connected)
- TOSLINK transmitter module not powered (check 5V wire connection on 9J1)

---

### Onkyo shows signal but Onkyo display shows DD or DTS instead of PCM

Le Potato is sending compressed audio instead of raw PCM.

**Fix:**
```bash
# On Le Potato — restart audio containers:
cd ~/music-potato
docker compose restart shairport-sync mpd spotifyd

# Check ALSA output format:
aplay -l
# Should show: card 0: amlaugesound — not a compressed format device
```

---

### Sub and speakers sound disconnected (two separate sound sources)

**Cause:** Crossover frequency mismatch or phase issue.

**Fixes:**
1. Toggle phase switch on sub (0° ↔ 180°)
2. Try crossover at 100 Hz instead of 80 Hz (helps if ES1 rolls off higher than rated)
3. Move sub closer to the Fluance ES1 towers (reduces time-delay between sub and mains)

---

### Volume is low even at 80/100 on dial

**Cause:** Input level trim is set too low, or sub level is reducing perceived loudness.

**Fix:** `SETUP → Manual Setup → Levels` — increase Front L/R level by +2 to +3 dB. Do not confuse input level with master volume.

---

## Part 13 — Long-Term Tips

### Re-run Audyssey after moving furniture
Significant room changes (large sofa moved, new curtains, shelves added) affect reflections. Re-run Audyssey to update EQ and level calibration.

### Sub auto-power hack
The YST-FSW050 has no auto-on. Put it on a smart plug linked to the Onkyo (via Home Assistant or a simple switched outlet strip). Power it on whenever the Onkyo powers on.

### Reference level listening
The Onkyo's volume dial is uncalibrated. For a meaningful reference volume (THX/Dolby reference = 0 dBFS input plays back at 85 dB SPL at the listening position), you need a calibrated SPL meter. This matters if you want consistent loudness between sessions or if you're calibrating EQ precisely. For casual listening it's not needed.

### ES1 break-in
New Fluance ES1 towers sound slightly stiff in the woofer suspension. After 20–40 hours of use the woofers loosen up and bass becomes fuller and less constrained. If the bass sounds thin in the first week, give them time.

### YST-FSW050 limitations
This is a compact sub with a 6.5-inch driver. It will not produce sub-bass (below 35 Hz) at high SPL. For electronic music or home theater bass below 35 Hz, the YST-FSW050 will compress before the Onkyo does. This is a physical limitation of the driver size — not a settings problem.

---

## Quick Reference

```
Onkyo volume for casual listening:     40–55
Onkyo volume for serious listening:    60–75
Onkyo volume reference (loud):         80–85

Listening mode:    Direct (music) / Stereo (background)
Crossover:         80 Hz
Sub level:         0 dB (adjust ±3 dB by ear)
Sub phase:         0° (try 180° if bass sounds thin)
Sub knob:          MAX (Onkyo controls crossover)
ES1 setting:       Small
Treble:            −2 dB (in Stereo mode only)
Re-EQ:             Off
Dynamic EQ:        Off
Late Night:        Off

Best source for lossless:    MPD → Direct mode → PCM 44.1/96 kHz displayed
Best source for Apple Music: AirPlay 2 → Direct mode → PCM 48 kHz displayed
```

---

## Sources

- [Fluance ES1 Tower Review — Audioholics](https://www.audioholics.com/tower-speaker-reviews/fluance-es1)
- [Yamaha YST-FSW050 Specs — Yamaha USA](https://usa.yamaha.com/products/audio_visual/speaker_systems/yst-fsw050/specs.html)
- [Onkyo TX-SR605 Listening Modes Explained — AVS Forum](https://www.avsforum.com/threads/onkyo-tx-sr605-705-805-listening-modes-explained-purposes-and-benefits.1008717/)
- [Onkyo TX-SR605 Speaker Setup — Home Theater Forum](https://www.hometheaterforum.com/community/threads/best-speaker-setup-for-an-onkyo-tx-sr605.285265/)
- [Onkyo TX-SR605 + Subwoofer Setup — AVForums](https://www.avforums.com/threads/onkyo-tx-sr605-and-sub-setup.1412589/)
- [Audyssey Setup Guide — Simple Home Cinema](https://simplehomecinema.com/2021/06/16/configuring-audyssey-the-right-way/)
- [Subwoofer Crossover Tips — SVS Sound](https://www.svsound.com/blogs/subwoofer-setup-and-tuning/tips-for-setting-the-proper-crossover-frequency-for-a-subwoofer)
- [Onkyo TX-SR605 Full Manual — ManualsLib](https://www.manualslib.com/manual/302297/Onkyo-Tx-Sr605.html)
