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

## Lancer sous Windows (WSL2 + Multipass)

> L'automatisation (Makefile, scripts shell, Ansible) suppose un environnement **Unix**.
> Sous Windows, on l'exécute depuis **WSL2** (Ubuntu), tandis que **Multipass tourne côté
> Windows (Hyper-V)**. Procédure best-effort : la démonstration de référence reste le Mac.

**1. Installer WSL2 + Ubuntu** (PowerShell en administrateur) :

```powershell
wsl --install -d Ubuntu
```

Puis redémarrer le PC et terminer la configuration d'Ubuntu.

**2. Activer le réseau « miroir »** pour que WSL2 puisse joindre les VMs Multipass.
Créer le fichier `C:\Users\<utilisateur>\.wslconfig` avec :

```ini
[wsl2]
networkingMode=mirrored
```

Puis, dans PowerShell : `wsl --shutdown` (WSL redémarrera au prochain lancement).

**3. Installer Multipass pour Windows** : télécharger l'installeur sur https://multipass.run
(il s'appuie sur Hyper-V — disponible sur Windows 10/11 Pro).

**4. Dans le terminal Ubuntu (WSL2), installer les outils** :

```bash
sudo apt update && sudo apt install -y make ansible python3 python3-pip unzip curl
# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
# kubectl + helm
sudo snap install kubectl --classic && sudo snap install helm --classic
```

**5. Rendre Multipass (Windows) appelable depuis WSL** via un petit wrapper :

```bash
sudo tee /usr/local/bin/multipass >/dev/null <<'EOF'
#!/usr/bin/env bash
exec multipass.exe "$@"
EOF
sudo chmod +x /usr/local/bin/multipass
multipass version   # doit répondre
```

**6. Récupérer le projet et le lancer** (toujours dans WSL2) :

```bash
git clone https://github.com/Gussdft/TPRE961.git && cd TPRE961
make ssh-key
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# coller la clé publique affichée dans terraform.tfvars
make all
```

**7. Accès Odoo** : éditer le fichier hosts **de Windows** (en administrateur)
`C:\Windows\System32\drivers\etc\hosts` et y ajouter la ligne affichée par `make hosts`,
par ex. `172.x.x.x odoo.cogip.local`. Ouvrir ensuite `https://odoo.cogip.local` dans le
navigateur Windows.

**Différences avec le Mac** :
- Pas de `multipass set local.driver=qemu` (sous Windows c'est Hyper-V).
- Les VMs sont en **x86_64** (Multipass prend l'image de l'architecture de l'hôte) — les images
  `odoo:17.0` et `postgres:16-alpine` sont multi-arch, donc compatibles.
- Si Ansible signale des hôtes `unreachable`, c'est le réseau WSL ↔ Hyper-V : vérifier que le
  mode `networkingMode=mirrored` (étape 2) est bien actif (`wsl --shutdown` puis relancer).

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
