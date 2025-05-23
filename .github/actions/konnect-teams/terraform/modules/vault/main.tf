terraform {
  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "4.4.0"
    }
  }
}

data "vault_auth_backend" "this" {
  path = "github"
}

# Create a team vault mount for the KV version 2 secret engine
resource "vault_mount" "this" {
  path        = "${var.team_name}-kv"
  type        = "kv"
  options     = { version = "2" }
  description = "Vault mount for the ${var.team_name} team"
}

# Create team vault policy
resource "vault_policy" "this" {
  name = "${vault_mount.this.path}-policy"

  policy = <<EOT
path "${vault_mount.this.path}/data/*" {
  capabilities = ["read"]
}

path "${vault_mount.this.path}/metadata/*" {
  capabilities = ["read"]
}

EOT
}

# Map policy to team
resource "vault_github_team" "this" {
  backend  = data.vault_auth_backend.this.id
  team     = var.team_name
  policies = ["${vault_policy.this.name}"]
}

# Store the access token in the KV
resource "vault_kv_secret_v2" "this" {

  mount               = vault_mount.this.path
  name                = var.system_account_secret_path
  delete_all_versions = true
  data_json = jsonencode(
    {
      token = var.system_account_token
    }
  )
  custom_metadata {
    max_versions = 5
  }
}