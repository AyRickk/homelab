terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc05"
    }
  }
}


variable "PROXMOX_API_URL" {
  type = string
}

variable "PROXMOX_ROOT_USER" {
  description = "Proxmox root user"
  type        = string
  sensitive   = true
}

variable "PROXMOX_ROOT_PASSWORD" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}

variable "PUBLIC_SSH_KEY" {
  type      = string
  sensitive = true
}

variable "CI_ODIN_PASSWORD" {
  type      = string
  sensitive = true
}

provider "proxmox" {
  pm_api_url      = var.PROXMOX_API_URL
  pm_user         = var.PROXMOX_ROOT_USER
  pm_password     = var.PROXMOX_ROOT_PASSWORD
  pm_tls_insecure = true
}
