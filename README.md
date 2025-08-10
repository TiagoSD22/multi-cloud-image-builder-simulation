# Multi-Cloud NGINX Image with Packer

This repository contains a Packer template that builds a standardized Ubuntu 22.04 LTS image with NGINX installed across AWS and Google Cloud Platform using shell script provisioning.

## 🎯 Supported Platforms

- **AWS EC2 AMI**
- **Google Cloud GCE Image**

## 📋 Prerequisites

### Required Tools
- [Packer](https://www.packer.io/downloads) (>= 1.8.0)
- Valid cloud provider credentials (see [Cloud Setup Guide](CLOUD_SETUP.md) for detailed instructions)

### Cloud Provider Requirements

> 📖 **For detailed setup instructions, see [CLOUD_SETUP.md](CLOUD_SETUP.md)**

#### AWS
- AWS account with IAM user that has EC2 permissions
- Access Key ID and Secret Access Key
- Configure via environment variables, AWS CLI, or credentials file

#### Google Cloud Platform
- GCP account with billing enabled
- Project with Compute Engine API enabled
- Service account with Compute permissions and JSON key file

### Quick Credential Setup

**AWS:**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**GCP:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

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

# GCP Configuration 
gcp_project_id        = "my-gcp-project"
```

### 3. Initialize Packer and Install Plugins
```bash
packer init main.pkr.hcl
```

This will automatically install the required plugins:
- Amazon plugin for AWS AMI building
- Google Cloud plugin for GCE image building

### 4. Validate Template
```bash
packer validate main.pkr.hcl
```

### 5. Build Images

#### Pre-build Validation (Recommended)
Check for existing images to prevent duplicates:
```bash
# Check if images already exist
chmod +x validate-build.sh
./validate-build.sh

# Check with specific version
./validate-build.sh --name my-image --version 2.1.0

# Auto-increment version if conflicts found
./validate-build.sh --auto-increment
```

#### Build for all platforms:
```bash
# With validation (recommended)
./build.sh

# Skip validation (if you want to force rebuild)
./build.sh --skip-validation

# Traditional packer command
packer build main.pkr.hcl
```

#### Build for specific platform:
```bash
# AWS only
./build.sh --platform aws
packer build -only="amazon-ebs.aws" main.pkr.hcl

# GCP only  
./build.sh --platform gcp
packer build -only="googlecompute.gcp" main.pkr.hcl

# GCP only  
./build.sh --platform gcp
packer build -only="googlecompute.gcp" main.pkr.hcl
```

#### Version Management:
```bash
# Build with specific version
packer build -var="image_version=2.1.0" main.pkr.hcl

# Force rebuild (replace existing images)
packer build -var="force_rebuild=true" main.pkr.hcl

# Skip AMI creation if exists (AWS only)
packer build -var="skip_create_ami=true" main.pkr.hcl
```

## 📁 Project Structure

```
packer/
├── main.pkr.hcl                     # Main Packer template
├── variables.pkrvars.hcl.example    # Example variables file
├── build.sh                         # Build automation script for AlmaLinux/RHEL
├── validate-build.sh                # Pre-build validation script (prevents duplicates)
├── cleanup.sh                       # Complete resource cleanup script
├── emergency-cleanup.sh             # Emergency instance termination script
├── check-credentials.sh              # Credential validation script
├── scripts/
│   └── install_nginx.sh             # NGINX installation and configuration script
├── CLOUD_SETUP.md                   # Detailed cloud provider setup guide
└── README.md                        # This file
```

## 🔧 Provisioning Details

The template uses **shell script provisioning** with **version-based naming** which:

1. **Prevents duplicate resources** by using versioned image names
2. **Pre-build validation** checks for existing images before building
3. **Updates package cache** and installs dependencies
4. **Copies the installation script** to the target instance
5. **Executes the NGINX installation script** which:
   - Installs NGINX package
   - Creates a custom welcome page
   - Configures optimized NGINX settings
   - Sets up security headers and compression
   - Creates health check endpoint
   - Enables and starts the service
6. **Cleans up** temporary files after provisioning

### Deduplication Features

- **Version-based naming**: Images use `image-name-v1.0.0` format instead of timestamps
- **Pre-build validation**: Checks if images already exist before starting build
- **Force rebuild option**: Can override existing images when needed
- **Auto-increment**: Automatically bump version numbers when conflicts found
- **Skip AMI creation**: Option to skip AWS AMI creation if one already exists

The included installation script (`scripts/install_nginx.sh`) performs the following:

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

### Modifying the Installation Script
Edit `scripts/install_nginx.sh` to customize the NGINX installation and configuration.

### Changing the Welcome Page
Modify the HTML content in `scripts/install_nginx.sh` to customize the default webpage.

### NGINX Configuration
Update the server configuration block in `scripts/install_nginx.sh` to modify NGINX server settings.

## 🔍 Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify cloud provider credentials are correctly configured
   - Check permissions for image creation in each cloud platform

2. **Build Failures**
   - Run `packer validate main.pkr.hcl` to check template syntax
   - Verify all required variables are set in your variables file

3. **Script Provisioning Issues**
   - Check that the installation script exists at `scripts/install_nginx.sh`
   - Verify script has proper permissions and is executable
   - Check script syntax if provisioning fails

4. **Plugin Installation Issues**
   - Run `packer init main.pkr.hcl` to install all required plugins
   - Check internet connectivity for plugin downloads
   - Verify Packer version supports the plugin system (>= 1.7.0)

### Debug Mode
Run Packer with debug flags for detailed output:
```bash
PACKER_LOG=1 packer build main.pkr.hcl
```

## 📊 Output

After successful build, you'll have:

- **AWS**: AMI in the specified region
- **GCP**: Custom image in your project

Each image will be tagged with:
- Environment: poc
- OS: ubuntu
- Service: nginx
- Timestamp in the name for uniqueness

## 🧹 Cleanup Resources

To remove all resources created by Packer builds:

### Emergency Instance Cleanup (for running instances)
If Packer builds fail or get interrupted, instances might be left running:

```bash
# See what instances are running
chmod +x emergency-cleanup.sh
./emergency-cleanup.sh --dry-run

# Terminate all running Packer instances immediately
./emergency-cleanup.sh

# Force cleanup without prompts
./emergency-cleanup.sh --force
```

### Complete Resource Cleanup (images + instances + other resources)
```bash
# See what would be deleted (dry run)
chmod +x cleanup.sh
./cleanup.sh --dry-run

# Delete all images and resources with default prefix (poc-nginx-image)
./cleanup.sh

# Delete images with custom prefix
./cleanup.sh --prefix my-custom-image

# Force cleanup without prompts
./cleanup.sh --force
```

### What Gets Cleaned Up

**AWS:**
- ✅ Running/stopped EC2 instances created by Packer
- ✅ AMIs (Amazon Machine Images)
- ✅ Associated EBS snapshots
- ✅ Packer-created security groups
- ✅ Packer-created key pairs

**GCP:**
- ✅ Running Packer compute instances
- ✅ Custom compute images

### Manual Cleanup

**AWS AMIs:**
```bash
# List your AMIs
aws ec2 describe-images --owners self --query "Images[?starts_with(Name, 'poc-nginx-image')].{ImageId:ImageId,Name:Name}"

# Delete specific AMI and its snapshots
aws ec2 deregister-image --image-id ami-12345678
aws ec2 delete-snapshot --snapshot-id snap-12345678
```

**GCP Images:**
```bash
# List your images
gcloud compute images list --filter="name~^poc-nginx-image.*"

# Delete specific image
gcloud compute images delete poc-nginx-image-gcp-1234567890
```

## 🔒 Security Considerations

- Images include basic security configurations
- Consider additional hardening for production use
- Regularly update base images to include latest security patches
- Review and customize NGINX security headers as needed

## 📝 License

This project is provided as-is for educational and proof-of-concept purposes.
