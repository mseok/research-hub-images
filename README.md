# research-hub-images

Public open-source Docker runtime images built for RunPod CPU research hubs and GPU experiment workers.

- `ghcr.io/mseok/research-hub:latest` — Ubuntu 24.04 x86_64 CPU hub with OpenSSH, Node 24, `uv`, `ruff`, `gh`, `tmux`, Chromium, `agy` CLI, and prebuilt Python 3.12 environments under `/opt/hub/envs/{api-core,chem-bio,opt-rl}`.
- `ghcr.io/mseok/leadatlas-rl-runtime:latest` — RunPod PyTorch 2.8.0 CUDA 12.8.1 GPU runtime with `transformers`, `peft`, `accelerate`, `rdkit`, and `openai` under `/opt/leadatlas/venv`.
