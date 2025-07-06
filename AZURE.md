
# 📘 R&D Document: Azure Networking and Access Control Using Terraform

## 📌 Title  
**Implementation of Azure Networking and Access Control Using Terraform**

## 👨‍💻 Author  
Rajus Kandpal

## 🗓️ Date  
06 July 2025

---

## 📚 Table of Contents
- [1. Introduction](#1-introduction)
- [2. Objectives](#2-objectives)
- [3. Concepts & Definitions](#3-concepts--definitions)
- [4. Terraform Implementation](#4-terraform-implementation)
- [5. Summary](#5-summary)
- [6. References](#6-references)

---

## 1. Introduction

This document outlines the research and implementation of network-level security and VM provisioning for Azure using Terraform. The focus is on NSGs, Public IPs, VM NICs, and automating web hosting.

---

## 2. Objectives

- Deploy Azure infrastructure using Infrastructure as Code (IaC).
- Configure NSGs to allow only specific IPs and deny others.
- Use static public IPs for predictable VM access.
- Provision Linux VM and install NGINX on startup.

---

## 3. Concepts & Definitions

- **NSG**: Network Security Groups manage traffic to NICs or subnets.
- **Public IP (Static)**: Assigned permanently to a resource.
- **NIC**: Network Interface connecting VM to subnet and public IP.
- **ASG**: Not used in this scope but helps group NICs logically.
- **Custom Data**: Used for auto-installing NGINX at boot time.

---

## 4. Terraform Implementation

### Complete Terraform Script:

```hcl
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

```


```
variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central India"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "rajusadmin"
}

```


```
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90.0"
    }
  }
}

provider "azurerm" {
  features {}
}

```


```
location       = "Central India"
admin_username = "rajusadmin"

```
#### Commands involved
```
terraform init
terraform plan
terraform apply
```
---

## 5. Summary

This updated setup provisions a full network and compute environment for automated web hosting using Azure and Terraform. It ensures controlled access, static IP addressing, and automated configuration of NGINX.

---

## 6. References

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Public IP](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-addresses)
- [Azure Linux VM](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/terraform-create-complete-vm)
