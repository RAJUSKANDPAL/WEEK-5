resource "azurerm_resource_group" "rg" {
  name     = "auto-hosting-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "auto-hosting-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "web_subnet" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "web_ip" {
  name                = "web-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "web_nsg" {
  name                = "web-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "allow-ssh-from-my-ip"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "103.21.91.77/32" # Replace with your public IP
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}
resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow-http"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}


resource "azurerm_network_interface" "web_nic" {
  name                = "web-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "web_nic_nsg" {
  network_interface_id      = azurerm_network_interface.web_nic.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_linux_virtual_machine" "web_vm" {
  name                  = "web-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCi8CpxmBSNHsmVbi09c15JSLBwurQ1NeWx73UHI8COU1j9ra+zvs4m+UHIwJucMfgBZjaH8x1jPlnMGrkP4JEQqaP6ArO9mgaBIRVeFmrM5vY1P9DT/BAmozksAbVJCXNJUJXKGrKqWFqf05N+j3IjuYc7uUlIg6nU+DQQHtWzeEAgLIOKYv2Ayw4jqtFPcbleN0yxpqx5tvB3GiRmFe25ZAKkD2+/FfQAveZntjatEwdUNAkLn6wk/LKl4T/H51SMNEUuS2HjUN0quqOnaQZKdmLYOVPfViQ56XDThjen4q9aQEcaLs56Ka8+gOaPDZIlB/jxNb7B4UUoYCGde0Epo/jcN8geRdnw6RWaeFz8rYFAXdfeUccDLXOwcBhwkGRdyrd/jhpwuH9aPzG6XQHyOd/Ulizr/Y5pJzgxJ6mx212ucQRWiV/JaNfHAIyqj6br1bzS9ZkzUA6EeAEV5J/rHvykArNIcZY86R+Aln2SkrppBd/HDzSV5jT6p6GCPaDHzAqMD81HuHAWb5kzMhe+yv0ITrmqltgk2YS2wS+1PF11pSqKt3CKqQ3ngdAGHhQKfylKUfqZ2BU8LXkcFaiVeU/uhQfJMo3T/igyLHyi1H2q3tZOMkLIQpg/LzaHkxqzGdU5hhsrR1aZItZqWxDdknJuXEqj/NgfSwfaTrd6RQ== rajus@RAJUS"
  }

  disable_password_authentication = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "web-vm-osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<EOF
#!/bin/bash
apt update
apt install -y nginx
echo "<h1>Welcome to Automated Web Hosting</h1><p>Deployed via Terraform!</p>" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx
EOF
  )
}
