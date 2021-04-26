# Configure the resource group
resource "azurerm_resource_group" "CRB" {
  name     = "ChrisRistB"
  location = "canadacentral"

    tags = {
        Environment = "Datacenter Case Study Site B"
        Team = "DevOps"
    }
}

#------------------------Network Deployment---------------------------#
# Deployment of Site B
resource "azurerm_virtual_network" "SITEB" {
  name                = "cr-SiteB"
  address_space       = ["10.0.0.0/8"]
  location            = azurerm_resource_group.CRB.location
  resource_group_name = azurerm_resource_group.CRB.name
}

# Creation of Subnets
resource "azurerm_subnet" "AzureFirewallSubnetB" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.CRB.name
  virtual_network_name = azurerm_virtual_network.SITEB.name
  address_prefixes     = ["10.0.0.0/24"]
}
resource "azurerm_subnet" "LANB" {
  name                 = "cr-lanB"
  resource_group_name  = azurerm_resource_group.CRB.name
  virtual_network_name = azurerm_virtual_network.SITEB.name
  address_prefixes     = ["10.100.200.0/24"]
}
resource "azurerm_subnet" "APPB" {
  name                 = "cr-appB"
  resource_group_name  = azurerm_resource_group.CRB.name
  virtual_network_name = azurerm_virtual_network.SITEB.name
  address_prefixes     = ["10.50.25.0/24"]
}
resource "azurerm_subnet" "STORAGEB" {
  name                 = "cr-storageB"
  resource_group_name  = azurerm_resource_group.CRB.name
  virtual_network_name = azurerm_virtual_network.SITEB.name
  address_prefixes     = ["10.10.50.0/24"]
}
resource "azurerm_subnet" "WEBB" {
  name                 = "cr-webB"
  resource_group_name  = azurerm_resource_group.CRB.name
  virtual_network_name = azurerm_virtual_network.SITEB.name
  address_prefixes     = ["10.0.25.0/24"]
}



