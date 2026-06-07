###############################################################################
# INF-16 — Dev environment root module
#
# Composes all Atlas Terraform modules in dependency order:
#   network → aks → identity → secrets / data / storage
#
# Wires outputs between modules so callers never hand-code resource IDs.
# No module is applied here — this is the composition layer only.
#
# Dependency graph:
#   module.network
#     ↳ module.aks         (consumes subnet_system_id, subnet_workload_id)
#         ↳ module.identity  (consumes oidc_issuer_url)
#             ↳ module.secrets  (consumes identity_client_ids["gateway"],
#             |                  subnet_data_id, vnet_id from network)
#             ↳ module.data     (consumes subnet_data_id, vnet_id)
#             ↳ module.storage  (consumes subnet_workload_id, vnet_id)
###############################################################################

###############################################################################
# 1. Network — VNet, subnets, NSGs
###############################################################################

module "network" {
  source = "../../modules/network"

  resource_group_name = var.resource_group_name
  location            = var.location

  vnet_name          = var.vnet_name
  vnet_address_space = var.vnet_address_space

  subnet_system_cidr   = var.subnet_system_cidr
  subnet_workload_cidr = var.subnet_workload_cidr
  subnet_data_cidr     = var.subnet_data_cidr

  tags = merge(var.tags, { module = "network" })
}

###############################################################################
# 2. AKS — cluster, system + workload node pools, OIDC issuer
#
# Consumes:
#   module.network.subnet_system_id
#   module.network.subnet_workload_id
###############################################################################

module "aks" {
  source = "../../modules/aks"

  resource_group_name = var.resource_group_name
  location            = var.location

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  dns_prefix         = var.dns_prefix

  # Wired from network outputs
  subnet_system_id   = module.network.subnet_system_id
  subnet_workload_id = module.network.subnet_workload_id

  system_node_pool_vm_size    = var.system_node_pool_vm_size
  system_node_pool_node_count = var.system_node_pool_node_count

  workload_node_pool_vm_size   = var.workload_node_pool_vm_size
  workload_node_pool_min_count = var.workload_node_pool_min_count
  workload_node_pool_max_count = var.workload_node_pool_max_count

  admin_group_object_ids = var.admin_group_object_ids

  tags = merge(var.tags, { module = "aks" })
}

###############################################################################
# 3. Identity — per-service managed identities, federated credentials, RBAC
#
# Consumes:
#   module.aks.oidc_issuer_url
###############################################################################

module "identity" {
  source = "../../modules/identity"

  resource_group_name = var.resource_group_name
  location            = var.location

  # Wired from AKS outputs
  oidc_issuer_url = module.aks.oidc_issuer_url

  kubernetes_namespace = var.kubernetes_namespace
  services             = var.services

  tags = merge(var.tags, { module = "identity" })
}

###############################################################################
# 4a. Secrets — Key Vault, private endpoint, SecretProviderClass template
#
# Consumes:
#   module.network.subnet_data_id
#   module.network.vnet_id
#   module.identity.identity_client_ids["gateway"]  (fallback to var if empty)
###############################################################################

locals {
  # Resolve gateway client ID: prefer live identity module output so the env
  # root is self-contained after first apply; accept a pre-supplied override
  # for the bootstrap case where identity hasn't been applied yet.
  gateway_client_id = (
    length(module.identity.identity_client_ids) > 0 &&
    lookup(module.identity.identity_client_ids, "gateway", "") != ""
    ? module.identity.identity_client_ids["gateway"]
    : var.gateway_identity_client_id
  )
}

module "secrets" {
  source = "../../modules/secrets"

  resource_group_name = var.resource_group_name
  location            = var.location

  key_vault_name             = var.key_vault_name
  key_vault_sku_name         = "standard"
  soft_delete_retention_days = 90
  purge_protection_enabled   = false # dev only; enable for prod

  tenant_id = var.tenant_id

  # Wired from network outputs
  subnet_data_id = module.network.subnet_data_id
  vnet_id        = module.network.vnet_id

  secret_names         = var.secret_names
  kubernetes_namespace = var.kubernetes_namespace
  identity_client_id   = local.gateway_client_id

  tags = merge(var.tags, { module = "secrets" })
}

###############################################################################
# 4b. Data — PostgreSQL Flexible Server, Redis Cache, private endpoints
#
# Consumes:
#   module.network.subnet_data_id
#   module.network.vnet_id
###############################################################################

module "data" {
  source = "../../modules/data"

  resource_group_name = var.resource_group_name
  location            = var.location

  # Wired from network outputs
  subnet_data_id = module.network.subnet_data_id
  vnet_id        = module.network.vnet_id

  # Dev-sized PostgreSQL (burstable, single-AZ)
  pg_server_name                  = var.pg_server_name
  pg_version                      = "16"
  pg_sku_name                     = "B_Standard_B1ms"
  pg_storage_mb                   = 32768
  pg_storage_tier                 = "P4"
  pg_admin_username               = var.pg_admin_username
  pg_backup_retention_days        = 7
  pg_geo_redundant_backup_enabled = false

  pg_databases = {
    atlas = {
      charset   = "UTF8"
      collation = "en_US.utf8"
    }
  }

  # Dev-sized Redis (Basic C0)
  redis_capacity             = 0
  redis_family               = "C"
  redis_sku_name             = "Basic"
  redis_non_ssl_port_enabled = false
  redis_minimum_tls_version  = "1.2"

  tags = merge(var.tags, { module = "data" })
}

###############################################################################
# 4c. Storage — Blob containers (golden-sets, trace-archive, artifacts) + ACR
#
# Consumes:
#   module.network.subnet_workload_id
#   module.network.vnet_id
###############################################################################

module "storage" {
  source = "../../modules/storage"

  resource_group_name = var.resource_group_name
  location            = var.location

  # Wired from network outputs
  subnet_workload_id = module.network.subnet_workload_id
  vnet_id            = module.network.vnet_id

  storage_account_name             = var.storage_account_name
  storage_account_replication_type = "LRS" # dev: locally redundant (cheapest)
  storage_account_tier             = "Standard"
  blob_versioning_enabled          = true
  blob_delete_retention_days       = 7
  container_delete_retention_days  = 7

  blob_containers = {
    golden-sets = {
      access_type           = "private"
      lifecycle_tier_days   = 90
      lifecycle_delete_days = 0
    }
    trace-archive = {
      access_type           = "private"
      lifecycle_tier_days   = 30
      lifecycle_delete_days = 365
    }
    artifacts = {
      access_type           = "private"
      lifecycle_tier_days   = 90
      lifecycle_delete_days = 730
    }
  }

  acr_name                          = var.acr_name
  acr_sku                           = "Premium" # private endpoint + scan-on-push
  acr_admin_enabled                 = false
  acr_public_network_access_enabled = false
  acr_quarantine_policy_enabled     = true
  acr_retention_policy_days         = 30
  acr_trust_policy_enabled          = false

  tags = merge(var.tags, { module = "storage" })
}
