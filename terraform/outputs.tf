# outputs.tf — Sorties Terraform
# PoC MSPR Bloc 2 — COGIP / Tesker
#
# Les IP des VMs Multipass ne sont pas exposées de façon fiable par le provider
# (DHCP). On récupère les IP via `multipass list` dans scripts/gen-inventory.sh.
# Ces sorties servent surtout à confirmer la topologie créée.

output "nodes" {
  description = "Nœuds créés et leur rôle"
  value = {
    for name, cfg in var.nodes :
    name => {
      role   = cfg.role
      cpus   = cfg.cpus
      memory = cfg.memory
    }
  }
}

output "control_plane" {
  description = "Nom du nœud control-plane"
  value       = [for name, cfg in var.nodes : name if cfg.role == "server"]
}

output "workers" {
  description = "Noms des nœuds workers"
  value       = [for name, cfg in var.nodes : name if cfg.role == "agent"]
}
