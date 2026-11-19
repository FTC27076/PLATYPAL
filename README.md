# Platypal 🐾

A small turquoise platypus that lives along the bottom of your Mac screen. He walks around,
naps, dances, does backflips, chases your cursor, and says things now and then.

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
| Leave the Mac alone for 3 minutes | Falls asleep, then greets you when you come back |
| Right-click / menu bar paw | Say Something, Come Here, Backflip, Dance, Nap, Chatty on/off, Quit |

On his own he picks from walking, running, idling, staring at your cursor, chasing it, hopping,
dancing, backflips, and naps (more naps after 11pm). He makes a remark every 35–90 seconds;
some lines depend on the time of day.

## Tweaking

Everything is in `Platypal.swift`:
- `Palette` holds the colors
- `Lines` holds everything he says
- `chooseNext()` sets how often he does each behavior
- `kAwayTime`, `kGravity` and the other constants at the top control timing and physics

To start him at login, add `Platypal.app` under System Settings → General → Login Items.
