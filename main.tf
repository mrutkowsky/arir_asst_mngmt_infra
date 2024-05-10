locals {
  environemt              = "dev"
  location                = "West Europe"
  pstgrsql_admin_login    = var.pstgrsql_admin_login
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
  sku_name            = "P0v3"
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


resource "azurerm_virtual_network" "vnet" {
  name                = "${local.environemt}-vnet-${random_id.server.hex}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "frontend_subnet" {
  name                 = "vnet-integration-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]

  delegation {
    name = "sf"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
  }

  private_endpoint_network_policies_enabled = false
}

resource "azurerm_subnet" "backend_private_endpoint_subnet" {
  name                 = "backend-private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  private_endpoint_network_policies_enabled = true
}

resource "azurerm_private_dns_zone" "private_endpoint_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "backend_private_endpoint_dns_zone_vnet_link" {
  name                  = "backendApiDnsZone"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private_endpoint_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_private_endpoint" "pe_backend_api" {
  name                = "backendApiPrivateEndpoint"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.backend_private_endpoint_subnet.id

  private_service_connection {
    is_manual_connection           = false
    name                           = "backendApiConnection"
    private_connection_resource_id = azurerm_linux_web_app.app_backend.id
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "backendApiDnsZone"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_endpoint_dns_zone.id]
  }
}

resource "azurerm_private_dns_a_record" "ar_backend_api" {
  name                = "backendapi-ar"
  zone_name           = azurerm_private_dns_zone.postgresql_dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.pe_backend_api.private_service_connection[0].private_ip_address]
}


resource "azurerm_subnet" "postgesql_private_endpoint_subnet" {
  name                 = "postgesql-private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  # delegation {
  #   name = "fs"
  #   service_delegation {
  #     name = "Microsoft.DBforPostgreSQL/flexibleServers"
  #     actions = [
  #       "Microsoft.Network/virtualNetworks/subnets/join/action",
  #     ]
  #   }
  # }
}

resource "azurerm_private_dns_zone" "postgresql_dns_zone" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_flexible_server_dns_zone_vnet_link" {
  name                  = "postgresqlDnsZone"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "ar" {
  name                = "postgresql-ar"
  zone_name           = azurerm_private_dns_zone.postgresql_dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.pe_postgresql.private_service_connection[0].private_ip_address]
}

resource "azurerm_postgresql_server" "postgresql_server" {
  name                         = "psql${random_id.server.hex}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = local.location
  version                      = "10"
  administrator_login          = "psqladmin"
  administrator_login_password = "H@Sh1CoR3!"

  storage_mb = 32768

  sku_name                         = "GP_Gen5_2"
  ssl_enforcement_enabled          = true
  geo_redundant_backup_enabled     = false
  auto_grow_enabled                = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
  public_network_access_enabled    = false
}

resource "azurerm_private_endpoint" "pe_postgresql" {
  name                = "postgreSqlPrivateEndpoint"
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.postgesql_private_endpoint_subnet.id

  private_service_connection {
    is_manual_connection           = false
    name                           = "postgreSqlConnection"
    private_connection_resource_id = azurerm_postgresql_server.postgresql_server.id
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "postgresqlServerDnsZone"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_endpoint_dns_zone.id]
  }
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
