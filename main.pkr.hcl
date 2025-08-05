packer {
  required_plugins {
    amazon = { 
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.2.8"
    }
    googlecompute = { 
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.0.0"
    }
    azure = { 
      source  = "github.com/hashicorp/azure"
      version = ">= 1.0.0"
    }
  }
}

variable "image_name" {
  type        = string
  default     = "poc-nginx-image"
  description = "Base name for the generated images"
}

variable "gcp_project_id" {
  type        = string
  default     = "your-gcp-project-id"
  description = "GCP Project ID"
}

variable "azure_client_id" {
  type        = string
  default     = "your-client-id"
  description = "Azure Client ID"
}

variable "azure_client_secret" {
  type        = string
  default     = "your-client-secret"
  description = "Azure Client Secret"
  sensitive   = true
}

variable "azure_tenant_id" {
  type        = string
  default     = "your-tenant-id"
  description = "Azure Tenant ID"
}

variable "azure_subscription_id" {
  type        = string
  default     = "your-subscription-id"
  description = "Azure Subscription ID"
}

variable "azure_resource_group" {
  type        = string
  default     = "your-resource-group"
  description = "Azure Resource Group"
}

# AWS EC2 AMI Source
source "amazon-ebs" "aws" {
  region        = "us-east-1"
  instance_type = "t2.micro"
  ami_name      = "${var.image_name}-aws-{{timestamp}}"
  
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }
  
  ssh_username = "ubuntu"
  
  tags = {
    Name        = "${var.image_name}-aws"
    Environment = "poc"
    OS          = "Ubuntu"
    Service     = "nginx"
  }
}

# Google Cloud GCE Image Source
source "googlecompute" "gcp" {
  project_id          = var.gcp_project_id
  zone                = "us-central1-a"
  source_image_family = "ubuntu-2204-lts"
  image_name          = "${var.image_name}-gcp-{{timestamp}}"
  machine_type        = "e2-micro"
  ssh_username        = "ubuntu"
  
  image_labels = {
    environment = "poc"
    os          = "ubuntu"
    service     = "nginx"
  }
}

# Azure Managed Image Source
source "azure-arm" "azure" {
  client_id                         = var.azure_client_id
  client_secret                     = var.azure_client_secret
  tenant_id                         = var.azure_tenant_id
  subscription_id                   = var.azure_subscription_id
  
  managed_image_name                = "${var.image_name}-azure-{{timestamp}}"
  managed_image_resource_group_name = var.azure_resource_group
  location                          = "East US"
  vm_size                          = "Standard_DS1_v2"
  
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts"
  os_type         = "Linux"
  
  azure_tags = {
    Environment = "poc"
    OS          = "Ubuntu"
    Service     = "nginx"
  }
}

# Build Configuration
build {
  name = "multi-cloud-nginx"
  
  sources = [
    "source.amazon-ebs.aws",
    "source.googlecompute.gcp",
    "source.azure-arm.azure"
  ]

  # Update package cache
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y curl wget"
    ]
  }

  # Copy NGINX installation script
  provisioner "file" {
    source      = "scripts/install_nginx.sh"
    destination = "/tmp/install_nginx.sh"
  }

  # Run NGINX installation and configuration script
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install_nginx.sh",
      "/tmp/install_nginx.sh"
    ]
  }

  # Cleanup and final system preparation
  provisioner "shell" {
    inline = [
      "sudo rm -f /tmp/install_nginx.sh",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "echo 'Image provisioning completed successfully!' | sudo tee /var/log/packer-build.log"
    ]
  }
}
