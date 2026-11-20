# Platypal 🐾

A small turquoise platypus that lives along the bottom of your Mac screen. He walks around,
naps, dances, does backflips, chases your cursor, and says things now and then.

## Two characters

This repo builds two separate apps from two source files:

| App | Source | Build |
|---|---|---|
| **Platypal**, the turquoise platypus | `Platypal.swift` | `./build.sh` → `Platypal.app` |
| **Stix**, an acrobatic stick figure | `Stix.swift` | `./build-stix.sh` → `Stix.app` |

They're independent copies. Changing one doesn't affect the other, and you can run both at once.
Everything below about Platypal applies to Stix too (toys, hats, agent mode, hiding, folders,
debug mode). Stix adds his own moves:

- **Fighting the cursor.** Rest the cursor near his head and he throws a jab, cross, high-kick combo at it.
- **Cursor swipes.** Whip the cursor through him fast and he either gets knocked flying or backflips out of the way ("Too slow!").
- **Tricks on his own.** Handstand walks, cartwheels, front flips, backflips, and shadowboxing flurries.
- **Hard landings.** Throw him hard and he often sticks a three-point superhero landing instead of getting dizzy.
- **Wall kicks.** Throw him at a screen edge and he may kick off it ("Parkour!").
- He has no face. You read his mood from his poses, and his red scarf streams behind him when he moves.

## Build & run

```bash
xcode-select --install   # only if you don't have the Command Line Tools yet
./build.sh
open Platypal.app
```

He drops in from the top of the screen and lands on the Dock. There's no Dock icon. Quit him
from the paw icon in the menu bar, or right-click him.

## Playing with him

| Do this | He does this |
|---|---|
| Click | Reacts ("Hey!", "That tickles!") |
| Double-click | Backflip |
| Drag | Dangles and flails. Let go mid-swing to **throw** him: he tumbles, bounces off walls, and gets dizzy if he lands hard |
| Rest the cursor near his face | He boops it |
| Drop him on (or just under/above) a desktop folder icon | He shrinks and falls into it, rummages around, then pops out and tells you something he found inside |
| Leave the Mac alone for 3 minutes | Falls asleep, then greets you when you come back |
| Right-click / menu bar paw | Say Something, Come Here, Backflip, Dance, Nap, Hide!, Toys, Hat, Secret Agent Mode, Chatty on/off, Quit |

On his own he picks from walking, running, idling, staring at your cursor, chasing it, hopping,
dancing, backflips, naps (more naps after 11pm), and **hiding behind windows**: he walks to the edge of an app window that reaches down to the Dock, tiptoes behind it, peeks his head out, then jumps out with "Peekaboo!". He makes a remark every 35–90 seconds;
some lines depend on the time of day.

## Toys and dress-up

Right-click him (or use the menu bar paw):

- **Toys ▸ Soccer Ball** drops a ball onto the screen. He dribbles and kicks it around, and it bounces
  off walls, off him (headers!) and off the trampoline. You can flick it with a click, or drag and throw it.
- **Toys ▸ Trampoline** drops a trampoline he bounces on, sometimes with flips. Throw him onto it and he
  goes boing. Drag it to move it.
- **Toys ▸ Play with Ball / Jump on Trampoline** sends him to play right away. He also plays on his own.
- Right-click a toy → **Put Away** removes it (or uncheck it in the Toys menu).
- **Hat ▸** party hat, top hat, crown, propeller cap (it spins faster in the air) or beanie.
- **Secret Agent Mode** gives him shades and an earpiece, and he drops spy one-liners.

The hat and agent mode are remembered between launches.

## Permissions

The folder trick asks Finder where your desktop icons are, so the first launch shows
**"Platypal wants access to control Finder"**. Click OK. If you decline, everything else still
works; you can turn it back on later in System Settings → Privacy & Security → Automation.
Because `build.sh` signs the app ad hoc, macOS may ask again after each rebuild.

Hiding only reads where windows are, never their titles or contents, so it needs no permission.

## Debugging the folder trick

If dropping him on a folder does nothing:

1. Right-click him → **Debug Desktop Folders**. He tells you what Finder said, and an overlay shows:
   - a **crosshair** where Finder says each folder icon is, with its name and coordinates
   - a **red dashed box** per folder: the drop zone. It turns green while his feet are inside it
   - a **yellow dot** at his feet. That dot must be inside a box when you let go
   - a live readout of his feet, your cursor, how many folders he knows about, and how fast your last drop was

   With debug mode on, every drop also makes him say why it missed ("let go too fast",
   "nearest is 'School': 40 pt left, 120 pt below my feet", and so on).

2. If the crosshairs sit off from your icons by the same amount each time, set `kIconOffset`
   in `Platypal.swift` to that gap and rebuild.

3. If he says Finder permission is blocked (error -1743), reset it and relaunch. macOS should
   ask again:
   ```bash
   tccutil reset AppleEvents local.platypal
   ```

4. To check Finder directly, outside Platypal:
   ```bash
   osascript -e 'tell application "Finder" to get {name, desktop position} of every folder of desktop'
   ```

5. To see his logs, run the binary from Terminal instead of `open`. Every Finder query is logged there:
   ```bash
   ./Platypal.app/Contents/MacOS/Platypal
   ```

## Tweaking

Everything is in `Platypal.swift`:
- `Palette` holds the colors
- `Lines` holds everything he says
- `chooseNext()` sets how often he does each behavior
- `kIconOffset` nudges where he thinks folder icons are, if he lands beside them instead of in them
- `kAwayTime`, `kGravity` and the other constants at the top control timing and physics

To start him at login, add `Platypal.app` under System Settings → General → Login Items.
