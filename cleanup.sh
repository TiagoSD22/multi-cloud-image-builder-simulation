#!/bin/bash

# Packer Resource Cleanup Script
# This script helps remove all images/AMIs created by Packer builds

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
FORCE=false
IMAGE_PREFIX="poc-nginx-image"
CONFIRM=true

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --prefix PREFIX         Image name prefix to search for [default: poc-nginx-image]"
    echo "  -d, --dry-run              Show what would be deleted without actually deleting"
    echo "  -f, --force                Skip confirmation prompts"
    echo "  -y, --yes                  Answer yes to all prompts"
    echo "  -h, --help                 Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                         # Interactive cleanup of poc-nginx-image* resources"
    echo "  $0 -d                      # Dry run to see what would be deleted"
    echo "  $0 -p my-image -f          # Force cleanup of my-image* resources"
    echo "  $0 -y                      # Cleanup with auto-confirm"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prefix)
            IMAGE_PREFIX="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            CONFIRM=false
            shift
            ;;
        -y|--yes)
            CONFIRM=false
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

echo -e "${CYAN}🧹 Packer Resource Cleanup Tool${NC}"
echo -e "${CYAN}===============================${NC}"
echo -e "Image prefix: ${YELLOW}$IMAGE_PREFIX${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "Mode: ${YELLOW}DRY RUN (no resources will be deleted)${NC}"
fi
echo ""