# Creation of Public IP (Site B Firewall)
resource "azurerm_public_ip" "SiteBpublic" {
  name                = "cr-publicB"
  location            = azurerm_resource_group.CRB.location
  resource_group_name = azurerm_resource_group.CRB.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# Creation of Public IP (Site B LoadBalancer)
resource "azurerm_public_ip" "lbpublicB" {
  name                = "cr-lbpublicB"
  location            = azurerm_resource_group.CRB.location
  resource_group_name = azurerm_resource_group.CRB.name
  allocation_method   = "Static"
}
# Configure the Firewall and Firewall Subnet
resource "azurerm_firewall" "SiteBFirewall" {
  name                = "cr-firewallB"
  location            = azurerm_resource_group.CRB.location
  resource_group_name = azurerm_resource_group.CRB.name
  ip_configuration {
    name                 = "cr-fwBconfig"
    subnet_id            = azurerm_subnet.AzureFirewallSubnetB.id
    public_ip_address_id = azurerm_public_ip.SiteBpublic.id
  }
}
#------------------------Load Balancer Deployment---------------------------#


#Internal Loadbalancer on the App subnet---------------------------------
resource "azurerm_lb" "LBBInternal" {
 name                = "cr-appLoadBalancerB"
 location              = azurerm_resource_group.CRB.location
 resource_group_name   = azurerm_resource_group.CRB.name

 frontend_ip_configuration {
   name                 = "lb_ipconfig"
   subnet_id            = azurerm_subnet.APPB.id
 }
}

resource "azurerm_lb_backend_address_pool" "LBappBackendB" {
 loadbalancer_id     = azurerm_lb.LBBInternal.id
 name                = "LBapp-BkEndAddrPool"
}

resource "azurerm_lb_probe" "LBappProbB" {
  resource_group_name = azurerm_resource_group.CRB.name
  loadbalancer_id     = azurerm_lb.LBBInternal.id
  name                = "ssh-running-probe"
  port                = 22
}

#Public Loadbalancer for SITEB ----------------------------------------------
resource "azurerm_lb" "LBBPublic" {
 name                = "cr-SiteBLoadBalancer"
 location              = azurerm_resource_group.CRB.location
 resource_group_name   = azurerm_resource_group.CRB.name

 frontend_ip_configuration {
   name                 = "lb_ipconfig"
   public_ip_address_id = azurerm_public_ip.lbpublicB.id
 }
}

resource "azurerm_lb_backend_address_pool" "LBBBackendB" {
 loadbalancer_id     = azurerm_lb.LBBPublic.id
 name                = "LBB-BkEndAddrPool"
}

resource "azurerm_lb_probe" "LBBProbB" {
  resource_group_name = azurerm_resource_group.CRB.name
  loadbalancer_id     = azurerm_lb.LBBPublic.id
  name                = "ssh-running-probe"
  port                = 22
}
#------------------------Deployment of Virtual Machines---------------------------#


# Create a File Server
resource "azurerm_network_interface" "FS_nic_webserverB" {
  name                      = "FS_nic_webservB"
  location                  = azurerm_resource_group.CRB.location
  resource_group_name       = azurerm_resource_group.CRB.name

  ip_configuration {
    name                          = "FSWEBConfg"
    subnet_id                     = azurerm_subnet.WEBB.id
    private_ip_address_allocation = "static"
    private_ip_address = "10.0.25.50"
  }
}
resource "azurerm_network_interface" "FS_nic_LANB" {
  name                      = "FS_nic_LANB"
  location                  = azurerm_resource_group.CRB.location
  resource_group_name       = azurerm_resource_group.CRB.name

  ip_configuration {
        name = "FSLANConfg"
        subnet_id = azurerm_subnet.LANB.id
        primary  = true
        private_ip_address_allocation = "static"
        private_ip_address = "10.100.200.50"

  }
}

resource "azurerm_virtual_machine" "FileServB" {
  name                  = "cr-fileservB"
  location              = azurerm_resource_group.CRB.location
  resource_group_name   = azurerm_resource_group.CRB.name
  network_interface_ids            = ["${azurerm_network_interface.FS_nic_LANB.id}","${azurerm_network_interface.FS_nic_webserverB.id}"]
  primary_network_interface_id     = "${azurerm_network_interface.FS_nic_LANB.id}"
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
    computer_name  = "cr-fileservB"
    admin_username = "Chris"
    admin_password = "P@ssw0rd1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}




# Create a Domain Controller
resource "azurerm_network_interface" "dc_nic_LANB" {
  name                = "dc_nic_LANB"
  location            = azurerm_resource_group.CRB.location
  resource_group_name = azurerm_resource_group.CRB.name

  ip_configuration {
    name                          = "dcLANConfg"
    subnet_id                     = azurerm_subnet.LANB.id
    private_ip_address_allocation = "static"
    private_ip_address = "10.100.200.55"
  }
}

resource "azurerm_windows_virtual_machine" "domaincontrollerB" {
  name                = "cr-domaincontB"
  resource_group_name = azurerm_resource_group.CRB.name
  location            = azurerm_resource_group.CRB.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.dc_nic_LANB.id,
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


# Create a print server
resource "azurerm_network_interface" "ps_nic_LANB" {
  name                = "ps_nic_LANB"
  location            = azurerm_resource_group.CRB.location
  resource_group_name = azurerm_resource_group.CRB.name

  ip_configuration {
    name                          = "psLANConfg"
    subnet_id                     = azurerm_subnet.LANB.id
    private_ip_address_allocation = "static"
    private_ip_address = "10.100.200.56"
  }
}

resource "azurerm_windows_virtual_machine" "printServerB" {
  name                = "cr-PrintServB"
  resource_group_name = azurerm_resource_group.CRB.name
  location            = azurerm_resource_group.CRB.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.ps_nic_LANB.id,
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
resource "azurerm_network_interface" "dbNicStorageB" {
  name                      = "dbNic1B"
  location                  = azurerm_resource_group.CRB.location
  resource_group_name       = azurerm_resource_group.CRB.name

  ip_configuration {
    name                          = "dbNicStorage-win-config"
    subnet_id                     = azurerm_subnet.STORAGEB.id
    private_ip_address_allocation = "static"
    private_ip_address = "10.10.50.10"
  }
}
resource "azurerm_network_interface" "dbNicLANB" {
  name                      = "dbNic2B"
  location                  = azurerm_resource_group.CRB.location
  resource_group_name       = azurerm_resource_group.CRB.name

  ip_configuration {
        name = "dbNicLAN-win-config"
        subnet_id = azurerm_subnet.LANB.id
        primary  = true
        private_ip_address_allocation = "static"
        private_ip_address = "10.100.200.60"

  }
}

resource "azurerm_virtual_machine" "DatabaseB" {
  name                  = "cr-dbB"
  location              = azurerm_resource_group.CRB.location
  resource_group_name   = azurerm_resource_group.CRB.name
  network_interface_ids            = ["${azurerm_network_interface.dbNicLANB.id}","${azurerm_network_interface.dbNicStorageB.id}"]
  primary_network_interface_id     = "${azurerm_network_interface.dbNicLANB.id}"
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
    computer_name  = "cr-dbB"
    admin_username = "Chris"
    admin_password = "P@ssw0rd1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}


#Create WebServers - 2 Servers

resource "azurerm_network_interface" "WebservNicB" {
 count               = 2
 name                = "WebservNicB${count.index}"
 location            = azurerm_resource_group.CRB.location
 resource_group_name = azurerm_resource_group.CRB.name

 ip_configuration {
   name                          = "WebservNic-configB"
   subnet_id                     = azurerm_subnet.WEBB.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_availability_set" "WebservAVB" {
 name                         = "WebservavB"
 location                     = azurerm_resource_group.CRB.location
 resource_group_name          = azurerm_resource_group.CRB.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "WebservB" {
  count                 = 2
  name                  = "cr-webservB${count.index}"
  location              = azurerm_resource_group.CRB.location
  availability_set_id   = azurerm_availability_set.WebservAV.id
  resource_group_name   = azurerm_resource_group.CRB.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.WebservNicB.*.id, count.index)]
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
    computer_name  = "cr-webservB${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}

#Deploying App Server - 2 Servers

resource "azurerm_network_interface" "appNICB" {
 count               = 2
 name                = "appNICB${count.index}"
 location            = azurerm_resource_group.CRB.location
 resource_group_name = azurerm_resource_group.CRB.name

 ip_configuration {
   name                          = "AppServConfiguration"
   subnet_id                     = azurerm_subnet.APPB.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_availability_set" "AppavsetB" {
 name                         = "AppavsetB"
 location                     = azurerm_resource_group.CRB.location
 resource_group_name          = azurerm_resource_group.CRB.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "appServB" {
  count                 = 2
  name                  = "appServB${count.index}"
  location              = azurerm_resource_group.CRB.location
  availability_set_id   = azurerm_availability_set.Appavset.id
  resource_group_name   = azurerm_resource_group.CRB.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.appNICB.*.id, count.index)]
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
    computer_name  = "appServB${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}


#Create Docker Host (Windows) - 3 Servers

resource "azurerm_network_interface" "DockerNicWebwinB" {
 count               = 2
 name                = "docWinNic1B${count.index}"
 location            = azurerm_resource_group.CRB.location
 resource_group_name = azurerm_resource_group.CRB.name

 ip_configuration {
   name                          = "DockerNicWeb-win-config"
   subnet_id                     = azurerm_subnet.WEBB.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_network_interface" "DockerNicAppNetwinB" {
 count               = 2
 name                = "docWinNic2B${count.index}"
 location            = azurerm_resource_group.CRB.location
 resource_group_name = azurerm_resource_group.CRB.name

 ip_configuration {
   name                          = "DockerNicAppNet-win-config"
   subnet_id                     = azurerm_subnet.APPB.id
   primary  = true
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_availability_set" "dockerAVB" {
 name                         = "dockeravB"
 location                     = azurerm_resource_group.CRB.location
 resource_group_name          = azurerm_resource_group.CRB.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "DockerWinB" {
  count                 = 2
  name                  = "cr-dockerwinB${count.index}"
  location              = azurerm_resource_group.CRB.location
  availability_set_id   = azurerm_availability_set.dockerAV.id
  resource_group_name   = azurerm_resource_group.CRB.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.DockerNicAppNetwinB.*.id, count.index),element(azurerm_network_interface.DockerNicWebwinB.*.id, count.index)]
  primary_network_interface_id     = (azurerm_network_interface.DockerNicAppNetwinB.*.id)[count.index]
  delete_os_disk_on_termination = true

 storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

 storage_os_disk {
   name              = "DockerWindowsOS${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-dockerwinB${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
  }

}



#Create Docker Host (Linux) - 2 Servers

resource "azurerm_network_interface" "DockerNicAppNetB" {
 count               = 2
 name                = "docNic1B${count.index}"
 location            = azurerm_resource_group.CRB.location
 resource_group_name = azurerm_resource_group.CRB.name

 ip_configuration {
   name                          = "DockerNicAppNet-config"
   subnet_id                     = azurerm_subnet.APPB.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_virtual_machine" "DockerB" {
  count                 = 2
  name                  = "cr-dockerB${count.index}"
  location              = azurerm_resource_group.CRB.location
  availability_set_id   = azurerm_availability_set.dockerAV.id
  resource_group_name   = azurerm_resource_group.CRB.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.DockerNicAppNetB.*.id, count.index)]
  delete_os_disk_on_termination = true

 storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

 storage_os_disk {
   name              = "DockerLinuxOS${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-dockerB${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}
