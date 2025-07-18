# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

ARG HUGGINGFACE_ACCESS_TOKEN

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --fast-deps --cuda-version 11.8 --nvidia --version 0.3.44

# Change working directory to ComfyUI
WORKDIR /comfyui

# Download some of the custom models
# Reactor doesn't see the network volume, so those must be baked in

RUN mkdir -p models/facerestore_models
RUN wget -q --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/facerestore_models/GFPGANv1.3.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GFPGANv1.3.pth
RUN wget -q --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/facerestore_models/GFPGANv1.4.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GFPGANv1.4.pth
RUN wget -q --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/facerestore_models/codeformer-v0.1.0.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/codeformer-v0.1.0.pth
RUN wget -q --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/facerestore_models/GPEN-BFR-512.onnx https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GPEN-BFR-512.onnx

# Install runpod
RUN pip install runpod requests dill lark diffusers timm groundingdino-py

# Go back to the root
WORKDIR /

# Restore the snapshot to install custom nodes
ADD src/restore_snapshot.sh ./
RUN chmod +x  /restore_snapshot.sh
ADD *snapshot*.json /
RUN /restore_snapshot.sh

# Copy scripts in
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Support for the network volume
ADD src/extra_model_paths.yaml /comfyui/

# Turn off NSFW detector in ReActor
COPY src/reactor_sfw.py /comfyui/custom_nodes/comfyui-reactor/scripts/

# Start container
CMD ["/start.sh"]