# Function to confirm action
confirm_action() {
    local message="$1"
    if [[ "$CONFIRM" == true ]] && [[ "$DRY_RUN" == false ]]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 1
        fi
    fi
    return 0
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# AWS Cleanup
cleanup_aws() {
    echo -e "${BLUE}🔧 Cleaning up AWS resources...${NC}"
    
    if ! command_exists aws; then
        echo -e "${YELLOW}⚠️  AWS CLI not found - skipping AWS cleanup${NC}"
        return
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  AWS credentials not configured - skipping AWS cleanup${NC}"
        return
    fi

    # 1. Clean up running EC2 instances created by Packer
    echo -e "${BLUE}🔍 Checking for Packer EC2 instances...${NC}"
    local packer_instances
    packer_instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=Packer Builder" \
                  "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,LaunchTime:LaunchTime,Name:Tags[?Key=='Name']|[0].Value}" \
        --output table 2>/dev/null || echo "")
    
    if [[ -n "$packer_instances" ]] && [[ "$packer_instances" != *"None"* ]]; then
        echo -e "${YELLOW}Found Packer EC2 instances:${NC}"
        echo "$packer_instances"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}🔍 DRY RUN: Would terminate the Packer instances listed above${NC}"
        else
            if confirm_action "This will terminate all running Packer EC2 instances"; then
                local instance_ids
                instance_ids=$(aws ec2 describe-instances \
                    --filters "Name=tag:Name,Values=Packer Builder" \
                              "Name=instance-state-name,Values=running,pending,stopping,stopped" \
                    --query "Reservations[].Instances[].InstanceId" \
                    --output text)
                
                for instance_id in $instance_ids; do
                    echo -e "${BLUE}🗑️  Terminating Packer instance: $instance_id${NC}"
                    if aws ec2 terminate-instances --instance-ids "$instance_id" >/dev/null; then
                        echo -e "${GREEN}✅ Instance $instance_id terminated${NC}"
                    else
                        echo -e "${RED}❌ Failed to terminate instance $instance_id${NC}"
                    fi
                done
            fi
        fi
    else
        echo -e "${GREEN}✅ No Packer EC2 instances found${NC}"
    fi

    # 2. Clean up orphaned instances that might have been created by failed builds
    echo -e "${BLUE}🔍 Checking for orphaned instances with image prefix...${NC}"
    local orphaned_instances
    orphaned_instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*$IMAGE_PREFIX*" \
                  "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,LaunchTime:LaunchTime,Name:Tags[?Key=='Name']|[0].Value}" \
        --output table 2>/dev/null || echo "")
    
    if [[ -n "$orphaned_instances" ]] && [[ "$orphaned_instances" != *"None"* ]]; then
        echo -e "${YELLOW}Found potentially orphaned instances:${NC}"
        echo "$orphaned_instances"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}🔍 DRY RUN: Would terminate the orphaned instances listed above${NC}"
        else
            if confirm_action "This will terminate instances that may be orphaned from failed Packer builds"; then
                local orphaned_ids
                orphaned_ids=$(aws ec2 describe-instances \
                    --filters "Name=tag:Name,Values=*$IMAGE_PREFIX*" \
                              "Name=instance-state-name,Values=running,pending,stopping,stopped" \
                    --query "Reservations[].Instances[].InstanceId" \
                    --output text)
                
                for instance_id in $orphaned_ids; do
                    echo -e "${BLUE}🗑️  Terminating orphaned instance: $instance_id${NC}"
                    if aws ec2 terminate-instances --instance-ids "$instance_id" >/dev/null; then
                        echo -e "${GREEN}✅ Instance $instance_id terminated${NC}"
                    else
                        echo -e "${RED}❌ Failed to terminate instance $instance_id${NC}"
                    fi
                done
            fi
        fi
    else
        echo -e "${GREEN}✅ No orphaned instances found${NC}"
    fi

    # 3. Clean up Packer security groups
    echo -e "${BLUE}🔍 Checking for Packer security groups...${NC}"
    local packer_sgs
    packer_sgs=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=packer_*" \
        --query "SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Description:Description}" \
        --output table 2>/dev/null || echo "")
    
    if [[ -n "$packer_sgs" ]] && [[ "$packer_sgs" != *"None"* ]]; then
        echo -e "${YELLOW}Found Packer security groups:${NC}"
        echo "$packer_sgs"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}🔍 DRY RUN: Would delete the Packer security groups listed above${NC}"
        else
            if confirm_action "This will delete Packer-created security groups"; then
                local sg_ids
                sg_ids=$(aws ec2 describe-security-groups \
                    --filters "Name=group-name,Values=packer_*" \
                    --query "SecurityGroups[].GroupId" \
                    --output text)
                
                for sg_id in $sg_ids; do
                    echo -e "${BLUE}🗑️  Deleting security group: $sg_id${NC}"
                    if aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null; then
                        echo -e "${GREEN}✅ Security group $sg_id deleted${NC}"
                    else
                        echo -e "${YELLOW}⚠️  Could not delete security group $sg_id (may be in use)${NC}"
                    fi
                done
            fi
        fi
    else
        echo -e "${GREEN}✅ No Packer security groups found${NC}"
    fi

    # 4. Clean up Packer key pairs
    echo -e "${BLUE}🔍 Checking for Packer key pairs...${NC}"
    local packer_keys
    packer_keys=$(aws ec2 describe-key-pairs \
        --filters "Name=key-name,Values=packer_*" \
        --query "KeyPairs[].{KeyName:KeyName,KeyFingerprint:KeyFingerprint}" \
        --output table 2>/dev/null || echo "")
    
    if [[ -n "$packer_keys" ]] && [[ "$packer_keys" != *"None"* ]]; then
        echo -e "${YELLOW}Found Packer key pairs:${NC}"
        echo "$packer_keys"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}🔍 DRY RUN: Would delete the Packer key pairs listed above${NC}"
        else
            if confirm_action "This will delete Packer-created key pairs"; then
                local key_names
                key_names=$(aws ec2 describe-key-pairs \
                    --filters "Name=key-name,Values=packer_*" \
                    --query "KeyPairs[].KeyName" \
                    --output text)
                
                for key_name in $key_names; do
                    echo -e "${BLUE}🗑️  Deleting key pair: $key_name${NC}"
                    if aws ec2 delete-key-pair --key-name "$key_name"; then
                        echo -e "${GREEN}✅ Key pair $key_name deleted${NC}"
                    else
                        echo -e "${RED}❌ Failed to delete key pair $key_name${NC}"
                    fi
                done
            fi
        fi
    else
        echo -e "${GREEN}✅ No Packer key pairs found${NC}"
    fi

    # 5. Find AMIs with the specified prefix
    echo -e "${BLUE}🔍 Checking for AMIs with prefix '$IMAGE_PREFIX'...${NC}"
    local amis
    amis=$(aws ec2 describe-images --owners self --query "Images[?starts_with(Name, \`$IMAGE_PREFIX\`)].{ImageId:ImageId,Name:Name,CreationDate:CreationDate}" --output table 2>/dev/null || echo "")
    
    if [[ -z "$amis" ]] || [[ "$amis" == *"None"* ]]; then
        echo -e "${GREEN}✅ No AWS AMIs found with prefix '$IMAGE_PREFIX'${NC}"
    else
        echo -e "${YELLOW}Found AWS AMIs:${NC}"
        echo "$amis"
        
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}🔍 DRY RUN: Would delete the AMIs listed above${NC}"
        else
            if confirm_action "This will delete all AWS AMIs with prefix '$IMAGE_PREFIX'"; then
                # Get AMI IDs
                local ami_ids
                ami_ids=$(aws ec2 describe-images --owners self --query "Images[?starts_with(Name, \`$IMAGE_PREFIX\`)].ImageId" --output text)
                
                for ami_id in $ami_ids; do
                    echo -e "${BLUE}🗑️  Deleting AMI: $ami_id${NC}"
                    
                    # Get associated snapshots before deleting AMI
                    local snapshots
                    snapshots=$(aws ec2 describe-images --image-ids "$ami_id" --query "Images[0].BlockDeviceMappings[?Ebs.SnapshotId != null].Ebs.SnapshotId" --output text)
                    
                    # Deregister AMI
                    if aws ec2 deregister-image --image-id "$ami_id"; then
                        echo -e "${GREEN}✅ AMI $ami_id deregistered${NC}"
                        
                        # Delete associated snapshots
                        for snapshot_id in $snapshots; do
                            if [[ "$snapshot_id" != "None" ]] && [[ -n "$snapshot_id" ]]; then
                                echo -e "${BLUE}🗑️  Deleting snapshot: $snapshot_id${NC}"
                                if aws ec2 delete-snapshot --snapshot-id "$snapshot_id" 2>/dev/null; then
                                    echo -e "${GREEN}✅ Snapshot $snapshot_id deleted${NC}"
                                else
                                    echo -e "${YELLOW}⚠️  Could not delete snapshot $snapshot_id (may be in use)${NC}"
                                fi
                            fi
                        done
                    else
                        echo -e "${RED}❌ Failed to deregister AMI $ami_id${NC}"
                    fi
                done
            fi
        fi
    fi
}

