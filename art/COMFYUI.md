# Local generation (ComfyUI + SDXL)

Installed outside the repo: `D:\Tools\comfyui\ComfyUI_windows_portable` (ComfyUI v0.43.0, SDXL base 1.0 in `ComfyUI\models\checkpoints`). RTX 2080 SUPER, 8 GB. `rembg` is pip-installed into its embedded Python and pulled a ~1 GB model on first use.

Start the server (port 8188):

```powershell
cd D:\Tools\comfyui\ComfyUI_windows_portable
.\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --port 8188 --listen 127.0.0.1
```

Pilot (Gate Warden), with `$py` = that `python.exe`:

```powershell
& $py art\tools\comfy_gen.py --prompt "<style block>, <bg prompt>" --out art\work\warden\bg_raw.png --seed 11
& $py art\tools\comfy_gen.py --prompt "<style block>, <figure prompt>, plain flat grey background" --out art\work\warden\figure_raw.png --width 768 --height 1024 --seed 5
& $py art\tools\assemble_layers.py art\work\warden art\layers\warden
```

Prompts come from `PROMPTS.md`. `art/work/` holds raw generations and is not meant to be committed. `mid.png` and `fg.png` are still procedural placeholders.

Known gaps: the generated figure kept a stone arch behind it in some cutouts, the figure is small in a 3:1 frame, and the Warden's gate bars and amber slit are not yet reproduced. Next: tighten prompts, add a style LoRA, generate mid/fg layers.
