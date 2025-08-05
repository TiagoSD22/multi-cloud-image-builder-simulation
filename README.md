# Multi-Cloud NGINX Image with Packer and Chef

This repository contains a Packer template that builds a standardized Ubuntu 22.04 LTS image with NGINX installed across multiple cloud platforms using Chef as the provisioner.

## 🎯 Supported Platforms

- **AWS EC2 AMI**
- **Google Cloud GCE Image**
- **Azure Managed Image**

## 📋 Prerequisites

### Required Tools
- [Packer](https://www.packer.io/downloads) (>= 1.8.0)
- Valid cloud provider credentials

### Cloud Provider Requirements

#### AWS
- AWS CLI configured or environment variables set:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION`

#### Google Cloud Platform
- Service account key or gcloud CLI authenticated
- Project with Compute Engine API enabled

#### Azure
- Service principal with contributor permissions
- Resource group created for storing images

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <this-repo>
cd packer
```

### 2. Configure Variables
Copy the example variables file and customize it:
```bash
cp variables.pkrvars.hcl.example variables.auto.pkrvars.hcl
```

Edit `variables.auto.pkrvars.hcl` with your specific values:
```hcl
image_name = "my-nginx-image"

# GCP Configuration
gcp_project_id = "my-gcp-project"

# Azure Configuration
azure_client_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_client_secret   = "your-secret-here"
azure_tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
azure_resource_group  = "my-images-rg"
```

### 3. Initialize Packer
```bash
packer init main.pkr.hcl
```

### 4. Validate Template
```bash
packer validate main.pkr.hcl
```

### 5. Build Images

#### Build for all platforms:
```bash
packer build main.pkr.hcl
```

#### Build for specific platform:
```bash
# AWS only
packer build -only="amazon-ebs.aws" main.pkr.hcl

# GCP only
packer build -only="googlecompute.gcp" main.pkr.hcl

# Azure only
packer build -only="azure-arm.azure" main.pkr.hcl
```

## 📁 Project Structure

```
packer/
├── main.pkr.hcl                     # Main Packer template
├── variables.pkrvars.hcl.example    # Example variables file
├── cookbooks/
│   └── nginx/
│       ├── metadata.rb              # Cookbook metadata
│       ├── recipes/
│       │   └── default.rb           # Main recipe
│       └── templates/
│           ├── index.html.erb       # Custom welcome page
│           └── default.erb          # NGINX configuration
└── README.md                        # This file
```

## 🔧 Chef Cookbook Details

The included Chef cookbook (`cookbooks/nginx`) performs the following:

1. **Updates package cache**
2. **Installs NGINX** package
3. **Configures custom welcome page** with cloud deployment information
4. **Sets up optimized NGINX configuration** with:
   - Security headers
   - Gzip compression
   - Health check endpoint (`/health`)
5. **Enables and starts** NGINX service
6. **Opens firewall** for HTTP traffic (if UFW is present)

## 🌐 Image Features

- **Base OS**: Ubuntu 22.04 LTS
- **Web Server**: NGINX (latest stable)
- **Custom Welcome Page**: Shows deployment information
- **Health Check**: Available at `/health` endpoint
- **Security**: Basic security headers configured
- **Performance**: Gzip compression enabled

## 🎛️ Customization

### Modifying the Chef Recipe
Edit `cookbooks/nginx/recipes/default.rb` to customize the NGINX installation and configuration.

### Changing the Welcome Page
Modify `cookbooks/nginx/templates/index.html.erb` to customize the default webpage.

### NGINX Configuration
Update `cookbooks/nginx/templates/default.erb` to modify NGINX server configuration.

## 🔍 Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify cloud provider credentials are correctly configured
   - Check permissions for image creation in each cloud platform

2. **Build Failures**
   - Run `packer validate main.pkr.hcl` to check template syntax
   - Verify all required variables are set in your variables file

3. **Chef Provisioning Issues**
   - Check that cookbook paths are correct
   - Verify Chef client installation succeeds

### Debug Mode
Run Packer with debug flags for detailed output:
```bash
PACKER_LOG=1 packer build main.pkr.hcl
```

## 📊 Output

After successful build, you'll have:

- **AWS**: AMI in the specified region
- **GCP**: Custom image in your project
- **Azure**: Managed image in your resource group

Each image will be tagged with:
- Environment: poc
- OS: ubuntu
- Service: nginx
- Timestamp in the name for uniqueness

## 🔒 Security Considerations

- Images include basic security configurations
- Consider additional hardening for production use
- Regularly update base images to include latest security patches
- Review and customize NGINX security headers as needed

## 📝 License

This project is provided as-is for educational and proof-of-concept purposes.
