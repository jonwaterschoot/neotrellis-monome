# LeaveSeqr

Ambient leaf physics sequencer for Neotrellis grids: leaves drift through the air, float on the water surface, and sink slowly to the mud. Three independent generative water tracks play notes as leaves pass over the playheads. Triops leap into the water to eat the sinking leaves, causing a bouncing bass echo delay.

- **Author:** jonwaterschoot
- **Version:** v0.3.0

---

# LeaveSeqr

Ambient leaf physics sequencer for Neotrellis grids: leaves drift through the air, float on the water surface, and sink slowly to the mud. Three independent generative water tracks play notes as leaves pass over the playheads. Triops leap into the water to eat the sinking leaves, causing a bouncing bass echo delay.

- **Author:** jonwaterschoot
- **Version:** v0.3.0

---

## Usage

Navigate the grid using three screens. Hold **ALT** (`x=1, y=3`) to cycle between the screens: **Live** (physics simulation), **Seq** (sequencer settings), and **Scale** (musical settings). By default, the sequencer runs at full 16 steps and runs at different relative speeds from top to bottom (surface is fastest, mid is slower, deep is the slowest).

---

## Controls

### Main Controls (Present on all screens)

| Location   | Label      | Description                              |
|------------|------------|------------------------------------------|
| x=1, y=8   | ALT        | Cycle screens: Live → Seq → Scale        |
| x=1, y=3   | Play/Stop  | Play/stop sequencer & physics (Live only)|
| x=16, y=3  | Freeze     | Pause leaves in water zones (Live only)  |

---

## Screen 1: Live Simulation (Default)

The primary view where the ambient ecosystem lives.

- **Row 1 (Canopy):** Leaves grow here. Tap a leaf to knock it loose, or tap an empty spot to plant.
- **Row 2 (Wind):**
  - **x=1..3**: Left wind — gusts push leaves horizontally to the right, and blows canopy loose.
  - **x=14..16**: Right wind — gusts push leaves horizontally to the left, and blows canopy loose.
- **Row 2..4 (Air Zone):** Leaves drift slowly down. Wind pushes horizontally and sometimes upward.
- **Row 5 (Water Surface):** Track 1, plays at base octave limit.
- **Row 6 (Underwater Mid):** Track 2, plays one octave down.
- **Row 7 (Underwater Deep):** Track 3, plays two octaves down.
- **Row 8 (Mud):** Leaves collect and decay at the bottom. Triops emerge occasionally.

---

## Screen 2: Sequencer Settings

Customize how the leaves trigger notes when they reach the water tracks.

**Top Row (y=1) Track Options:**
1. `x=1` LEN — tap a track row twice to set loop start and end bounds (left-to-right is forward, right-to-left is reverse).
2. `x=2` DIV — tap `x=1..6` on a track row to set track division (playback speed).
3. `x=3` CH — tap `x=1..16` on a track row to set MIDI channel.
4. `x=4` OCT — tap `x=1..8` on a track row to set octave offset bounds (-4 to +3).

**Row 2-4 Controls:**
- **BPM**: `x=1..4, y=2` (-10, -1, +1, +10)
- **Wind Str**: `x=1..3, y=3` (lo, mid, hi)
- **Density**: `x=5..8, y=3` (off, lo, mid, hi)
- **Humanize**: `x=1..3, y=4` (off, soft, heavy)
- **Triops**: `x=5, y=4` (off, soft, strong)

**Tracks:**
Modify the tracks by tapping at their live `y` positions (Rows 5, 6, 7).

---

## Screen 3: Scale & Environment

Tune the harmony, environment, and physical appearance.

| Component      | Location               | Controls Description                                         |
|----------------|------------------------|--------------------------------------------------------------|
| **Scale**      | `x=1..7, y=1`          | Select scale: MAJ, MIN, PMA, PMI, DOR, LYD, CUS (Custom)     |
| **Root Note/Custom** | `x=1..7, y=3..4` | y=3: Black keys (with gaps). y=4: White keys. Custom toggles.|
| **Octave Base**| `x=1..4, y=6`          | Octave base: 2, 3, 4, 5                                      |
| **Season**     | `x=1..4, y=7`          | SP Spring, SU Summer, AU Autumn, WI Winter (see below)       |
| **Monochrome** | `x=6, y=7`             | Toggle monochrome mode on/off                                |

### Seasons

Seasons change leaf colors, note character, and MIDI CC filter automation simultaneously.

| Season | Colors | Notes | MIDI CC |
|--------|--------|-------|---------|
| **SP** Spring | Bright greens | Short, energetic · high velocity | Neutral (CC 100) |
| **SU** Summer | Warm yellow-greens | Long, sustained · high velocity | Neutral (CC 100) |
| **AU** Autumn | Warm oranges & reds | Short–medium · velocity variance · 25% chord chance (third or fifth) | Slow, wide filter sweeps |
| **WI** Winter | Cool blues & greys | Long and short mixed · lower velocity · 15% echo chance | Fast, jittery filter drift |

Spring and Summer leave the MIDI CC filter at 100 (fully open, no movement). Autumn and Winter drive a slow-moving CC ramp on CC 74 — Autumn sweeps broadly and slowly, Winter drifts fast and erratically. If your synth or DAW responds to CC 74 (filter cutoff), these seasons will animate the filter automatically.
| **Grid Dimming** | `x=3..5, y=8`        | Grid brightness levels: lo, mid, max                         |
