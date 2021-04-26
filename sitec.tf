# Configure the resource group
resource "azurerm_resource_group" "CRC" {
  name     = "ChrisRistC"
  location = "centralus"

    tags = {
        Environment = "Datacenter Case Study Site C"
        Team = "DevOps"
    }
}

#------------------------Network Deployment---------------------------#
# Deployment of Site B
resource "azurerm_virtual_network" "SITEC" {
  name                = "cr-SiteC"
  address_space       = ["192.168.0.0/16"]
  location            = azurerm_resource_group.CRC.location
  resource_group_name = azurerm_resource_group.CRC.name
}

# Creation of Subnets
resource "azurerm_subnet" "AzureFirewallSubnetC" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.CRC.name
  virtual_network_name = azurerm_virtual_network.SITEC.name
  address_prefixes     = ["192.168.1.0/24"]
}
resource "azurerm_subnet" "LANC" {
  name                 = "cr-lanC"
  resource_group_name  = azurerm_resource_group.CRC.name
  virtual_network_name = azurerm_virtual_network.SITEC.name
  address_prefixes     = ["192.168.160.0/24"]
}
resource "azurerm_subnet" "APPC" {
  name                 = "cr-appC"
  resource_group_name  = azurerm_resource_group.CRC.name
  virtual_network_name = azurerm_virtual_network.SITEC.name
  address_prefixes     = ["192.168.120.0/24"]
}
resource "azurerm_subnet" "WEBC" {
  name                 = "cr-webC"
  resource_group_name  = azurerm_resource_group.CRC.name
  virtual_network_name = azurerm_virtual_network.SITEC.name
  address_prefixes     = ["192.168.0.0/24"]
}


