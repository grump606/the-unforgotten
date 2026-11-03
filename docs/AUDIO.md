# Audio

All sound goes through the `AudioManager` autoload (`audio/audio_manager.gd`). Screens say what is happening; they never create players.

- **Buses**: `Music`, `Ambience`, `SFX`, all sending to `Master`; created in code at startup (no bus layout file). Trims at slider 100%: music -8 dB, ambience -22 dB, effects -4 dB.
- **Scenes**: `AudioManager.set_scene(music_id, ambience_id)`. Repeating the current ids does nothing; a different id crossfades (`audio/audio_channel.gd`, 1.6 s music, 2.5 s ambience). `run.gd` picks: fight music during a fight, the quiet track everywhere else, the sea on the start screens and at the first destination (Shore of Names).
- **Effects**: `AudioManager.sfx(id)` (from screens, `RunScreen.sfx(id)`). Requests in one frame merge into the highest priority; the same effect is not repeated within 60 ms. Used for: every `RunScreen.add_button` button (`click`), starting or continuing a journey (`confirm`), hand-card selection in the discard step (`card_select`), a played card (`card_play`), a card that cannot be played (`unavailable`), taking a reward card (`reward`), End Turn (`click`). There are none for hover or redraws.
- **Pause**: music and ambience keep playing, ducked 6 dB while the pause menu is open. Losing window focus mutes the master bus until focus returns.
- **Settings**: Master/Music/Ambience/Effects sliders and Mute on the main menu ("Sound") and the pause menu ("Sound"), stored under `audio` in `user://settings.json` via `Settings` (other keys are kept). Written when a slider is released, on Back, on mute, and on close.
- **Headless**: nothing plays when the display server is headless (automated tests); `AudioManager.sfx_log` still records requests.

## Assets

- `audio/source/` holds the untouched originals (hidden from Godot with `.gdignore`, so neither imported nor exported).
- `tools/audio/bake_loops.py` turns them into the seamless loops the game plays (`audio/music/*_loop.ogg`, `audio/ambience/coastal_loop.ogg`, import set to loop). Requires Python with numpy and soundfile.
- Effects are unmodified Kenney CC0 WAVs in `audio/sfx/`.
- `audio/CREDITS.txt` is the credits/licence record. It is listed in the export preset's `include_filter` so it ships, and the Sound page shows it.
