# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
  

}



# Configure the resource group
resource "azurerm_resource_group" "CR" {
  name     = "ChrisRistA"
  location = "westus2"

    tags = {
        Environment = "Datacenter Case Study Site A"
        Team = "DevOps"
    }
}


#------------------------Network Deployment---------------------------#
# Deployment of Site A
resource "azurerm_virtual_network" "SITEA" {
  name                = "cr-SiteA"
  address_space       = ["172.16.0.0/16"]
  location            = azurerm_resource_group.CR.location
  resource_group_name = azurerm_resource_group.CR.name
}

# Creation of Subnets
resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.CR.name
  virtual_network_name = azurerm_virtual_network.SITEA.name
  address_prefixes     = ["172.16.100.0/24"]
}
resource "azurerm_subnet" "LAN" {
  name                 = "cr-lan"
  resource_group_name  = azurerm_resource_group.CR.name
  virtual_network_name = azurerm_virtual_network.SITEA.name
  address_prefixes     = ["172.16.200.0/24"]
}
resource "azurerm_subnet" "APP" {
  name                 = "cr-app"
  resource_group_name  = azurerm_resource_group.CR.name
  virtual_network_name = azurerm_virtual_network.SITEA.name
  address_prefixes     = ["172.16.10.0/24"]
}
resource "azurerm_subnet" "STORAGE" {
  name                 = "cr-storage"
  resource_group_name  = azurerm_resource_group.CR.name
  virtual_network_name = azurerm_virtual_network.SITEA.name
  address_prefixes     = ["172.16.20.0/24"]
}
resource "azurerm_subnet" "DOCKER" {
  name                 = "cr-docker"
  resource_group_name  = azurerm_resource_group.CR.name
  virtual_network_name = azurerm_virtual_network.SITEA.name
  address_prefixes     = ["172.16.30.0/24"]
}
resource "azurerm_subnet" "WEB" {
  name                 = "cr-web"
  resource_group_name  = azurerm_resource_group.CR.name
  virtual_network_name = azurerm_virtual_network.SITEA.name
  address_prefixes     = ["172.16.40.0/24"]
}

# Creation of Public IP (Site A Firewall)
resource "azurerm_public_ip" "Apublic" {
  name                = "cr-apublic"
  location            = azurerm_resource_group.CR.location
  resource_group_name = azurerm_resource_group.CR.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# Creation of Public IP (Site A LoadBalancer)
resource "azurerm_public_ip" "lbpublic" {
  name                = "cr-lbpublic"
  location            = azurerm_resource_group.CR.location
  resource_group_name = azurerm_resource_group.CR.name
  allocation_method   = "Static"
}
# Configure the Firewall and Firewall Subnet
resource "azurerm_firewall" "Firewall" {
  name                = "cr-firewall"
  location            = azurerm_resource_group.CR.location
  resource_group_name = azurerm_resource_group.CR.name
  ip_configuration {
    name                 = "cr-fwconfig"
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.Apublic.id
  }
}

#------------------------Load Balancer Deployment---------------------------#

#Internal Loadbalancer on the Storage subnet---------------------------------
resource "azurerm_lb" "LBAInternal" {
 name                = "cr-storageLoadBalancer"
 location              = azurerm_resource_group.CR.location
 resource_group_name   = azurerm_resource_group.CR.name

 frontend_ip_configuration {
   name                 = "lb_ipconfig"
   subnet_id            = azurerm_subnet.STORAGE.id
 }
}

resource "azurerm_lb_backend_address_pool" "LBStorageBackend" {
 loadbalancer_id     = azurerm_lb.LBAInternal.id
 name                = "LBStor-BkEndAddrPool"
}

resource "azurerm_lb_probe" "LBStorageProb" {
  resource_group_name = azurerm_resource_group.CR.name
  loadbalancer_id     = azurerm_lb.LBAInternal.id
  name                = "ssh-running-probe"
  port                = 22
}

#Public Loadbalancer for SITEA ----------------------------------------------
resource "azurerm_lb" "LBAPublic" {
 name                = "cr-SiteALoadBalancer"
 location              = azurerm_resource_group.CR.location
 resource_group_name   = azurerm_resource_group.CR.name

 frontend_ip_configuration {
   name                 = "lb_ipconfig"
   public_ip_address_id = azurerm_public_ip.lbpublic.id
 }
}

resource "azurerm_lb_backend_address_pool" "LBABackend" {
 loadbalancer_id     = azurerm_lb.LBAPublic.id
 name                = "LBA-BkEndAddrPool"
}

resource "azurerm_lb_probe" "LABProb" {
  resource_group_name = azurerm_resource_group.CR.name
  loadbalancer_id     = azurerm_lb.LBAPublic.id
  name                = "ssh-running-probe"
  port                = 22
}




#------------------------Deployment of Virtual Machines---------------------------#

#Creation of Virtual Machines
#Deploying App Server (6 Servers)

resource "azurerm_network_interface" "appNIC" {
 count               = 2
 name                = "acctni${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "AppServConfiguration"
   subnet_id                     = azurerm_subnet.APP.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_availability_set" "Appavset" {
 name                         = "Appavset"
 location                     = azurerm_resource_group.CR.location
 resource_group_name          = azurerm_resource_group.CR.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "appServ" {
  count                 = 2
  name                  = "appServ${count.index}"
  location              = azurerm_resource_group.CR.location
  availability_set_id   = azurerm_availability_set.Appavset.id
  resource_group_name   = azurerm_resource_group.CR.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.appNIC.*.id, count.index)]
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
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}


