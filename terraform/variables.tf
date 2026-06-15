# variables.tf — Variables du cluster
# PoC MSPR Bloc 2 — COGIP / Tesker

# Carte des nœuds du cluster.
# - role "server" => control-plane K3s (+ serveur NFS co-localisé)
# - role "agent"  => worker K3s
#
# Contrainte 8 Go : configuration par défaut = 1 control-plane + 2 workers (~5 Gio).
# Repli "nœud unique" : ne garder que k3s-cp et passer son rôle de workers à vide
# (voir README, section "Repli nœud unique").
variable "nodes" {
  description = "Définition des VMs du cluster K3s"
  type = map(object({
    cpus   = number
    memory = string
    disk   = string
    role   = string # "server" ou "agent"
  }))

  default = {
    k3s-cp = { cpus = 2, memory = "2G", disk = "8G", role = "server" }
    k3s-w1 = { cpus = 1, memory = "2G", disk = "6G", role = "agent" }
    k3s-w2 = { cpus = 1, memory = "1G", disk = "6G", role = "agent" }
  }
}

# Image Ubuntu Multipass (ARM64 sur Apple Silicon).
variable "image" {
  description = "Image Ubuntu utilisée par Multipass"
  type        = string
  default     = "22.04"
}

# Clé SSH publique injectée dans les VMs via cloud-init.
# À renseigner dans terraform.tfvars (jamais commitée).
variable "ssh_public_key" {
  description = "Clé SSH publique (~/.ssh/mspr_ed25519.pub)"
  type        = string
}
