locals {
  environemt = "dev"
  location   = "West Europe"
  pstgrsql_admin_login = var.pstgrsql_admin_login
  pstgrsql_admin_password = var.pstgrsql_admin_password
}

data "azurerm_client_config" "current" {}

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = 69
  }

  byte_length = 8
}


resource "azurerm_resource_group" "rg" {
  name     = "arir_asst_mngmt"
  location = "West Europe"
}

resource "azurerm_service_plan" "asp" {
  name                = "${local.environemt}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  os_type             = "Linux"
  sku_name            = "F1"
}


resource "azurerm_linux_web_app" "app_frontend" {
  name                = "${local.environemt}-app-frontend"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = false
    application_stack {
      node_version = "20-lts"
    }
  }

  https_only                    = true
  public_network_access_enabled = true
}

resource "azurerm_linux_web_app" "app_backend" {
  name                = "${local.environemt}-app-backend"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = false
    application_stack {
      dotnet_version = "8.0"
    }
  }

  https_only                    = true
  public_network_access_enabled = true
}

resource "azurerm_postgresql_server" "postgresql_server" {
  name                = "${local.environemt}-psqrserver"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = local.pstgrsql_admin_login
  administrator_login_password = local.pstgrsql_admin_password

  sku_name   = "B_Gen5_1"
  version    = "11"
  storage_mb = 5120

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  public_network_access_enabled    = true
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
  infrastructure_encryption_enabled = false
}

resource "azurerm_key_vault" "kv" {
  name                        = "${local.environemt}-kv-${random_id.server.hex}"
  location                    = local.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.environemt}-vnet-${random_id.server.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.254.0.0/16"]
}