# Create a File Server
resource "azurerm_network_interface" "FS_nic_storage" {
  name                      = "FS_nic_storage"
  location                  = "westus2"
  resource_group_name       = azurerm_resource_group.CR.name

  ip_configuration {
    name                          = "myNICConfg"
    subnet_id                     = azurerm_subnet.STORAGE.id
    private_ip_address_allocation = "static"
    private_ip_address = "172.16.20.50"
  }
}
resource "azurerm_network_interface" "FS_nic_LAN" {
  name                      = "FS_nic_LAN"
  location                  = "westus2"
  resource_group_name       = azurerm_resource_group.CR.name

  ip_configuration {
        name = "OUT"
        subnet_id = azurerm_subnet.LAN.id
        primary  = true
        private_ip_address_allocation = "static"
        private_ip_address = "172.16.200.50"

  }
}

resource "azurerm_virtual_machine" "FileServ" {
  name                  = "cr-fileserv"
  location              = "westus2"
  resource_group_name   = azurerm_resource_group.CR.name
  network_interface_ids            = ["${azurerm_network_interface.FS_nic_LAN.id}","${azurerm_network_interface.FS_nic_storage.id}"]
  primary_network_interface_id     = "${azurerm_network_interface.FS_nic_LAN.id}"
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
    computer_name  = "cr-fileserv"
    admin_username = "Chris"
    admin_password = "P@ssw0rd1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}




# Create a Domain Controller
resource "azurerm_network_interface" "dc_nic_LAN" {
  name                = "dc_nic_LAN"
  location            = azurerm_resource_group.CR.location
  resource_group_name = azurerm_resource_group.CR.name

  ip_configuration {
    name                          = "myNICConfg"
    subnet_id                     = azurerm_subnet.LAN.id
    private_ip_address_allocation = "static"
    private_ip_address = "172.16.200.55"
  }
}

resource "azurerm_windows_virtual_machine" "domaincontroller" {
  name                = "cr-domaincont"
  resource_group_name = azurerm_resource_group.CR.name
  location            = azurerm_resource_group.CR.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.dc_nic_LAN.id,
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
resource "azurerm_network_interface" "ps_nic_LAN" {
  name                = "ps_nic_LAN"
  location            = azurerm_resource_group.CR.location
  resource_group_name = azurerm_resource_group.CR.name

  ip_configuration {
    name                          = "myNICConfg"
    subnet_id                     = azurerm_subnet.LAN.id
    private_ip_address_allocation = "static"
    private_ip_address = "172.16.200.56"
  }
}

resource "azurerm_windows_virtual_machine" "printServer" {
  name                = "cr-PrintServ"
  resource_group_name = azurerm_resource_group.CR.name
  location            = azurerm_resource_group.CR.location
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







#Create Docker Host (Windows) - 2 Servers

resource "azurerm_network_interface" "DockerNicWebwin" {
 count               = 2
 name                = "docWinNic1${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "DockerNicWeb-win-config"
   subnet_id                     = azurerm_subnet.WEB.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_network_interface" "DockerNicDockNetwin" {
 count               = 2
 name                = "docWinNic2${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "DockerNicDocNet-win-config"
   subnet_id                     = azurerm_subnet.DOCKER.id
   primary  = true
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_availability_set" "dockerAV" {
 name                         = "dockerav"
 location                     = azurerm_resource_group.CR.location
 resource_group_name          = azurerm_resource_group.CR.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "DockerWin" {
  count                 = 2
  name                  = "cr-dockerwin${count.index}"
  location              = azurerm_resource_group.CR.location
  availability_set_id   = azurerm_availability_set.dockerAV.id
  resource_group_name   = azurerm_resource_group.CR.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.DockerNicDockNetwin.*.id, count.index),element(azurerm_network_interface.DockerNicWebwin.*.id, count.index)]
  primary_network_interface_id     = (azurerm_network_interface.DockerNicDockNetwin.*.id)[count.index]
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
    computer_name  = "cr-dockerwin${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
  }

}



#Create Docker Host (Linux) - 4 Servers

resource "azurerm_network_interface" "DockerNicDockNet" {
 count               = 4
 name                = "docNic1${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "DockerNicDocNet-config"
   subnet_id                     = azurerm_subnet.DOCKER.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_virtual_machine" "Docker" {
  count                 = 4
  name                  = "cr-docker${count.index}"
  location              = azurerm_resource_group.CR.location
  availability_set_id   = azurerm_availability_set.dockerAV.id
  resource_group_name   = azurerm_resource_group.CR.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.DockerNicDockNet.*.id, count.index)]
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
    computer_name  = "cr-docker${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}


