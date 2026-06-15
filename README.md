# PoC MSPR Bloc 2 — Odoo sur Kubernetes (COGIP / Tesker)

Déploiement de l'ERP **Odoo** sur un cluster **Kubernetes (K3s)**, **100 % automatisé**
en Infrastructure as Code, dans le cadre fictif de la société **COGIP** pour son client
**Tesker**. La solution est **reproductible** (objectif Plan de Reprise d'Activité) :
`make all` reconstruit toute la plateforme de zéro.

Certification visée : **Expert en Informatique et Systèmes d'Information (RNCP 35584)** — MSPR Bloc 2.

## Architecture (PoC local)

```
        Mac M1 (8 Go, arm64)
        │
        ├─ Terraform ──> Multipass ──> 3 VMs Ubuntu 22.04 ARM64
        │                                k3s-cp   (server + serveur NFS)
        │                                k3s-w1   (agent)
        │                                k3s-w2   (agent)
        │
        └─ Ansible ────> sur les VMs :
             common      préparation (sysctl, modules, paquets)
             nfs_server  serveur NFS co-localisé sur le control-plane
             k3s_server  control-plane K3s (Traefik + ServiceLB intégrés)
             k3s_agent   jonction des workers
             platform    Helm : nfs-subdir-provisioner + cert-manager
             odoo        manifests : PostgreSQL + Odoo + Ingress HTTPS

   Accès final : https://odoo.cogip.local  (Traefik + certificat auto-signé)
```

### Choix techniques

- **K3s** : Traefik (Ingress) et ServiceLB sont **intégrés** → pas de MetalLB ni ingress-nginx.
- **Odoo** via images **officielles** `odoo:17.0` + `postgres:16-alpine` (multi-arch, arm64).
  Le chart Helm Bitnami est volontairement écarté (catalogue déprécié → `ImagePullBackOff`).
- **Stockage** : `nfs-subdir-external-provisioner` (StorageClass `nfs-client`). Sur 8 Go, le
  serveur NFS est **co-localisé** sur le control-plane (pas de 4ᵉ VM).
- **HTTPS** : cert-manager + ClusterIssuer auto-signé sur l'hôte `odoo.cogip.local`.
- Helm sert **uniquement** au provisioner NFS et à cert-manager ; Odoo est déployé par manifests.

## Prérequis (macOS Apple Silicon)

```bash
brew install terraform ansible kubernetes-cli helm
brew install --cask multipass
# Driver conseillé sur M1 si "launch failed" :
multipass set local.driver=qemu
```

## Démarrage rapide

```bash
# 1) Clé SSH dédiée + récupération de la clé publique
make ssh-key

# 2) Renseigner la clé publique dans terraform/terraform.tfvars
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
#    puis coller la clé affichée par 'make ssh-key' dans ssh_public_key

# 3) Pipeline complet : VMs -> inventaire -> déploiement -> ligne /etc/hosts
make all

# 4) Ajouter la ligne affichée à /etc/hosts, par ex. :
echo "192.168.64.X odoo.cogip.local" | sudo tee -a /etc/hosts
```

Puis ouvrir **https://odoo.cogip.local** (accepter le certificat auto-signé).
Mot de passe maître Odoo : voir `odoo_master_password` dans `ansible/group_vars/all.yml`.

### Étapes individuelles

| Commande         | Effet                                                        |
|------------------|-------------------------------------------------------------|
| `make ssh-key`   | Génère `~/.ssh/mspr_ed25519` et affiche la clé publique     |
| `make up`        | `terraform apply` → crée les VMs Multipass                   |
| `make inventory` | Génère `ansible/inventory.ini` depuis les IP Multipass       |
| `make deploy`    | `ansible-playbook site.yml` (K3s + NFS + Helm + Odoo)        |
| `make hosts`     | Affiche la ligne `odoo.cogip.local` pour `/etc/hosts`        |
| `make status`    | `kubectl get nodes / pods -A / ingress`                      |
| `make validate`  | `terraform validate` + `ansible --syntax-check`              |
| `make down`      | `terraform destroy` → supprime les VMs                       |
| `make clean`     | `down` + suppression des fichiers générés                    |

## Repli « nœud unique » (contrainte 8 Go)

Si le cluster est instable (pods `Pending`, swap saturé), réduire à un seul nœud.
Dans `terraform/terraform.tfvars`, surcharger la map `nodes` :

```hcl
nodes = {
  k3s-cp = { cpus = 2, memory = "4G", disk = "10G", role = "server" }
}
```

Le groupe `[workers]` de l'inventaire est alors vide : le play d'agents est ignoré
sans erreur. Le reste du pipeline est identique.

## Vérifications avant de dire « c'est bon »

```bash
cd terraform && terraform validate && terraform fmt -check
cd ../ansible && ansible-playbook site.yml --syntax-check
make status          # nodes Ready + pods Running (Odoo + postgres dans ns odoo)
```

But final : Odoo accessible sur **https://odoo.cogip.local** (certificat auto-signé accepté).

## Pièges connus

- **IP Multipass non immédiates** : `make inventory` attend ~20 s. Si vide, relancer.
- **Connexion Ansible KO** : utilisateur `ubuntu`, clé `~/.ssh/mspr_ed25519` (vérifier `terraform.tfvars`).
- **`launch failed`** : `multipass set local.driver=qemu`.
- **Images arm64** : toujours cibler des images multi-arch (sinon émulation lente / échec sur M1).
- **Premier accès Odoo lent** : l'image initialise la base au premier démarrage (patienter 1–2 min).

## Sécurité / secrets

Les fichiers sensibles sont couverts par `.gitignore` : `terraform.tfvars`, `*.tfstate*`,
`.terraform/`, `cloud-init.*.yaml`, `ansible/inventory.ini`, clés SSH.
Les mots de passe Odoo/PostgreSQL sont en clair dans `group_vars/all.yml` **pour le PoC
uniquement** ; en production → **Ansible Vault**.

## Proposition de production (présentée à l'oral, non déployée)

Cluster managé en haute disponibilité chez un fournisseur cloud (control-plane managé,
≥ 3 workers répartis sur plusieurs zones), stockage par CSI du fournisseur (blocs réseau
répliqués), Ingress + LoadBalancer managé, certificats **Let's Encrypt** (ACME) au lieu de
l'auto-signé, secrets en coffre (Vault / Secret Manager), sauvegardes PostgreSQL planifiées
et observabilité (logs + métriques). Le même découpage Terraform/Ansible est conservé ;
seuls le provider Terraform et le backend de stockage changent.

## Structure du dépôt

```
terraform/   providers.tf, variables.tf, main.tf, outputs.tf,
             cloud-init.yaml.tftpl, terraform.tfvars.example
scripts/     gen-inventory.sh
ansible/     ansible.cfg, requirements.yml, site.yml, group_vars/all.yml
  roles/     common, nfs_server, k3s_server, k3s_agent, platform, odoo
Makefile     up / inventory / deploy / all / hosts / status / down / clean
```
