# Cloud Provider Setup Guide

This guide provides step-by-step instructions for setting up accounts and credentials for AWS, Google Cloud Platform, and Azure to use with Packer.

## 🔧 AWS Setup

### 1. Create AWS Account
1. Go to [https://aws.amazon.com](https://aws.amazon.com)
2. Click "Create an AWS Account"
3. Follow the registration process (requires credit card)
4. Verify your account via email and phone

### 2. Create IAM User for Packer
1. Log into AWS Console
2. Go to **IAM** → **Users** → **Create user**
3. User name: `packer-user`
4. Select **Programmatic access**
5. Click **Next: Permissions**

### 3. Attach Permissions
Attach these policies to the user:
- `AmazonEC2FullAccess`
- `IAMReadOnlyAccess` (for role assumptions if needed)

Or create a custom policy with minimum permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CopyImage",
                "ec2:CreateImage",
                "ec2:CreateKeypair",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteKeyPair",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSnapshot",
                "ec2:DeleteVolume",
                "ec2:DeregisterImage",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeRegions",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DescribeVpcs",
                "ec2:DetachVolume",
                "ec2:GetPasswordData",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifySnapshotAttribute",
                "ec2:RegisterImage",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances"
            ],
            "Resource": "*"
        }
    ]
}
```

### 4. Get Access Keys
1. After creating the user, download the CSV file with:
   - **Access Key ID**
   - **Secret Access Key**
2. Store these securely

### 5. Configure AWS Credentials

**Option A: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option B: AWS CLI Configuration**
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# Enter your Access Key ID, Secret Access Key, region (us-east-1), and output format (json)
```

**Option C: Credentials File**
Create `~/.aws/credentials`:
```ini
[default]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
```

Create `~/.aws/config`:
```ini
[default]
region = us-east-1
```

---

## ☁️ Google Cloud Platform Setup

