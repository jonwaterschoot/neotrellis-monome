**game over**
- when the board gets reset, all settings are reverted to a fresh state like boot.
- we have two wipes, the second one should replay the notes we heard in the first wipe but in a half speed reversed order

**tempo:**
- no tempo increase as you move along, or grow: stick to 1 tempo set by the bpm, the yellow fruit can trigger a temporary slower speed, halving speed for 16 steps

**notes**
- yellow, triggers a temporary half speed tempo
- red shrinks the tail
- cyan with triggered halo: the halo has a life span of 3, 1st hit changes the halo to a plus around the cyan (corners of the 3*3 square dissapear), 2nd hit cleans the halo, 3rd clears it completely, the blue gets 3 dim states 
  - cyan triggers a chord, that is held for a few counts varying from 3-5 while the chord is playing, arp is halted, 
  - 1st hit chord major; sec minor; third play the chord in a strummed mode 

- played notes repeat after hits; as notes get collected they become part of a evolving arpeggio, each new note replaces the oldest one.
- we want to Ensure that a hit always is a audible event: we constrain notes within a few octaves and the hit causes that note to be a higher ocatave, once in the arpeggio pool it becomes part of the normal octaves.  
 

**settings page:**
- a double tap allows to keep the menu openen until tapped again, 1 tap plus hold is temporary open
- we'll make the controls work as a 'slider' setting, so hitting inside the bar sets the value
- this means we do not need the plus

settings:
1. Top row 16 pixels: tempo stretches along the full 16 width to allows to go from 40 to 190 in steps of 10, highlight 120 to start as default  
   - we'll allow to set it finer by adding a number display / counter that shows the bpm 
   - use a 3x4 grid for each number, use gradients of amber to make the second number differentiate
   - use a two dot blue front and green back to set the speed granular -/+ 1
2. second row, 16 pixels: set amount of max. fruits 
3. third row of 16 pixels allows to set the lifespan of the arp, first 8 pixels makes the notes dissapear after x steps (allows the game to be silent when no new steps are added), second 8 pixels allows to set the lifespan kept in pool, from 1-8 


4. 4th row of a few toggles, allows to set a few variables: 
   - 1 st toggle the autorunner
   - arp modes: order of collecting, random, up, down
     (use the "3 dig display to write; ORD; RND; UP; DWN)