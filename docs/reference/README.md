# Screen reference sheets

Two web pages that show what the game's screens look like and what art and code they are built from. Open the `index.html` files in a browser; the images sit next to them and the pages need no build step. (They load two Google Fonts for the headings and fall back to Georgia and a system font when offline.)

| Page | What it shows |
| --- | --- |
| [`screens/index.html`](screens/index.html) | Every screen: main menu, character select, rest, vendor, boss fight (entrance and settled), a regular fight and the end card. For each, an in-game capture, the art it uses with file paths, layout and rules details, the code files, and the command that opens it. |
| [`vendor/index.html`](vendor/index.html) | The vendor stall in detail: the painted stall, the shopkeeper, and the screen as it looks in the game. |

## They are snapshots

The captures were taken at v0.6.6 plus the changes up to the plaque-style menus and the boss HUD (November 2026), at the default window size. When a screen changes, retake its capture and update the page. The facts in the pages (prices, sizes, text) were true at that time.

The vendor capture in both pages shows the dark backing panel covering the stall art; that is how it looked when captured and has since been treated as a known issue.

## Retaking a capture

Every screen can be opened directly with the debug launcher (`README.md`, "Debug"): no playing down the line, and nothing is saved.

```powershell
.\scripts\debug_fight.ps1 -Screen select                        # character select
.\scripts\debug_fight.ps1 -Screen rest -Character pickpocket    # rest
.\scripts\debug_fight.ps1 -Screen vendor -Character medium      # vendor
.\scripts\debug_fight.ps1 eraser -Character deserter            # boss fight (entrance in the first 2 seconds)
.\scripts\debug_fight.ps1 shade,hound,crow -Character pickpocket # regular fight
.\scripts\debug_fight.ps1 -Screen end -Character medium -Hp 31  # end card (-Screen defeat for the defeat card)
```

The main menu is the normal launch; with a save it shows Continue and the saved-run tablet.
