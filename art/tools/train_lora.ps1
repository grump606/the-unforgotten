# Train the style LoRA (SDXL, 8 GB card) with kohya sd-scripts.
#   powershell -ExecutionPolicy Bypass -File art\tools\train_lora.ps1
# Expects curated images + .txt captions in art\work\lora_train\5_cbpstyle\ (5 = repeats per epoch).
# Output: art\work\lora_out\cbpstyle.safetensors (copy it to ComfyUI\models\loras).
param(
    [string]$Trainer = 'D:\Tools\trainer-sd-scripts',
    [string]$Python = 'D:\Tools\trainer-python\python.exe',
    [string]$Checkpoint = 'D:\Tools\comfyui\ComfyUI_windows_portable\ComfyUI\models\checkpoints\sd_xl_base_1.0.safetensors',
    [int]$Epochs = 4
)
$root = Split-Path (Split-Path $PSScriptRoot)
Set-Location $Trainer
& $Python -m accelerate.commands.launch --num_cpu_threads_per_process 4 sdxl_train_network.py `
    --pretrained_model_name_or_path $Checkpoint `
    --train_data_dir (Join-Path $root 'art\work\lora_train') `
    --output_dir (Join-Path $root 'art\work\lora_out') --output_name cbpstyle `
    --resolution 640,640 --enable_bucket --min_bucket_reso 512 --max_bucket_reso 896 `
    --network_module networks.lora --network_dim 16 --network_alpha 8 `
    --optimizer_type Adafactor --optimizer_args scale_parameter=False relative_step=False warmup_init=False `
    --learning_rate 1e-4 --lr_scheduler constant `
    --max_train_epochs $Epochs --train_batch_size 1 --save_every_n_epochs 2 `
    --mixed_precision fp16 --save_precision fp16 --no_half_vae `
    --gradient_checkpointing --cache_latents --cache_text_encoder_outputs --network_train_unet_only `
    --max_data_loader_n_workers 0 --sdpa --caption_extension .txt --seed 42

