# Serpentine Sequencer: Settings Matrix Documentation

The settings menu allows extensive, real-time control over the sequencer and game mechanics. When holding or toggling the `ALT` button (bottom-left corner), the 16x8 NeoTrellis grid maps to the following interactive parameters.

---

## Row 1: Spawner Engine
- **x=1 to 8: Spawn Quantity Slider**
  Controls the maximum number of fruits allowed on the grid simultaneously. Each pixel step represents 2 fruits, allowing a maximum of 16 fruits when fully maxed at `x=8`.
- **x=11 to 16: Fruit Type Toggles**
  A 6-element palette allowing independent enabling/disabling of fruit drop permutations. Active fruits glow with native RGB; disabled drop to 10% brightness.
  - `x=11`: Red (Basic Note & Tail Shrink)
  - `x=12`: Blue (Bonus Length & Arp Trigger)
  - `x=13`: Yellow (Temp Slow Down & Arp Trigger)
  - `x=14`: Cyan (Diatonic Triads / Chords)
  - `x=15`: Orange (33% Chance Arp Trigger)
  - `x=16`: Purple (Gravity Echo Bounces)

## Row 2: Arpeggiator Configuration
- **x=1 to 8: Arpeggio Lifespan**
  Sets how many steps the active Arpeggiator sequence lasts before decaying. Each pixel adds 8 steps to the span.
- **x=9 to 16: Arpeggio Pool Capacity**
  Dictates the maximum buffer size of notes the snake can hold concurrently in the historical chord memory.

## Row 3: Timing & Macros
- **x=1: Autopilot Mode**
  Cycles between three snake AI navigation states:
  - `NON`: Manual control only
  - `SEM`: Semi-Auto (Snake seeks targets when fed a direction manually)
  - `AUT`: Full Auto (Unattended continuous play)
- **x=3: Arpeggio Playback Mode**
  Cycles the order in which the internal Arp Pool repeats.
  - `ORD`: Ordered (FIFO)
  - `RND`: Random selection
  - `UP`: Low-to-High pitch sort
  - `DWN`: High-to-Low pitch sort
- **x=10, 11, 12, 13: Tempo (BPM) Controls**
  Increment and decrement triggers for the master clock speed.
  - `x=10`: -10 BPM
  - `x=11`: -1 BPM
  - `x=12`: +1 BPM
  - `x=13`: +10 BPM
- **x=15: Master Grid Brightness**
  Steps through internal LED brightness limiting ratios to conserve power or increase vibrancy.
- **x=16: Monochrome/Tint Overlay**
  Toggles between rich color display and 8 cinematic monochromatic tinted hue layers.

## Row 4: Scale System & Readouts
- **x=1 to 7: Scale Selection Tabs**
  Determines the diatonic structure filtering the sequencer grid.
  - `x=1`: Major (`MAJ`)
  - `x=2`: Minor (`MIN`)
  - `x=3`: Pentatonic Major (`PMA`)
  - `x=4`: Pentatonic Minor (`PMI`)
  - `x=5`: Dorian (`DOR`)
  - `x=6`: Lydian (`LYD`)
  - `x=7`: Custom Manual (`CUS`)
- **x=8 to 16: Dynamic LED Numeric Readout Space**
  A static 3x5 block font matrix dedicated to rendering current text states (BPM amounts, String Identifiers for Scale, and Arp States).

## Rows 6 & 7: The Interactive Keyboard
Used for locking the global Root Note of the sequencer, or plotting toggle positions internally when `CUS` scale mode is selected.
- **Row 6 (Black Keys):**
  - `x=2`(C#), `x=3`(D#)
  - `x=5`(F#), `x=6`(G#), `x=7`(A#)
- **Row 7 (White Keys):**
  - `x=1`(C), `x=2`(D), `x=3`(E), `x=4`(F), `x=5`(G), `x=6`(A), `x=7`(B)

## Rows 7 & 8: Global Grid Overlays
- **x=1, y=8: ALT / Settings Access Key**
  The entry and exit toggle. Tapping it quickly activates sticky-mode, holding and releasing enables momentary access.
- **x=14 to 16: D-PAD Area**
  Rendered at the bottom right.
  - `x=15, y=7`: UP
  - `x=14, y=8`: LEFT
  - `x=15, y=8`: DOWN
  - `x=16, y=8`: RIGHT
