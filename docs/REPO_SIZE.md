# Repository size

Notes for the maintainer. Nothing has been moved or deleted, and history has not been rewritten;
this page lists what is big and what the options are, so the decision is yours.

Measured on `main` after v0.8.1 (about 1,020 tracked files, about 430 commits):

```
git count-objects -vH   ->   size-pack: ~249 MiB   (a fresh clone downloads about this much)
```

## Biggest tracked folders (working-tree size of tracked files)

| Folder | Size | In the game export? | Notes |
| --- | --- | --- | --- |
| `art/layers/screens` | ~75 MB | yes | Painted backdrops and screen layers (PNG), the largest single group |
| `art/layers/cards` | ~49 MB | yes | One painted PNG per card |
| `audio/source` | ~15 MB | **no** (source only) | Original MP3s for the music and ambience; the game uses the compressed OGGs in `audio/music` and `audio/ambience` |
| `art/layers/ui` | ~7 MB | yes | |
| `audio/music` | ~5 MB | yes | OGG loops (`combat_loop.ogg` alone is 4 MB) |
| `docs/reference` | ~4 MB | **no** | Generated screen reference sheets (web pages and captures) |
| `art/layers/*` (enemies, players) | ~2 MB each | yes | Sprites |
| `art/tutorial` | ~0.8 MB | yes | The tutorial's fight-screen picture |
| everything else (code, data, tests, docs) | ~2 MB | mostly | Source is tiny next to the art |

The biggest single files are `audio/source/combat_piano_cello.mp3` (9.6 MB), `audio/music/combat_loop.ogg`
(4.0 MB) and several 3 MB backdrop PNGs.

`.gitignore` already keeps `art/work/` (the working files of the art pipeline), `build/`, `.godot/`
and local engine folders out of the repository.

## Exported versus source-only

The export preset (`export_presets.cfg`, `exclude_filter`) leaves out `audio/source/*`, `tests/*`,
`tools/*`, `scripts/*`, `docs/*` (so also `docs/reference`), `installer/*`, `build/*`, `art/work/*`,
`art/tools/*` and `art/*.md`. So the installer carries `art/layers`, `audio/music`, `audio/ambience`,
`audio/sfx` and the code, and `audio/source` plus `docs/reference` are weight that only the
repository pays.

## Options

None of these is needed today; the repository is workable at this size. They matter if clones get
slow or the history keeps growing as art is regenerated (every changed PNG adds a full copy to
history).

1. **Do nothing.** Cheapest. Growth is roughly the size of each regenerated image.
2. **Git LFS for `*.png`, `*.mp3`, `*.ogg`.** Keeps clones small (pointers in history, files fetched on demand). Costs: GitHub LFS storage and bandwidth quotas, CI needs `lfs: true` on checkout (and the engine import cache key must account for it), every contributor installs LFS. Converting existing history needs a history rewrite (`git lfs migrate`); converting only new commits does not shrink the existing pack.
3. **Move the sources out of the repo.** `audio/source` (15 MB) and `docs/reference` (4 MB) are not needed to build the game. They could live in a separate private repository, a release asset, or a cloud folder, leaving a README pointer. Removing them from the working tree is easy; removing them from history needs a rewrite.
4. **Shrink the art.** Many backdrops are 3 MB PNGs. Lossless re-compression (for example `oxipng`) or WebP would cut the working tree without any workflow change, at the cost of re-importing and a one-off large commit.
5. **A shallow or partial clone for CI and contributors** (`fetch-depth: 1` is already enough for CI): no repository change at all.

Before any of the history-rewriting options, tag the current `main` and keep a backup clone: release
tags and the update signing files reference commits.

## Binary handling

`.gitattributes` marks PNG, MP3, OGG, WAV, JPG, WebP and ICO as `binary`, so Git never tries to
convert line endings or print a text diff for them.