# GCP Cleanup
cleanup_gcp() {
    echo -e "${BLUE}🔧 Cleaning up GCP Images...${NC}"
    
    if ! command_exists gcloud; then
        echo -e "${YELLOW}⚠️  gcloud CLI not found - skipping GCP cleanup${NC}"
        return
    fi

    # Check GCP authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  GCP not authenticated - skipping GCP cleanup${NC}"
        return
    fi

    # Get current project
    local project_id
    project_id=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$project_id" ]]; then
        echo -e "${YELLOW}⚠️  No GCP project set - skipping GCP cleanup${NC}"
        return
    fi

    echo -e "Current GCP project: ${YELLOW}$project_id${NC}"

    # Find images with the specified prefix
    local images
    images=$(gcloud compute images list --filter="name~^$IMAGE_PREFIX.*" --format="table(name,family,creationTimestamp)" 2>/dev/null || echo "")
    
    if [[ -z "$images" ]] || [[ "$images" == *"Listed 0 items"* ]]; then
        echo -e "${GREEN}✅ No GCP images found with prefix '$IMAGE_PREFIX'${NC}"
        return
    fi

    echo -e "${YELLOW}Found GCP Images:${NC}"
    echo "$images"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}🔍 DRY RUN: Would delete the GCP images listed above${NC}"
        return
    fi

    if confirm_action "This will delete all GCP images with prefix '$IMAGE_PREFIX' in project '$project_id'"; then
        # Get image names
        local image_names
        image_names=$(gcloud compute images list --filter="name~^$IMAGE_PREFIX.*" --format="value(name)")
        
        for image_name in $image_names; do
            echo -e "${BLUE}🗑️  Deleting GCP image: $image_name${NC}"
            if gcloud compute images delete "$image_name" --quiet; then
                echo -e "${GREEN}✅ Image $image_name deleted${NC}"
            else
                echo -e "${RED}❌ Failed to delete image $image_name${NC}"
            fi
        done
    fi
}

# Azure Cleanup
cleanup_azure() {
    echo -e "${BLUE}🔧 Cleaning up Azure Managed Images...${NC}"
    
    if ! command_exists az; then
        echo -e "${YELLOW}⚠️  Azure CLI not found - skipping Azure cleanup${NC}"
        return
    fi

    # Check Azure authentication
    if ! az account show >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Azure not authenticated - skipping Azure cleanup${NC}"
        return
    fi

    # Get current subscription
    local subscription_name
    subscription_name=$(az account show --query name --output tsv)
    echo -e "Current Azure subscription: ${YELLOW}$subscription_name${NC}"

    # Find managed images with the specified prefix
    local images
    images=$(az image list --query "[?starts_with(name, '$IMAGE_PREFIX')].{Name:name,ResourceGroup:resourceGroup,Location:location}" --output table 2>/dev/null || echo "")
    
    if [[ -z "$images" ]] || [[ "$images" == *"[]"* ]]; then
        echo -e "${GREEN}✅ No Azure managed images found with prefix '$IMAGE_PREFIX'${NC}"
        return
    fi

    echo -e "${YELLOW}Found Azure Managed Images:${NC}"
    echo "$images"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BLUE}🔍 DRY RUN: Would delete the Azure images listed above${NC}"
        return
    fi

    if confirm_action "This will delete all Azure managed images with prefix '$IMAGE_PREFIX'"; then
        # Get image details
        local image_data
        image_data=$(az image list --query "[?starts_with(name, '$IMAGE_PREFIX')].{name:name,resourceGroup:resourceGroup}" --output tsv)
        
        while IFS=$'\t' read -r image_name resource_group; do
            if [[ -n "$image_name" ]]; then
                echo -e "${BLUE}🗑️  Deleting Azure image: $image_name (RG: $resource_group)${NC}"
                if az image delete --name "$image_name" --resource-group "$resource_group"; then
                    echo -e "${GREEN}✅ Image $image_name deleted${NC}"
                else
                    echo -e "${RED}❌ Failed to delete image $image_name${NC}"
                fi
            fi
        done <<< "$image_data"
    fi
}

# Main cleanup execution
main() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}🔍 DRY RUN MODE - No resources will be deleted${NC}"
        echo ""
    fi

    cleanup_aws
    echo ""
    cleanup_gcp
    echo ""
    cleanup_azure
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${CYAN}🔍 Dry run completed. Run without -d/--dry-run to actually delete resources.${NC}"
    else
        echo -e "${GREEN}🎉 Cleanup completed!${NC}"
    fi
}

# Run main function
main