#Create WebServers - 2 Servers

resource "azurerm_network_interface" "WebservNic" {
 count               = 2
 name                = "WebservNic${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "WebservNic-config"
   subnet_id                     = azurerm_subnet.WEB.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_availability_set" "WebservAV" {
 name                         = "Webservav"
 location                     = azurerm_resource_group.CR.location
 resource_group_name          = azurerm_resource_group.CR.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "Webserv" {
  count                 = 2
  name                  = "cr-webserv${count.index}"
  location              = azurerm_resource_group.CR.location
  availability_set_id   = azurerm_availability_set.WebservAV.id
  resource_group_name   = azurerm_resource_group.CR.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.WebservNic.*.id, count.index)]
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
    computer_name  = "cr-webserv${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}


#Create Exchange Servers - 2 Servers

resource "azurerm_network_interface" "ExchNicStorage" {
 count               = 2
 name                = "ExchNic1${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "ExchNicStorage-win-config"
   subnet_id                     = azurerm_subnet.STORAGE.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_network_interface" "ExchNicLAN" {
 count               = 2
 name                = "ExchNic2${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "ExchNicLAN-win-config"
   subnet_id                     = azurerm_subnet.LAN.id
   primary  = true
   private_ip_address_allocation = "dynamic"
 }
}


resource "azurerm_availability_set" "ExchAV" {
 name                         = "Exchav"
 location                     = azurerm_resource_group.CR.location
 resource_group_name          = azurerm_resource_group.CR.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "Exchange" {
  count                 = 2
  name                  = "cr-exch${count.index}"
  location              = azurerm_resource_group.CR.location
  availability_set_id   = azurerm_availability_set.ExchAV.id
  resource_group_name   = azurerm_resource_group.CR.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.ExchNicLAN.*.id, count.index),element(azurerm_network_interface.ExchNicStorage.*.id, count.index)]
  primary_network_interface_id     = (azurerm_network_interface.ExchNicLAN.*.id)[count.index]
  delete_os_disk_on_termination = true

 storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

 storage_os_disk {
   name              = "ExchOS${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-exch${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_windows_config {
  }

}


#Create Database Servers - 2 Servers

resource "azurerm_network_interface" "dbNicStorage" {
 count               = 2
 name                = "dbNic1${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "dbNicStorage-win-config"
   subnet_id                     = azurerm_subnet.STORAGE.id
   private_ip_address_allocation = "dynamic"
 }
}
resource "azurerm_network_interface" "dbNicLAN" {
 count               = 2
 name                = "dbNic2${count.index}"
 location            = azurerm_resource_group.CR.location
 resource_group_name = azurerm_resource_group.CR.name

 ip_configuration {
   name                          = "dbNicLAN-win-config"
   subnet_id                     = azurerm_subnet.LAN.id
   primary  = true
   private_ip_address_allocation = "dynamic"
 }
}


resource "azurerm_availability_set" "dbAV" {
 name                         = "dbav"
 location                     = azurerm_resource_group.CR.location
 resource_group_name          = azurerm_resource_group.CR.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "Database" {
  count                 = 2
  name                  = "cr-db${count.index}"
  location              = azurerm_resource_group.CR.location
  availability_set_id   = azurerm_availability_set.dbAV.id
  resource_group_name   = azurerm_resource_group.CR.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [element(azurerm_network_interface.dbNicLAN.*.id, count.index),element(azurerm_network_interface.dbNicStorage.*.id, count.index)]
  primary_network_interface_id     = (azurerm_network_interface.dbNicLAN.*.id)[count.index]
  delete_os_disk_on_termination = true

 storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

 storage_os_disk {
   name              = "DatabaseOS${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

   os_profile {
    computer_name  = "cr-db${count.index}"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
    os_profile_linux_config {
    disable_password_authentication = false
  }

}
