terraform {
  cloud {
    organization = "ARiR"

    workspaces {
      name = "arir-asst-mngmt-dev"
    }
  }

    required_providers {
    azurerm = {
        source  = "hashicorp/azurerm"
        version = "=3.98.0"
    }
  } 
}

provider "azurerm" {
  features {}
}