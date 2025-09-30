terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

####################
# Variables
####################
variable "subscription_id" {
  type        = string
  description = "Azure subscription id"
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "resource_group_name" {
  type    = string
  default = "rg-cosmos-proxy"
}

variable "vnet_name" {
  type    = string
  default = "vnet-cosmos-proxy"
}

variable "subnet_name" {
  type    = string
  default = "snet-appservice"
}

variable "app_service_plan_name" {
  type    = string
  default = "asp-cosmos-proxy"
}

variable "app_service_name" {
  type    = string
  default = "as-cosmos-proxy"
}

variable "cosmos_account_name" {
  type    = string
  default = "cosmosproxyacct001" # must be globally unique and lowercase
}

####################
# Resource Group
####################
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

####################
# Virtual Network + Subnet (with delegation for App Service)
####################
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "appservice_subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

####################
# Public IP (static) for NAT Gateway
####################
resource "azurerm_public_ip" "nat_public_ip" {
  name                = "pip-nat-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    purpose = "nat-static-ip-for-onprem-whitelist"
  }
}

####################
# NAT Gateway + Associations
####################
resource "azurerm_nat_gateway" "natgw" {
  name                    = "nat-gw-cosmos-proxy"
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_association" "natgw_ip" {
  nat_gateway_id       = azurerm_nat_gateway.natgw.id
  public_ip_address_id = azurerm_public_ip.nat_public_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_assoc" {
  subnet_id      = azurerm_subnet.appservice_subnet.id
  nat_gateway_id = azurerm_nat_gateway.natgw.id
}

####################
# App Service Plan + Linux Web App
####################
resource "azurerm_service_plan" "asp" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "app" {
  name                = var.app_service_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      node_version = "18-lts"
    }
    always_on              = true
    vnet_route_all_enabled = true
  }

  app_settings = {
    "COSMOSDB_ACCOUNT_NAME" = azurerm_cosmosdb_account.cosmos.name
    "COSMOSDB_PRIMARY_KEY"  = azurerm_cosmosdb_account.cosmos.primary_key
    "COSMOSDB_URI"          = azurerm_cosmosdb_account.cosmos.endpoint
  }

  identity {
    type = "SystemAssigned"
  }
}

# VNet Integration (Swift) for Linux Web App
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_swift" {
  app_service_id = azurerm_linux_web_app.app.id
  subnet_id      = azurerm_subnet.appservice_subnet.id
}

####################
# Cosmos DB Account (SQL API)
####################
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = var.cosmos_account_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

####################
# Outputs
####################
output "nat_public_ip" {
  description = "Static public IP to give to on-prem firewall for whitelist (NAT Gateway IP)."
  value       = azurerm_public_ip.nat_public_ip.ip_address
}

output "app_service_default_hostname" {
  description = "App Service default domain - use this as proxy endpoint."
  value       = azurerm_linux_web_app.app.default_hostname
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.cosmos.endpoint
}

output "cosmos_primary_key" {
  description = "Cosmos DB primary master key (sensitive). For production use KeyVault."
  value       = azurerm_cosmosdb_account.cosmos.primary_key
  sensitive   = true
}
