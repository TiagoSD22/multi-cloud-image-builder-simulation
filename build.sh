#!/bin/bash

# Multi-Cloud Image Build Script for AlmaLinux/RHEL
# This bash script helps automate the Packer build process

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PLATFORM="all"
VARS_FILE="variables.auto.pkrvars.hcl"
DEBUG=false
VALIDATE_ONLY=false

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --platform PLATFORM    Cloud platform to build for (aws|gcp|azure|all) [default: all]"
    echo "  -v, --vars-file FILE        Variables file to use [default: variables.auto.pkrvars.hcl]"
    echo "  -d, --debug                 Enable debug mode"
    echo "  -t, --validate-only         Only validate, don't build"
    echo "  -h, --help                  Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Build for all platforms"
    echo "  $0 -p aws                   # Build only for AWS"
    echo "  $0 -d -p gcp                # Build for GCP with debug enabled"
    echo "  $0 -t                       # Only validate template"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            PLATFORM="$2"
            if [[ ! "$PLATFORM" =~ ^(aws|gcp|azure|all)$ ]]; then
                echo -e "${RED}❌ Invalid platform: $PLATFORM${NC}"
                echo "Valid options: aws, gcp, azure, all"
                exit 1
            fi
            shift 2
            ;;
        -v|--vars-file)
            VARS_FILE="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -t|--validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

echo -e "${CYAN}🚀 Multi-Cloud NGINX Image Builder${NC}"
echo -e "${CYAN}=================================${NC}"

# Check if Packer is installed
if command -v packer &> /dev/null; then
    PACKER_VERSION=$(packer version | head -n1)
    echo -e "${GREEN}✅ Packer found: $PACKER_VERSION${NC}"
else
    echo -e "${RED}❌ Packer not found. Please install Packer first.${NC}"
    echo "Installation instructions: https://www.packer.io/downloads"
    echo ""
    echo "For AlmaLinux/RHEL, you can install using:"
    echo "  sudo dnf install -y dnf-plugins-core"
    echo "  sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo"
    echo "  sudo dnf install packer"
    exit 1
fi

# Check if variables file exists
if [[ ! -f "$VARS_FILE" ]]; then
    echo -e "${YELLOW}⚠️  Variables file '$VARS_FILE' not found.${NC}"
    echo -e "${YELLOW}📋 Creating from example template...${NC}"
    
    if [[ -f "variables.pkrvars.hcl.example" ]]; then
        cp "variables.pkrvars.hcl.example" "$VARS_FILE"
        echo -e "${GREEN}✅ Created '$VARS_FILE' from example. Please edit it with your values.${NC}"
        echo -e "${YELLOW}⏸️  Pausing build. Please configure your variables first.${NC}"
        echo ""
        echo "Edit the file with your cloud provider credentials:"
        echo "  nano $VARS_FILE"
        echo "  # or"
        echo "  vim $VARS_FILE"
        exit 0
    else
        echo -e "${RED}❌ Example variables file not found.${NC}"
        exit 1
    fi
fi

# Initialize Packer
echo -e "${BLUE}🔧 Initializing Packer...${NC}"
if packer init main.pkr.hcl; then
    echo -e "${GREEN}✅ Packer initialized successfully${NC}"
else
    echo -e "${RED}❌ Failed to initialize Packer${NC}"
    exit 1
fi

# Validate template
echo -e "${BLUE}🔍 Validating Packer template...${NC}"
VALIDATE_CMD="packer validate"
if [[ -f "$VARS_FILE" ]]; then
    VALIDATE_CMD="$VALIDATE_CMD -var-file=\"$VARS_FILE\""
fi
VALIDATE_CMD="$VALIDATE_CMD main.pkr.hcl"

if eval $VALIDATE_CMD; then
    echo -e "${GREEN}✅ Template validation successful${NC}"
else
    echo -e "${RED}❌ Template validation failed${NC}"
    exit 1
fi

if [[ "$VALIDATE_ONLY" == true ]]; then
    echo -e "${GREEN}✅ Validation complete. Exiting as requested.${NC}"
    exit 0
fi

# Set debug environment if requested
if [[ "$DEBUG" == true ]]; then
    export PACKER_LOG=1
    echo -e "${YELLOW}🐛 Debug mode enabled${NC}"
fi

# Build images
echo -e "${BLUE}🏗️  Starting image build for platform(s): $PLATFORM${NC}"

BUILD_CMD="packer build"

if [[ -f "$VARS_FILE" ]]; then
    BUILD_CMD="$BUILD_CMD -var-file=\"$VARS_FILE\""
fi

case $PLATFORM in
    "aws")
        BUILD_CMD="$BUILD_CMD -only=\"amazon-ebs.aws\""
        echo -e "${YELLOW}☁️  Building AWS AMI only...${NC}"
        ;;
    "gcp")
        BUILD_CMD="$BUILD_CMD -only=\"googlecompute.gcp\""
        echo -e "${YELLOW}☁️  Building GCP image only...${NC}"
        ;;
    "azure")
        BUILD_CMD="$BUILD_CMD -only=\"azure-arm.azure\""
        echo -e "${YELLOW}☁️  Building Azure image only...${NC}"
        ;;
    "all")
        echo -e "${YELLOW}☁️  Building images for all platforms...${NC}"
        ;;
esac

BUILD_CMD="$BUILD_CMD main.pkr.hcl"

echo -e "${CYAN}🔨 Executing: $BUILD_CMD${NC}"
echo ""

if eval $BUILD_CMD; then
    echo ""
    echo -e "${GREEN}🎉 Build completed successfully!${NC}"
    echo -e "${GREEN}📋 Check your cloud consoles for the new images.${NC}"
    echo ""
    echo "Image locations:"
    echo "  AWS: Check EC2 Console -> AMIs"
    echo "  GCP: Check Compute Engine -> Images"
    echo "  Azure: Check your resource group for managed images"
else
    echo ""
    echo -e "${RED}❌ Build failed. Check the output above for details.${NC}"
    exit 1
fi
