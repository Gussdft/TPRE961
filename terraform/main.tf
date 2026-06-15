# main.tf — Création des VMs Multipass
# PoC MSPR Bloc 2 — COGIP / Tesker

# 1) Rendu d'un fichier cloud-init par nœud (clé SSH + paquets de base).
#    Les fichiers générés (cloud-init.<nom>.yaml) sont ignorés par git.
resource "local_file" "cloud_init" {
  for_each = var.nodes

  filename = "${path.module}/cloud-init.${each.key}.yaml"
  content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname       = each.key
    ssh_public_key = var.ssh_public_key
  })
}

# 2) Une instance Multipass par entrée de la map "nodes".
resource "multipass_instance" "node" {
  for_each = var.nodes

  name           = each.key
  image          = var.image
  cpus           = each.value.cpus
  memory         = each.value.memory
  disk           = each.value.disk
  cloudinit_file = local_file.cloud_init[each.key].filename

  # S'assurer que le cloud-init est écrit avant le lancement de la VM.
  depends_on = [local_file.cloud_init]
}
