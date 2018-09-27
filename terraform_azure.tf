variable "resourcename" {
  default = "myResourceGroup"
}

variable "ARM_SUBSCRIPTION_ID" {}
variable "ARM_CLIENT_ID" {}
variable "ARM_CLIENT_SECRET" {}
variable "ARM_TENANT_ID" {}

# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "${var.ARM_SUBSCRIPTION_ID}"
    client_id       = "${var.ARM_CLIENT_ID}"
    client_secret   = "${var.ARM_CLIENT_SECRET}"
    tenant_id       = "${var.ARM_TENANT_ID}"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "eastus"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

    tags {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.myterraformnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

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

    tags {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.myterraformgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.myterraformnsg.id}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags {
        environment = "Terraform Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.myterraformgroup.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.myterraformgroup.name}"
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Terraform Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
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
        computer_name  = "myvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa B7AlHu+XDEUcMBwvgIbRCXx09dSHdGomkdQSZAQ5mgietjwtKKmRATgqgCZ3BleFaP2TPAhYsvaWEca1PGtY/jkfYsIZt3M0ipwRuxw6FGTMPl8bG8E0/Tgg1cPyrv1nEEbN1lKVAbgenpstYnIshwPJ/bEdVDOVtCdvudfSJeRnPpB8FjQMIjbAkS8xXLc9xENy40MGYNfjm9ZWpMERE0a4y8oIehmKSM0kQLjW6DvPRYVx8H4A7I4Z+Kg4WE7LQwhkSngrWa2nEAbA5Ka9cxIEKvvoml5kkaaUbVK/WUsPY8lc7oIFD43NwVKQomZUNZKkYQhRK7rpTrUI50K7oI75X3/HN1JEC0DLRaROu0e0kZix20U+Ss8+x62NRpz23PbkBOkMF7hUWlhPJqxHFhxE4FzYDxXr0bryCm/X3Sd7Y9/IF3gjmTOcRD2dRG9fCBc3KcgG/iM3EbBrwQHvxpa0cqMo0fpzgqTTRYryaf5xPqidYVCQT4nociegrZvtqcwD6K80AfAz1YlctR/z3zvlYfCo0H/wzQJduu5/xC7cxpAeRJs6xnsDtQoQC0BWjFMhCoFz+KQ1slYbZsp0ojAfRZfQj3EFfE7ECSzGoTHcObtF6LlOZRcNu6P3Pi1pmKouBaBdmehiIDu0f7o0xDOL48AkYRQi0x2Yei8vxj+9utdT4PbclxXy8Tcfeh0zphN6knLjxtJ5jnIhy+hk8mytSXqQJDZwn4DQS0YCjNnKhU2aMzWnREqpO6WDeRmm10/vgKLExEcR7LvAcSqzMV38h3KMWPuTc2BQ4RF6HNRresa7bXat+PYIxyBLmfI8RcNDDN6XvY8EnUivkP6oYUzpTAHH/xNReple7qiv1g1T+dIFnUSkO9ZvQ3+rcdGKYGUD8Jto60BwteNPndScZtUeXFkbpqoR4Eyl9lSLzhSDmK6hUlslDfXB52dTlABlttau9K6EErIiqm7x72F3fUPRCCu4luHt6mnmK2rplcdK6Ykc73MPz66MxfbjkoFN451QrtgH/5ARpVKntxirTkgHa+m34C0K2HQtxaNEJUDyiKFeYOsezzn9JDr/iafW8I1D8ZOkGS7t+rVjb4JY8e9PIOtloOopvbxedgt2pSwokFBkXPm1ckHMsIjMjt4U0nAWQSDvkyurukTjsea8FqTYe4egG74R80kcFeCohlhnBacEsYoXPCWhj79mEODJPFGsvnn9prIX3kFk714qA7q/XBjdw1YtIX7fvk+eG2qHg8eVVPC5Kwez+lzRW3Cp1YKs4yoyL4wCQxQ1pX5oohJ5KlJa+AfAk5bN9TQLiH+PpqDMF7LqSCTy2XBQQWbyXABBJGaBgonPxa8oSpqWULrLhkEpQLFmtU36kwf1rUjjllTgD+lokl50VDua0Xhwfts4ZYetV0EZHMWS3wNN2+Ax40sAoUONEYF1CIirHkNDWX7sQLxH5zwKL1X4WYHQ+HMF1taCLOFKaosL/c4fDpNxjiaKKtBsh9IgrCHB8Ei2tIKhN1OMfUi36DtZPUhxGJ8ptYZGemkX1hfspyUUPP+StyUFnuHsvQNddL95Nce/DUWhWHzMc0/YPuyUWpNf adam@azure"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Demo"
    }
}
