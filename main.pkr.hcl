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
  }
}

variable "image_name" {
  type        = string
  default     = "poc-nginx-image"
  description = "Base name for the generated images"
}

variable "image_version" {
  type        = string
  default     = "1.0.0"
  description = "Version of the image (used for deduplication)"
}

variable "force_rebuild" {
  type        = bool
  default     = false
  description = "Force rebuild even if image already exists"
}

variable "skip_create_ami" {
  type        = bool
  default     = false
  description = "Skip AMI creation if one with the same name already exists"
}

variable "gcp_project_id" {
  type        = string
  default     = "packer-images-468118"
  description = "GCP Project ID"
}

# AWS EC2 AMI Source
source "amazon-ebs" "aws" {
  region        = "us-east-1"
  instance_type = "t2.micro"
  ami_name      = "${var.image_name}-aws-v${var.image_version}"
  skip_create_ami = var.skip_create_ami
  
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
    Name        = "${var.image_name}-aws-v${var.image_version}"
    Environment = "poc"
    OS          = "Ubuntu"
    Service     = "nginx"
    Version     = var.image_version
    BuildDate   = "{{timestamp}}"
  }
}

# Google Cloud GCE Image Source
source "googlecompute" "gcp" {
  project_id          = var.gcp_project_id
  zone                = "us-central1-a"
  source_image_family = "ubuntu-2204-lts"
  image_name          = "${var.image_name}-gcp-v${replace(var.image_version, ".", "-")}"
  machine_type        = "e2-micro"
  ssh_username        = "ubuntu"
  
  image_labels = {
    environment = "poc"
    os          = "ubuntu"
    service     = "nginx"
    version     = replace(var.image_version, ".", "-")
    build_date  = "{{timestamp}}"
  }
}

# Build Configuration
build {
  name = "multi-cloud-nginx"
  
  sources = [
    "source.amazon-ebs.aws",
    "source.googlecompute.gcp"
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