### 1. Create GCP Account
1. Go to [https://cloud.google.com](https://cloud.google.com)
2. Click "Get started for free"
3. Sign in with Google account or create one
4. Complete billing setup (requires credit card, but you get $300 free credit)

### 2. Create a New Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click project dropdown → **New Project**
3. Project name: `packer-images-project` (or your preferred name)
4. Note the **Project ID** (will be auto-generated)

### 3. Enable Required APIs
```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Or via Console: APIs & Services → Library → Search "Compute Engine API" → Enable
```

### 4. Create Service Account
1. Go to **IAM & Admin** → **Service Accounts**
2. Click **Create Service Account**
3. Name: `packer-service-account`
4. Description: "Service account for Packer image building"
5. Click **Create and Continue**

### 5. Assign Roles
Assign these roles to the service account:
- `Compute Instance Admin (v1)`
- `Compute Storage Admin`
- `Service Account User`

### 6. Create and Download Key
1. Click on the created service account
2. Go to **Keys** tab → **Add Key** → **Create new key**
3. Choose **JSON** format
4. Download the JSON key file
5. Store it securely (e.g., `~/gcp-packer-key.json`)

### 7. Configure GCP Credentials

**Option A: Environment Variable**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/gcp-packer-key.json"
```

**Option B: Install and Use gcloud CLI**
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate with service account
gcloud auth activate-service-account --key-file=/path/to/your/gcp-packer-key.json

# Set default project
gcloud config set project YOUR_PROJECT_ID
```

---

## 🔷 Azure Setup

### 1. Create Azure Account
1. Go to [https://azure.microsoft.com](https://azure.microsoft.com)
2. Click "Start free" or "Pay as you go"
3. Sign in with Microsoft account or create one
4. Complete verification (requires credit card, but you get $200 free credit)

### 2. Create Resource Group
```bash
# Using Azure CLI (install first)
az group create --name packer-images-rg --location "East US"

# Or via Portal: Resource groups → Create → Name: packer-images-rg → Region: East US
```

### 3. Create Service Principal
```bash
# Create service principal
az ad sp create-for-rbac --name "packer-sp" --role Contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# This will output:
# {
#   "appId": "your-client-id",
#   "displayName": "packer-sp",
#   "password": "your-client-secret",
#   "tenant": "your-tenant-id"
# }
```

### 4. Get Subscription ID
```bash
# Get subscription ID
az account show --query id --output tsv

# Or via Portal: Subscriptions → Copy the Subscription ID
```

### 5. Configure Azure Credentials

**Option A: Environment Variables**
```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

**Option B: Azure CLI Login**
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Set subscription (if you have multiple)
az account set --subscription "your-subscription-id"
```

---

## 🔧 Update Packer Variables

Create your `variables.auto.pkrvars.hcl` file:

```hcl
# Base image name
image_name = "my-nginx-image"

# GCP Configuration
gcp_project_id = "your-actual-project-id"

# Azure Configuration
azure_client_id       = "your-actual-client-id"
azure_client_secret   = "your-actual-client-secret"
azure_tenant_id       = "your-actual-tenant-id"
azure_subscription_id = "your-actual-subscription-id"
azure_resource_group  = "packer-images-rg"
```

## 🚀 Test Your Setup

### Test AWS
```bash
aws sts get-caller-identity
```

### Test GCP
```bash
gcloud auth list
gcloud projects list
```

### Test Azure
```bash
az account show
```

## 🔍 Troubleshooting

### AWS Issues
- **No credentials found**: Set environment variables or configure AWS CLI
- **Access denied**: Check IAM permissions
- **Invalid region**: Ensure region exists and you have access

### GCP Issues
- **Default credentials not found**: Set `GOOGLE_APPLICATION_CREDENTIALS`
- **API not enabled**: Enable Compute Engine API
- **Project not found**: Check project ID spelling

### Azure Issues
- **Invalid tenant**: Check tenant ID format and validity
- **Authentication failed**: Verify client ID and secret
- **Subscription not found**: Confirm subscription ID

## 💡 Cost Optimization Tips

1. **Use smaller instance types** for building (already configured in template)
2. **Build in regions with lower costs**
3. **Clean up failed builds** promptly
4. **Use free tier resources** when available
5. **Set up billing alerts** to monitor costs

## 🔒 Security Best Practices

1. **Use least privilege principle** for service accounts
2. **Rotate credentials regularly**
3. **Store credentials securely** (never commit to git)
4. **Use separate accounts** for different environments
5. **Monitor access logs** for unusual activity

## 🧹 Resource Cleanup

### Important: Clean Up Resources to Avoid Charges

Packer creates images/AMIs that may incur storage costs. Use the provided cleanup script to remove them:

```bash
# See what would be deleted
./cleanup.sh --dry-run

# Clean up all poc-nginx-image* resources
./cleanup.sh

# Clean up with custom prefix
./cleanup.sh --prefix your-image-name
```

### Manual Cleanup Commands

**AWS - Remove AMIs and Snapshots:**
```bash
# List your custom AMIs
aws ec2 describe-images --owners self

# Delete AMI (replace ami-xxx with actual ID)
aws ec2 deregister-image --image-id ami-xxx

# Delete associated snapshots
aws ec2 describe-snapshots --owner-ids self
aws ec2 delete-snapshot --snapshot-id snap-xxx
```

**GCP - Remove Custom Images:**
```bash
# List custom images
gcloud compute images list --no-standard-images

# Delete image
gcloud compute images delete IMAGE_NAME
```

**Azure - Remove Managed Images:**
```bash
# List managed images
az image list

# Delete image
az image delete --name IMAGE_NAME --resource-group RESOURCE_GROUP
```

### Cost Monitoring

- **AWS**: Check EC2 console for AMI storage costs
- **GCP**: Monitor Compute Engine storage in billing
- **Azure**: Check storage costs in cost management

### Automated Cleanup

Consider setting up automated cleanup policies:
- **AWS**: Use lifecycle policies for AMIs
- **GCP**: Set up Cloud Scheduler for image cleanup
- **Azure**: Use Azure Automation for managed image cleanup
