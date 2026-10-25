# scripts

Only the device tools and firmware tests live here:

- **[selector](selector/)**, a script picker. Every script on the device gets a slot; press once to show its name, press again to load it.
- **[tresholdmemorytests](tresholdmemorytests/)**, two comment-padded scripts just under and just over the ~32 KB upload limit of stock iii. Both should upload on this firmware. See the [investigation](../changestracker/leaveseqr-upload-failure-investigation.md).

## Music scripts and examples

Sequencers (leaveseqr, sandman, serpentine), the color demos and the test scripts are kept in the emulator repo, [diii-neotrellis-emulator/scripts](https://github.com/jonwaterschoot/diii-neotrellis-emulator/tree/main/scripts). You can try each one in the browser in the [emulator](https://jonwaterschoot.github.io/diii-neotrellis-emulator/), then upload it to the grid with diii.
