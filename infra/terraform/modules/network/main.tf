###############################################################################
# INF-4 — Network Module
#
# Provisions:
#   - Virtual Network (atlas-vnet)
#   - Subnets: system / workload / data
#   - NSGs attached to each subnet with least-privilege rules
#
# CIDR Plan (see also variables.tf for full rationale):
#
#   VNet:      10.0.0.0/16   — full Atlas address space
#   system:    10.0.0.0/22   — AKS system node pool (kube-system workloads)
#   workload:  10.0.4.0/22   — AKS workload node pool (Atlas services)
#   data:      10.0.8.0/24   — PostgreSQL Flexible Server + Redis private
#                               endpoints; kept small, no pods here
#
# Dependency order (from README):  network → aks → identity → …
# The aks module consumes:
#   - output.subnet_system_id
#   - output.subnet_workload_id
# The data/secrets modules consume:
#   - output.subnet_data_id
###############################################################################

###############################################################################
# Virtual Network
###############################################################################

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

###############################################################################
# Subnets
###############################################################################

# ---------------------------------------------------------------------------
# system — AKS system node pool
# service_endpoints: none (system pool needs no direct PaaS access)
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "system" {
  name                 = "system"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_system_cidr]
}

# ---------------------------------------------------------------------------
# workload — AKS workload node pool
# service_endpoints: Microsoft.Storage + Microsoft.KeyVault so pods can
# reach Blob Storage and Key Vault without traversing the public internet
# (belt-and-suspenders alongside private endpoints).
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_workload_cidr]

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
  ]
}

# ---------------------------------------------------------------------------
# data — PostgreSQL Flexible Server + Redis private endpoints
# private_endpoint_network_policies: disabled so private endpoint NICs
# can be placed in this subnet (Azure requirement).
# ---------------------------------------------------------------------------
resource "azurerm_subnet" "data" {
  name                 = "data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_data_cidr]

  # Required for private endpoints to function in this subnet
  private_endpoint_network_policies = "Disabled"
}

###############################################################################
# NSGs
###############################################################################

# ---------------------------------------------------------------------------
# NSG: system subnet
#
# Rules:
#   ALLOW  AzureLoadBalancer → system  (health probes)
#   ALLOW  workload → system           (kubelet + CNI cross-pool traffic)
#   DENY   Internet → system           (system pool is not internet-facing)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "system" {
  name                = "nsg-system"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-AzureLoadBalancer-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = var.subnet_system_cidr
  }

  security_rule {
    name                       = "Allow-Workload-To-System-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_workload_cidr
    destination_address_prefix = var.subnet_system_cidr
  }

  security_rule {
    name                       = "Deny-Internet-To-System-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.subnet_system_cidr
  }
}

resource "azurerm_subnet_network_security_group_association" "system" {
  subnet_id                 = azurerm_subnet.system.id
  network_security_group_id = azurerm_network_security_group.system.id
}

# ---------------------------------------------------------------------------
# NSG: workload subnet
#
# Rules:
#   ALLOW  Internet → workload:443     (HTTPS — ingress controller)
#   ALLOW  AzureLoadBalancer → workload (health probes)
#   ALLOW  system → workload           (kube-apiserver → kubelet)
#   DENY   Internet → workload (non-443) (block all other internet ingress)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "workload" {
  name                = "nsg-workload"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.subnet_workload_cidr
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = var.subnet_workload_cidr
  }

  security_rule {
    name                       = "Allow-System-To-Workload-Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_system_cidr
    destination_address_prefix = var.subnet_workload_cidr
  }

  security_rule {
    name                       = "Deny-Internet-NonHTTPS-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.subnet_workload_cidr
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

# ---------------------------------------------------------------------------
# NSG: data subnet
#
# Rules:
#   ALLOW  workload → data:5432   (PostgreSQL)
#   ALLOW  workload → data:6380   (Redis TLS)
#   DENY   Internet → data        (data tier is fully internal)
#   DENY   system → data          (system pool has no business reaching data)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "data" {
  name                = "nsg-data"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "Allow-Workload-PostgreSQL-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.subnet_workload_cidr
    destination_address_prefix = var.subnet_data_cidr
  }

  security_rule {
    name                       = "Allow-Workload-Redis-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380" # Redis TLS port
    source_address_prefix      = var.subnet_workload_cidr
    destination_address_prefix = var.subnet_data_cidr
  }

  security_rule {
    name                       = "Deny-Internet-To-Data-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.subnet_data_cidr
  }

  security_rule {
    name                       = "Deny-System-To-Data-Inbound"
    priority                   = 4001
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.subnet_system_cidr
    destination_address_prefix = var.subnet_data_cidr
  }
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}