# Creation of Public IP (Site C LoadBalancer)
resource "azurerm_public_ip" "lbpublicC" {
  name                = "cr-lbpublicC"
  location            = azurerm_resource_group.CRC.location
  resource_group_name = azurerm_resource_group.CRC.name
  allocation_method   = "Static"
}
# Creation of Public IP (Site C Firewall)
resource "azurerm_public_ip" "SiteCpublic" {
  name                = "cr-publicC"
  location            = azurerm_resource_group.CRC.location
  resource_group_name = azurerm_resource_group.CRC.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# Configure the Firewall and Firewall Subnet
resource "azurerm_firewall" "SiteCFirewall" {
  name                = "cr-firewallC"
  location            = azurerm_resource_group.CRC.location
  resource_group_name = azurerm_resource_group.CRC.name
  ip_configuration {
    name                 = "cr-fwCconfig"
    subnet_id            = azurerm_subnet.AzureFirewallSubnetC.id
    public_ip_address_id = azurerm_public_ip.SiteCpublic.id
  }
}
#------------------------Load Balancer Deployment---------------------------#
#Internal Loadbalancer on the Web subnet---------------------------------
resource "azurerm_lb" "LBCInternalC" {
 name                = "cr-webLoadBalancerC"
 location              = azurerm_resource_group.CRC.location
 resource_group_name   = azurerm_resource_group.CRC.name

 frontend_ip_configuration {
   name                 = "lb_ipconfig"
   subnet_id            = azurerm_subnet.WEBC.id
 }
}

resource "azurerm_lb_backend_address_pool" "LBwebBackendC" {
 loadbalancer_id     = azurerm_lb.LBCInternalC.id
 name                = "LBweb-BkEndAddrPool"
}

resource "azurerm_lb_probe" "LBwebProbC" {
  resource_group_name = azurerm_resource_group.CRC.name
  loadbalancer_id     = azurerm_lb.LBCInternalC.id
  name                = "ssh-running-probe"
  port                = 22
}
#Public Loadbalancer for SITEC ----------------------------------------------
resource "azurerm_lb" "LBCPublic" {
 name                = "cr-SiteCLoadBalancer"
 location              = azurerm_resource_group.CRC.location
 resource_group_name   = azurerm_resource_group.CRC.name

 frontend_ip_configuration {
   name                 = "lb_ipconfig"
   public_ip_address_id = azurerm_public_ip.lbpublicC.id
 }
}

resource "azurerm_lb_backend_address_pool" "LBCBackendC" {
 loadbalancer_id     = azurerm_lb.LBCPublic.id
 name                = "LBC-BkEndAddrPool"
}

resource "azurerm_lb_probe" "LBCProbC" {
  resource_group_name = azurerm_resource_group.CRC.name
  loadbalancer_id     = azurerm_lb.LBCPublic.id
  name                = "ssh-running-probe"
  port                = 22
}


#------------------------Deployment of Virtual Machines---------------------------#


# Create a File Server

resource "azurerm_network_interface" "FS_nic_LANC" {
  name                      = "FS_nic_LANC"
  location                  = azurerm_resource_group.CRC.location
  resource_group_name       = azurerm_resource_group.CRC.name

  ip_configuration {
        name = "FSLANConfgC"
        subnet_id = azurerm_subnet.LANC.id
        private_ip_address_allocation = "static"
        private_ip_address = "192.168.160.50"

  }
}

resource "azurerm_virtual_machine" "FileServC" {
  name                  = "cr-fileservC"
  location              = azurerm_resource_group.CRC.location
  resource_group_name   = azurerm_resource_group.CRC.name
  network_interface_ids     = [azurerm_network_interface.FS_nic_LANC.id,]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "FileServOS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "cr-fileservC"
    admin_username = "Chris"
    admin_password = "P@ssw0rd1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

# Create a print server
resource "azurerm_network_interface" "ps_nic_LANC" {
  name                = "ps_nic_LANC"
  location            = azurerm_resource_group.CRC.location
  resource_group_name = azurerm_resource_group.CRC.name

  ip_configuration {
    name                          = "psLANConfgC"
    subnet_id                     = azurerm_subnet.LANC.id
    private_ip_address_allocation = "static"
    private_ip_address = "192.168.160.56"
  }
}

resource "azurerm_windows_virtual_machine" "printServerC" {
  name                = "cr-PrintServC"
  resource_group_name = azurerm_resource_group.CRC.name
  location            = azurerm_resource_group.CRC.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.ps_nic_LAN.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

# Create Database Server
resource "azurerm_network_interface" "dbNicAppC" {
  name                      = "dbNic1C"
  location                  = azurerm_resource_group.CRC.location
  resource_group_name       = azurerm_resource_group.CRC.name

  ip_configuration {
    name                          = "dbNicApp-win-config"
    subnet_id                     = azurerm_subnet.APPC.id
    private_ip_address_allocation = "static"
    private_ip_address = "192.168.120.10"
  }
}
resource "azurerm_network_interface" "dbNicLANC" {
  name                      = "dbNic2C"
  location                  = azurerm_resource_group.CRC.location
  resource_group_name       = azurerm_resource_group.CRC.name

  ip_configuration {
        name = "dbNicLAN-win-config"
        subnet_id = azurerm_subnet.LANC.id
        primary  = true
        private_ip_address_allocation = "static"
        private_ip_address = "192.168.160.60"

  }
}

resource "azurerm_virtual_machine" "DatabaseC" {
  name                  = "cr-dbC"
  location              = azurerm_resource_group.CRC.location
  resource_group_name   = azurerm_resource_group.CRC.name
  network_interface_ids            = ["${azurerm_network_interface.dbNicLANC.id}","${azurerm_network_interface.dbNicAppC.id}"]
  primary_network_interface_id     = "${azurerm_network_interface.dbNicLANC.id}"
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "DatabaseOS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "cr-dbC"
    admin_username = "Chris"
    admin_password = "P@ssw0rd1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

}
#Create WebServer

resource "azurerm_network_interface" "WebservNicC" {
 count               = 1
 name                = "WebservNicC${count.index}"
 location            = azurerm_resource_group.CRC.location
 resource_group_name = azurerm_resource_group.CRC.name

 ip_configuration {
   name                          = "WebservNic-config"
   subnet_id                     = azurerm_subnet.WEBC.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_availability_set" "WebservAVC" {
 name                         = "WebservavC"
 location                     = azurerm_resource_group.CRC.location
 resource_group_name          = azurerm_resource_group.CRC.name
 platform_fault_domain_count  = 1
 platform_update_domain_count = 1
 managed                      = true
}

resource "azurerm_virtual_machine" "WebservC" {
  count                 = 1
  name                  = "cr-webservC${count.index}"
  location              = azurerm_resource_group.CRC.location
  availability_set_id   = azurerm_availability_set.WebservAVC.id
  resource_group_name   = azurerm_resource_group.CRC.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.WebservNicC.*.id, count.index)]
  delete_os_disk_on_termination = true

 storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

 storage_os_disk {
   name              = "WebservOS${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-webservC${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}



# Create a Domain Controller
resource "azurerm_network_interface" "dc_nic_LANC" {
  name                = "dc_nic_LANC"
  location            = azurerm_resource_group.CRC.location
  resource_group_name = azurerm_resource_group.CRC.name

  ip_configuration {
    name                          = "dcLANConfg"
    subnet_id                     = azurerm_subnet.LANC.id
    private_ip_address_allocation = "static"
    private_ip_address = "192.168.160.55"
  }
}

resource "azurerm_windows_virtual_machine" "domaincontrollerC" {
  name                = "cr-domainReadC"
  resource_group_name = azurerm_resource_group.CRC.name
  location            = azurerm_resource_group.CRC.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.dc_nic_LANC.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

#Deploying App Server - 2 Servers

resource "azurerm_network_interface" "appNICC" {
 count               = 2
 name                = "appNICC${count.index}"
 location            = azurerm_resource_group.CRC.location
 resource_group_name = azurerm_resource_group.CRC.name

 ip_configuration {
   name                          = "AppServConfiguration"
   subnet_id                     = azurerm_subnet.APPC.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_availability_set" "AppavsetC" {
 name                         = "AppavsetC"
 location                     = azurerm_resource_group.CRC.location
 resource_group_name          = azurerm_resource_group.CRC.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "appServC" {
  count                 = 2
  name                  = "appServC${count.index}"
  location              = azurerm_resource_group.CRC.location
  availability_set_id   = azurerm_availability_set.AppavsetC.id
  resource_group_name   = azurerm_resource_group.CRC.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.appNICC.*.id, count.index)]
  delete_os_disk_on_termination = true

 storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

 storage_os_disk {
   name              = "appServOs${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "appServC${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}





#Create Docker Host (Linux) 1/2
resource "azurerm_network_interface" "DockerNicLANNet1C" {
 name                = "docNic1C"
 location            = azurerm_resource_group.CRC.location
 resource_group_name = azurerm_resource_group.CRC.name

 ip_configuration {
   name                          = "DockerNicLANNet-config"
   subnet_id                     = azurerm_subnet.LANC.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_virtual_machine" "Docker1C" {
  name                  = "cr-dockerC1C"
  location              = azurerm_resource_group.CRC.location
  resource_group_name   = azurerm_resource_group.CRC.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.DockerNicLANNet1C.id]

 storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

 storage_os_disk {
   name              = "DockerLinuxOS1"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-dockerC1"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}

#Create Docker Host (Linux) 2/2
resource "azurerm_network_interface" "DockerNicWEBNet1C" {
 name                = "docNic2C"
 location            = azurerm_resource_group.CRC.location
 resource_group_name = azurerm_resource_group.CRC.name

 ip_configuration {
   name                          = "DockerNicWEBNet-config"
   subnet_id                     = azurerm_subnet.WEBC.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_virtual_machine" "Docker2C" {
  name                  = "cr-dockerC2"
  location              = azurerm_resource_group.CRC.location
  resource_group_name   = azurerm_resource_group.CRC.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.DockerNicWEBNet1C.id]

 storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

 storage_os_disk {
   name              = "DockerLinuxOS2"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-dockerC1"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}

#Create Docker Host (Windows)
resource "azurerm_network_interface" "DockerNicWEBNet2C" {
 name                = "docNic3C"
 location            = azurerm_resource_group.CRC.location
 resource_group_name = azurerm_resource_group.CRC.name

 ip_configuration {
   name                          = "DockerNicWEBNet-config"
   subnet_id                     = azurerm_subnet.WEBC.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_virtual_machine" "DockerWinC" {
  name                  = "cr-dockerwinC"
  location              = azurerm_resource_group.CRC.location
  resource_group_name   = azurerm_resource_group.CRC.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.DockerNicWEBNet1C.id,]

 storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

 storage_os_disk {
   name              = "DockerWindowsOS"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-dockerwinB"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
  }

}
