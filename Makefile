# Makefile — PoC MSPR Bloc 2 (COGIP / Tesker)
# Orchestration : Terraform (VMs) -> inventaire -> Ansible (K3s + Odoo)

SHELL := /bin/bash
SSH_KEY := $(HOME)/.ssh/mspr_ed25519
TF_DIR := terraform
ANSIBLE_DIR := ansible

.PHONY: help ssh-key up inventory deploy all hosts status down clean validate

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

ssh-key: ## Génère la clé SSH dédiée si absente et affiche la clé publique
	@test -f $(SSH_KEY) || ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -C "mspr-cogip"
	@echo "--- Clé publique à coller dans $(TF_DIR)/terraform.tfvars ---"
	@cat $(SSH_KEY).pub

up: ## Crée les VMs Multipass (terraform apply)
	cd $(TF_DIR) && terraform init -upgrade && terraform apply -auto-approve

inventory: ## Génère ansible/inventory.ini depuis les IP Multipass
	@echo "Attente de l'attribution des IP (~20 s)..." && sleep 20
	SSH_KEY=$(SSH_KEY) ./scripts/gen-inventory.sh

deploy: ## Déploie K3s + NFS + cert-manager + Odoo (ansible)
	@echo "Amorçage des routes réseau vers les VMs (ARP)..."
	@for ip in $$(multipass list --format json | \
		python3 -c 'import sys,json; print(" ".join(ip for vm in json.load(sys.stdin)["list"] if vm["name"].startswith("k3s-") for ip in vm["ipv4"][:1]))'); do \
		ping -c 2 $$ip >/dev/null 2>&1 || true; \
	done
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml && \
		ansible-playbook site.yml

all: up inventory deploy hosts ## Pipeline complet (up -> inventory -> deploy -> hosts)

hosts: ## Affiche la ligne à ajouter à /etc/hosts
	@IP=$$(multipass info k3s-cp --format json | \
		python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["info"]["k3s-cp"]["ipv4"][0])'); \
	echo "Ajoute cette ligne à /etc/hosts :"; \
	echo "  $$IP odoo.cogip.local"

status: ## État du cluster (nodes, pods, ingress)
	@multipass exec k3s-cp -- sudo k3s kubectl get nodes -o wide
	@echo "---"
	@multipass exec k3s-cp -- sudo k3s kubectl get pods -A
	@echo "---"
	@multipass exec k3s-cp -- sudo k3s kubectl get ingress -n odoo

validate: ## Vérifie la syntaxe Terraform et Ansible
	cd $(TF_DIR) && terraform fmt -check && terraform validate
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml --syntax-check

down: ## Détruit les VMs Multipass (terraform destroy)
	cd $(TF_DIR) && terraform destroy -auto-approve

clean: down ## Détruit les VMs et supprime les fichiers générés
	rm -f $(TF_DIR)/cloud-init.*.yaml $(ANSIBLE_DIR)/inventory.ini
