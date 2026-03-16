#!/bin/bash
# ComfyUI Video Generation Setup for vast.ai
# Image: vastai/comfy (ComfyUI pre-installed at /workspace/ComfyUI)
# Models: Wan2.1 I2V 720P fp8 + RMBG background removal

set -e

COMFYUI_DIR="/workspace/ComfyUI"
MODELS_DIR="$COMFYUI_DIR/models"
NODES_DIR="$COMFYUI_DIR/custom_nodes"

echo ""
echo "========================================"
echo " ComfyUI Wan Video — vast.ai Setup"
echo " Models: Wan2.1 I2V 720P (fp8) + RMBG"
echo "========================================"
echo ""

# ── Создаём папки ──────────────────────────────────────────
mkdir -p "$MODELS_DIR/diffusion_models"
mkdir -p "$MODELS_DIR/text_encoders"
mkdir -p "$MODELS_DIR/vae"
mkdir -p "$MODELS_DIR/clip_vision"
mkdir -p "$MODELS_DIR/unet"

# ── Системные пакеты ───────────────────────────────────────
echo ">>> Installing system packages..."
apt-get update -qq
apt-get install -y -qq aria2 ffmpeg git

# ── Python зависимости ─────────────────────────────────────
echo ">>> Installing Python packages..."
pip install -q "huggingface_hub[cli]" rembg onnxruntime-gpu 2>/dev/null || \
pip install -q "huggingface_hub[cli]" rembg onnxruntime 2>/dev/null || true

# ── Custom Nodes ───────────────────────────────────────────
echo ">>> Installing custom nodes..."

install_node() {
    local repo="$1"
    local name="${repo##*/}"
    local path="$NODES_DIR/$name"
    if [ -d "$path" ]; then
        echo "  [skip] $name already exists"
    else
        echo "  [install] $name"
        git clone --depth=1 "$repo" "$path" 2>/dev/null
        if [ -f "$path/requirements.txt" ]; then
            pip install -q -r "$path/requirements.txt" 2>/dev/null || true
        fi
    fi
}

install_node "https://github.com/ltdrdata/ComfyUI-Manager"
install_node "https://github.com/kijai/ComfyUI-WanVideoWrapper"
install_node "https://github.com/kijai/ComfyUI-KJNodes"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
install_node "https://github.com/1038lab/ComfyUI-RMBG"
install_node "https://github.com/cubiq/ComfyUI_essentials"
install_node "https://github.com/city96/ComfyUI-GGUF"

# ── Скачивание моделей ─────────────────────────────────────
download_model() {
    local url="$1"
    local dest_dir="$2"
    local filename="${url##*/}"
    # убираем query string если есть
    filename="${filename%%\?*}"

    if [ -f "$dest_dir/$filename" ]; then
        echo "  [skip] $filename already exists"
        return
    fi

    echo "  [download] $filename"
    if [ -n "$HF_TOKEN" ]; then
        wget --header="Authorization: Bearer $HF_TOKEN" \
             -q --show-progress \
             --content-disposition \
             -P "$dest_dir" \
             "$url" 2>&1 || \
        aria2c --header="Authorization: Bearer $HF_TOKEN" \
               -x 8 -s 8 -k 1M \
               -d "$dest_dir" -o "$filename" \
               "$url" 2>/dev/null
    else
        wget -q --show-progress \
             --content-disposition \
             -P "$dest_dir" \
             "$url" 2>&1 || \
        aria2c -x 8 -s 8 -k 1M \
               -d "$dest_dir" -o "$filename" \
               "$url" 2>/dev/null
    fi
}

echo ""
echo ">>> Downloading models (this will take 20-30 minutes)..."

# Wan2.1 I2V 720P fp8 (~14GB)
download_model \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors" \
    "$MODELS_DIR/diffusion_models"

# Text Encoder UMT5-XXL fp8 (~9GB)
download_model \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" \
    "$MODELS_DIR/text_encoders"

# VAE (~400MB)
download_model \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" \
    "$MODELS_DIR/vae"

# CLIP Vision (~1.26GB) — официальный репозиторий Comfy-Org
download_model \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "$MODELS_DIR/clip_vision"

echo ""
echo "========================================"
echo " Setup complete!"
echo " ComfyUI is available at port 18188"
echo "========================================"
echo ""

# ── Запуск ComfyUI ─────────────────────────────────────────
echo ">>> Starting ComfyUI on port 18188..."
cd "$COMFYUI_DIR"
python main.py --listen 0.0.0.0 --port 18188 --enable-cors-header &

echo ">>> ComfyUI started. Open http://IP:18188 in your browser."
