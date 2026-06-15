# providers.tf — Fournisseurs Terraform
# PoC MSPR Bloc 2 — COGIP / Tesker
# Provider Multipass (larstobi) pour piloter des VMs Ubuntu ARM64 en local.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "multipass" {}

provider "local" {}
