#!/bin/bash
# ComfyUI Video Generation Template for vast.ai
# Model: Wan2.1 I2V + Wan2.2 Animate
# Feature: Background preservation from reference image
# Source: https://raw.githubusercontent.com/your-repo/wan_video_vastai.sh (placeholder)

# ============================================================
#  CONFIGURATION — edit this section
# ============================================================

# Hugging Face token (for gated models)
# Set this in your vast.ai template as environment variable HF_TOKEN
# export HF_TOKEN="hf_..."

DISK_GB_REQUIRED=120

APT_PACKAGES=(
    "aria2"
    "ffmpeg"
)

PIP_PACKAGES=(
    "huggingface_hub[cli]"
    "rembg[gpu]"        # background removal
    "onnxruntime-gpu"
)

# Custom ComfyUI nodes
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/1038lab/ComfyUI-RMBG"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/city96/ComfyUI-GGUF"
)

# === Wan 2.1 Image-to-Video 720P (fp8 — recommended for 24GB VRAM) ===
DIFFUSION_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors"
)

# === Text Encoder ===
TEXT_ENCODER_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors"
)

# === VAE ===
VAE_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"
)

# === CLIP Vision ===
CLIP_VISION_MODELS=(
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/clip_vision_h.safetensors"
)

# === Wan 2.2 Animate (optional — requires more VRAM / longer download) ===
# Uncomment to also install Wan2.2 Animate
# WAN22_ANIMATE=(
#     "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/..."
# )

# === Background removal models (RMBG 2.0 via ComfyUI-RMBG) ===
# These are auto-downloaded by the RMBG node on first use.
# No manual download needed.

# ============================================================
#  DO NOT EDIT BELOW THIS LINE
# ============================================================

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/diffusion_models" \
        "${DIFFUSION_MODELS[@]}"

    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/text_encoders" \
        "${TEXT_ENCODER_MODELS[@]}"

    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/vae" \
        "${VAE_MODELS[@]}"

    provisioning_get_models \
        "${WORKSPACE}/storage/stable_diffusion/models/clip_vision" \
        "${CLIP_VISION_MODELS[@]}"

    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo apt-get install -y ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    fi
    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

function provisioning_print_header() {
    printf "\n========================================\n"
    printf " ComfyUI Wan Video — vast.ai Provisioning\n"
    printf " Models: Wan2.1 I2V 720P (fp8) + RMBG\n"
    printf " Feature: Background preservation\n"
    printf "========================================\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Disk %sGB < required %sGB — some models may not download\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete — ComfyUI starting now\n\n"
}

provisioning_start
