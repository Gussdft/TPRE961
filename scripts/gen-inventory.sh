#!/usr/bin/env bash
# gen-inventory.sh — Génère ansible/inventory.ini depuis l'état Multipass.
# PoC MSPR Bloc 2 — COGIP / Tesker
#
# Classement par convention de nommage :
#   - k3s-cp*  -> groupe [control_plane] (rôle server)
#   - k3s-w*   -> groupe [workers]       (rôle agent)
# Le fichier généré est ignoré par git (ne pas l'éditer à la main).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${ROOT_DIR}/ansible/inventory.ini"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/mspr_ed25519}"

if ! command -v multipass >/dev/null 2>&1; then
  echo "ERREUR : 'multipass' introuvable. Installe-le (brew install --cask multipass)." >&2
  exit 1
fi

# On capture la sortie JSON dans un fichier temporaire pour éviter tout conflit
# entre le pipe et le here-document lus par python.
TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT
multipass list --format json >"$TMP_JSON"

if [ ! -s "$TMP_JSON" ]; then
  echo "ERREUR : 'multipass list --format json' n'a rien renvoyé. Réessaie dans quelques secondes." >&2
  exit 1
fi

python3 - "$INVENTORY" "$SSH_KEY" "$TMP_JSON" <<'PY'
import json, sys

inventory_path, ssh_key, json_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(json_path) as fh:
    data = json.load(fh)

control_plane, workers = [], []

for vm in data.get("list", []):
    name = vm.get("name", "")
    ips = [ip for ip in vm.get("ipv4", []) if ip]  # ignore les IP vides
    if not ips:
        continue
    ip = ips[0]
    line = f"{name} ansible_host={ip}"
    if name.startswith("k3s-cp"):
        control_plane.append(line)
    elif name.startswith("k3s-w"):
        workers.append(line)

if not control_plane:
    sys.stderr.write(
        "ERREUR : aucun control-plane détecté (k3s-cp sans IP ?). "
        "Attends ~20 s après 'make up' puis relance 'make inventory'.\n"
    )
    sys.exit(1)

lines = []
lines.append("# Inventaire généré automatiquement — NE PAS ÉDITER À LA MAIN")
lines.append("")
lines.append("[control_plane]")
lines.extend(control_plane)
lines.append("")
lines.append("[workers]")
lines.extend(workers)
lines.append("")
lines.append("[k3s_cluster:children]")
lines.append("control_plane")
lines.append("workers")
lines.append("")
lines.append("[all:vars]")
lines.append("ansible_user=ubuntu")
lines.append(f"ansible_ssh_private_key_file={ssh_key}")
lines.append("ansible_python_interpreter=/usr/bin/python3")
lines.append("ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'")
lines.append("")

with open(inventory_path, "w") as f:
    f.write("\n".join(lines))

print(f"Inventaire écrit : {inventory_path}")
print(f"  control_plane : {len(control_plane)} hote(s)")
print(f"  workers       : {len(workers)} hote(s)")
PY
