terraform {
  backend "azurerm" {
    resource_group_name  = "student"
    storage_account_name = "studentexample"
    container_name       = "student"
    key                  = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

locals {
  vms = {
    "vm-001" = {
      vm_size          = "Standard_B1s"
      assign_public_ip = true
    }
    "vm-002" = {
      vm_size          = "Standard_B1s"
      assign_public_ip = false
    }
  }
}

resource "azurerm_virtual_network" "example" {
  name                = "example-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = "student"
}

resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = "student"
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "existing_pip" {
  name                = "Public-ip"
  resource_group_name = "student"
  location            = "East US"
  allocation_method   = "Static"
  sku                 = "Standard"

}

resource "azurerm_network_interface" "example" {
  for_each            = local.vms
  name                = "nic-${each.key}"
  location            = "East US"
  resource_group_name = "student"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = each.value.assign_public_ip ? azurerm_public_ip.existing_pip.id : null
  }
}

resource "azurerm_linux_virtual_machine" "example" {
  for_each                        = local.vms
  name                            = each.key
  resource_group_name             = "student"
  location                        = "East US"
  size                            = each.value.vm_size
  admin_username                  = "azureuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.example[each.key].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "vm-nsg"
  location            = "East US"
  resource_group_name = "student"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_assoc" {
  network_interface_id      = azurerm_network_interface.example["vm-001"].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
