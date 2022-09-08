# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "eastus"
}


#################################################################################################
#Network LB Rules

resource "azurerm_virtual_network" "rg" {
  name                = "vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "rg" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.2.0/24"]
}

 resource "azurerm_public_ip" "rg" {
   name                         = "publicIPForLB"
   location                     = azurerm_resource_group.rg.location
   resource_group_name          = azurerm_resource_group.rg.name
   allocation_method            = "Static"
   sku = "Standard"
 }

resource "azurerm_lb" "rg" {
   name                = "loadBalancer"
   location            = azurerm_resource_group.rg.location
   resource_group_name = azurerm_resource_group.rg.name
   sku                 = "Standard"

   frontend_ip_configuration {
     name                 = "publicIPAddress"
     public_ip_address_id = azurerm_public_ip.rg.id
   }
 }

 resource "azurerm_lb_backend_address_pool" "rg" {
   loadbalancer_id     = azurerm_lb.rg.id
   name                = "BackEndAddressPool"
 }

resource "azurerm_network_security_group" "sec-group" {
  name                = "sec-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

# We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "Allow_Out"
    priority                   = 201
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  
}

resource "azurerm_subnet_network_security_group_association" "sec-group-association" {
  subnet_id                 = azurerm_subnet.rg.id
  network_security_group_id = azurerm_network_security_group.sec-group.id
  depends_on = [ azurerm_network_security_group.sec-group ]
}

resource "azurerm_lb_nat_rule" "tcp" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.rg.id
  name                           = "RDP-VM-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = "3389"
  frontend_ip_configuration_name = "publicIPAddress"
  count                          = 2
}

resource "azurerm_lb_nat_rule" "winrm" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.rg.id
  name                           = "WinRM-VM-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = "5001${count.index + 1}"
  backend_port                   = "5985"
  frontend_ip_configuration_name = "publicIPAddress"
  count                          = 2
}

resource "azurerm_lb_nat_rule" "winrm-sec" {
  count                          = 2
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.rg.id
  name                           = "WinRM-s-VM-${count.index + 1}"
  protocol                       = "Tcp"
  frontend_port                  = "5002${count.index + 1}"
  backend_port                   = "5986"
  frontend_ip_configuration_name = "publicIPAddress"

}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.rg.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = "80"
  backend_port                   = "80"
  frontend_ip_configuration_name = "publicIPAddress"
  enable_floating_ip             = "false"
  idle_timeout_in_minutes        = "5"
  probe_id                       = azurerm_lb_probe.lb_probe.id
  depends_on                     = [ azurerm_lb_probe.lb_probe ]
}

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id     = azurerm_lb.rg.id
  name                = "tcpProbe"
  protocol            = "Tcp"
  port                = "80"
  interval_in_seconds = "5"
  number_of_probes    = "2"
}

resource "azurerm_network_interface_nat_rule_association" "natrule" {
  network_interface_id  = element(azurerm_network_interface.rg.*.id, count.index)
  ip_configuration_name = "testConfiguration"
  nat_rule_id           = element(azurerm_lb_nat_rule.tcp.*.id, count.index)
  count                 = 2
}

 resource "azurerm_network_interface" "rg" {
   count               = 2
   name                = "nic-${count.index}"
   location            = azurerm_resource_group.rg.location
   resource_group_name = azurerm_resource_group.rg.name

   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = azurerm_subnet.rg.id
     private_ip_address_allocation = "Dynamic"
   }
 }

#################################################################################################
#VMs

locals {
  count = 2
  admin_username       = "iamadmin1"
  admin_password       = "MyPasswordStrong2022"
  zones = ["1","2"]
}


resource "azurerm_windows_virtual_machine" "rg" {
  count = 2
  name = "Server2019-${count.index}"
  admin_username       = "iamadmin1"
  admin_password       = "MyPasswordStrong2022"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.rg[count.index].id]
  size               = "Standard_F2"
  zone = var.zone[count.index]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

}

