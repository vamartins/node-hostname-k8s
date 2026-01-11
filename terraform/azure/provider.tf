terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-cloudops-tf-prod-weu"
    storage_account_name = "stcloudopstfprodweu"
    container_name       = "tfstate"
    key                  = "node-hostname-aks.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
