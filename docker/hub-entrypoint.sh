#!/usr/bin/env bash
set -euo pipefail

WS="/workspace"
PERSIST="$WS/home"

mkdir -p \
  "$PERSIST/.gemini" \
  "$PERSIST/.antigravity-server" \
  "$PERSIST/.config" \
  "$PERSIST/.local/bin" \
  "$PERSIST/.local/share" \
  "$PERSIST/.local/state" \
  "$PERSIST/.ssh" \
  "$PERSIST/ssh-host-keys" \
  "$PERSIST/projects" \
  "$WS/spend-evidence"

chmod 700 "$PERSIST/.ssh" "$PERSIST/ssh-host-keys"

link_persist() {
  local target="$1"
  local link_path="$2"
  mkdir -p "$(dirname "$link_path")"
  if [[ -L "$link_path" ]]; then
    if [[ "$(readlink "$link_path")" == "$target" ]]; then
      return
    fi
    rm -f "$link_path"
  elif [[ -e "$link_path" ]]; then
    if [[ -d "$link_path" && -d "$target" ]]; then
      cp -an "$link_path/." "$target/" 2>/dev/null || true
    fi
    rm -rf "$link_path"
  fi
  ln -s "$target" "$link_path"
}

link_persist "$PERSIST/.gemini" "/root/.gemini"
link_persist "$PERSIST/.antigravity-server" "/root/.antigravity-server"
link_persist "$PERSIST/.config" "/root/.config"
link_persist "$PERSIST/.local" "/root/.local"

# Keep /root/.ssh as a real 0700 root:root directory (OpenSSH StrictModes rejects symlinks through 0777 NFS /workspace).
if [[ -L /root/.ssh ]]; then
  rm -f /root/.ssh
fi
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [[ -f "$PERSIST/.ssh/authorized_keys" ]]; then
  cp -f "$PERSIST/.ssh/authorized_keys" /root/.ssh/authorized_keys
fi
if [[ -f "$PERSIST/.ssh/config" ]]; then
  cp -f "$PERSIST/.ssh/config" /root/.ssh/config
  chmod 600 /root/.ssh/config
fi

for repo_dir in dot agent-skills; do
  if [[ -d "$PERSIST/$repo_dir" ]]; then
    link_persist "$PERSIST/$repo_dir" "/root/$repo_dir"
  fi
done

# Persist SSH host keys across restarts so clients do not hit host-key mismatch errors.
if [[ -f "$PERSIST/ssh-host-keys/ssh_host_ed25519_key" ]]; then
  cp -a "$PERSIST/ssh-host-keys/ssh_host_"* /etc/ssh/
  chmod 600 /etc/ssh/ssh_host_*_key
else
  ssh-keygen -A
  cp -a /etc/ssh/ssh_host_* "$PERSIST/ssh-host-keys/"
  chmod 600 "$PERSIST/ssh-host-keys/ssh_host_"*_key
fi

# Inject RunPod PUBLIC_KEY into /root/.ssh/authorized_keys and mirror to persistent storage.
AUTH_KEYS="/root/.ssh/authorized_keys"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
if [[ -n "${PUBLIC_KEY:-}" ]]; then
  while IFS= read -r key_line; do
    [[ -z "$key_line" ]] && continue
    grep -qxF "$key_line" "$AUTH_KEYS" || printf '%s\n' "$key_line" >> "$AUTH_KEYS"
  done <<< "$PUBLIC_KEY"
fi
cp -f "$AUTH_KEYS" "$PERSIST/.ssh/authorized_keys"
chmod 600 "$PERSIST/.ssh/authorized_keys"

# Ensure non-interactive SSH shells see /opt/hub tools and persistent ~/.local/bin.
cat >/etc/profile.d/research-hub.sh <<'PROFILE'
export UV_PYTHON_INSTALL_DIR=/opt/hub/uv_python
export PLAYWRIGHT_BROWSERS_PATH=/opt/hub/ms-playwright
export SPEND_EVIDENCE_HOME=/workspace/spend-evidence
export PATH="/opt/hub/bin:/opt/hub/envs/api-core/bin:/root/.local/bin:/usr/local/bin:$PATH"
PROFILE

if ! grep -q "research-hub.sh" /root/.bashrc 2>/dev/null; then
  printf '\n[ -f /etc/profile.d/research-hub.sh ] && source /etc/profile.d/research-hub.sh\n' >> /root/.bashrc
fi

# Export container environment for SSH sessions (excluding secrets that belong in user files).
env | grep -E '^(UV_|PLAYWRIGHT_|SPEND_EVIDENCE_|RUNPOD_POD_ID=|RUNPOD_DC_ID=|PATH=)' > /etc/environment || true

mkdir -p /run/sshd
/usr/sbin/sshd

if [[ -x "$WS/boot.sh" ]]; then
  "$WS/boot.sh" >> "$WS/boot.log" 2>&1 || true
fi

if [[ $# -gt 0 ]]; then
  exec "$@"
fi
exec sleep infinity
