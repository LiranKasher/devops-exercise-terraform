# Define log file path with timestamp and start logging
#$LogFile = Join-Path $PSScriptRoot ("logs\Setup-DevOps-Exercise-Infrastructure_" + (Get-Date -Format 'dd-MM-yyyy_HH-mm-ss') + ".log")

# Ensure logs directory exists
$LogDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Start-Transcript -Path $LogFile -Append

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Alias("ForegroundColor")]
        [string]$Color = "White"
    )

    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    Write-Host "$timestamp $Message" -ForegroundColor $Color
}


# --- Ensure required tools --- #
function Ensure-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName,
        [Parameter(Mandatory = $true)]
        [scriptblock]$InstallAction
    )

    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Log "$ToolName already installed. Skipping installation..." -Color Yellow
    } else {
        Write-Log "$ToolName not found. Installing..." -Color Green
        & $InstallAction

        # Post-install verification
        $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Log "$ToolName installation verified." -Color Green
        } else {
            Write-Log "$ToolName installation failed or not found on PATH." -Color Red
            Write-Log "Please restart your terminal and run this script again." -Color Yellow
        }
    }
}

function Install-AwsCli {
    Write-Log "Installing AWS CLI v2..." -Color Green
    $installer = "$env:TEMP\AWSCLIV2.msi"
    Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installer
    Start-Process msiexec.exe -Wait -ArgumentList "/i $installer /qn"
    $awsExe = (Get-Command aws.exe -ErrorAction SilentlyContinue).Source
    if ($awsExe -and (Test-Path $awsExe)) {
        Write-Log "AWS CLI installed successfully." -Color Green
    } else {
        Write-Log "AWS CLI installation failed. aws.exe not found." -Color Red
    }
}

function Install-Eksctl {
    Write-Log "Installing eksctl..." -Color Green
    $zipPath = "$env:TEMP\eksctl.zip"
    $extractPath = "$env:TEMP\eksctl"
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Windows_amd64.zip" -OutFile $zipPath
    Expand-Archive $zipPath -DestinationPath $extractPath -Force
    $exe = Join-Path $extractPath "eksctl.exe"
    if (Test-Path $exe) {
        $targetPath = "C:\Program Files\eksctl"
        New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
        Move-Item $exe "$targetPath\eksctl.exe" -Force
        $env:Path += ";$targetPath"
        Write-Log "eksctl installed successfully." -Color Green
    } else {
        Write-Log "eksctl.exe not found after extraction. Check archive contents." -Color Red
    }
}

function Install-Kubectl {
    Write-Log "Installing kubectl..." -Color Green
    $kubectlPath = "C:\Program Files\kubectl"
    New-Item -ItemType Directory -Force -Path $kubectlPath | Out-Null
    Invoke-WebRequest "https://dl.k8s.io/release/v1.30.0/bin/windows/amd64/kubectl.exe" -OutFile "$kubectlPath\kubectl.exe"
    if (Test-Path "$kubectlPath\kubectl.exe") {
        $env:Path += ";$kubectlPath"
        Write-Log "kubectl installed successfully." -Color Green
    } else {
        Write-Log "kubectl.exe not found after download. Check URL." -Color Red
    }
}

function Install-Helm {
    Write-Log "Installing Helm..." -Color Green
    $zipPath = "$env:TEMP\helm.zip"
    $extractPath = "$env:TEMP\helm"
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest "https://get.helm.sh/helm-v3.15.2-windows-amd64.zip" -OutFile $zipPath
    Expand-Archive $zipPath -DestinationPath $extractPath -Force
    $exe = Join-Path $extractPath "windows-amd64\helm.exe"
    if (Test-Path $exe) {
        $targetPath = "C:\Program Files\helm"
        New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
        Move-Item $exe "$targetPath\helm.exe" -Force
        $env:Path += ";$targetPath"
        Write-Log "Helm installed successfully." -Color Green
    } else {
        Write-Log "helm.exe not found after extraction. Check archive contents." -Color Red
    }
}

function Install-Terraform {
    Write-Log "Installing Terraform..." -Color Green
    $zipPath = "$env:TEMP\terraform.zip"
    $extractPath = "$env:TEMP\terraform"
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    $latest = Invoke-RestMethod "https://checkpoint-api.hashicorp.com/v1/check/terraform"
    $version = $latest.current_version
    $url = "https://releases.hashicorp.com/terraform/$version/terraform_${version}_windows_amd64.zip"
    Invoke-WebRequest $url -OutFile $zipPath
    Expand-Archive $zipPath -DestinationPath $extractPath -Force
    $exe = Join-Path $extractPath "terraform.exe"
    if (Test-Path $exe) {
        $targetPath = "C:\Program Files\terraform"
        New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
        Move-Item $exe "$targetPath\terraform.exe" -Force
        $env:Path += ";$targetPath"
        Write-Log "Terraform installed successfully." -Color Green
    } else {
        Write-Log "terraform.exe not found after extraction. Check archive contents." -Color Red
    }
}

Write-Log "=== Ensuring required tools are installed ===" -Color Cyan
Ensure-Tool "aws"       { Install-AwsCli }
Ensure-Tool "eksctl"    { Install-Eksctl }
Ensure-Tool "kubectl"   { Install-Kubectl }
Ensure-Tool "helm"      { Install-Helm }
Ensure-Tool "terraform" { Install-Terraform }


# --- Variables --- #
$DefaultRegion = "il-central-1"
$RoleName = "GitHubOIDCDeployRole"
$CiWorkflowFile = Join-Path $PSScriptRoot ".github\workflows\ci.yaml"
$CdWorkflowFile = Join-Path $PSScriptRoot ".github\workflows\cd.yaml"
$TerraformDir = Join-Path $PSScriptRoot "terraform"

# Verify Terraform directory exists
if (-not (Test-Path $TerraformDir)) {
    Write-Log "ERROR: Terraform directory not found at $TerraformDir" -Color Red
    Stop-Transcript
    exit 1
}


# --- Dynamic variables --- #

Write-Log "=== Gathering AWS and Git information ===" -Color Cyan

# Get AWS Account ID
try {
    $AccountId = (aws sts get-caller-identity --query "Account" --output text 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Write-Log "ERROR: Failed to get AWS Account ID. Make sure AWS CLI is configured." -Color Red
        Write-Log "Run: aws configure" -Color Yellow
        Stop-Transcript
        exit 1
    }
    Write-Log "AWS Account ID: $AccountId" -Color Green
} catch {
    Write-Log "ERROR: Failed to retrieve AWS Account ID: $_" -Color Red
    Stop-Transcript
    exit 1
}

# Get AWS Region
$Region = (aws configure get region)
if (-not $Region -or $Region -eq "") {
    Write-Log "No default region set in AWS CLI. Using default: $DefaultRegion" -Color Yellow
    $Region = $DefaultRegion
}
Write-Log "AWS Region: $Region" -Color Green

# Get the remote origin URL
try {
    $RemoteUrl = git config --get remote.origin.url
    if (-not $RemoteUrl) {
        Write-Log "ERROR: No git remote origin found. Make sure you're in a git repository." -Color Red
        Stop-Transcript
        exit 1
    }
    Write-Log "Git Remote URL: $RemoteUrl" -Color Green
} catch {
    Write-Log "ERROR: Failed to get git remote origin: $_" -Color Red
    Stop-Transcript
    exit 1
}

# Extract org/user and repo name
if ($RemoteUrl -match "github.com[:/](.+?)/(.+?)(\.git)?$") {
    $GitHubOrg = $matches[1]
    $GitHubRepo = $matches[2]
    Write-Log "GitHub Org: $GitHubOrg" -Color Green
    Write-Log "GitHub Repo: $GitHubRepo" -Color Green
} else {
    Write-Log "ERROR: Could not parse GitHub org/repo from remote URL: $RemoteUrl" -Color Red
    Stop-Transcript
    exit 1
}


# --- Step 1: Add required Helm charts and update cache --- #
Write-Log "=== Step 1: Adding Helm repositories ===" -Color Cyan
try {
    helm repo add eks https://aws.github.io/eks-charts 2>&1 | Out-Null
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>&1 | Out-Null
    helm repo add fluent https://fluent.github.io/helm-charts 2>&1 | Out-Null
    helm repo update 2>&1 | Out-Null
    Write-Log "Helm repositories added and updated successfully." -Color Green
} catch {
    Write-Log "WARNING: Some Helm repos may already exist. Continuing..." -Color Yellow
}


# --- Step 2: Change to terraform directory --- #
Write-Log "=== Step 2: Navigating to Terraform directory ===" -Color Cyan
Set-Location $TerraformDir
Write-Log "Working directory: $(Get-Location)" -Color Green


# --- Step 3: Initialize Terraform --- #
Write-Log "=== Step 3: Initializing Terraform ===" -Color Cyan
terraform init -upgrade
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Terraform init failed!" -Color Red
    Set-Location $PSScriptRoot
    Stop-Transcript
    exit 1
}
Write-Log "Terraform initialized successfully." -Color Green


# --- Step 4: Apply changes (automated, no plan preview) --- #
Write-Log "=== Step 4: Applying Terraform changes ===" -Color Cyan
Write-Log "This will take approximately 15-20 minutes..." -Color Yellow

terraform apply `
    -var="account_id=$AccountId" `
    -var="region=$Region" `
    -var="github_org=$GitHubOrg" `
    -var="github_repo=$GitHubRepo" `
    -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Terraform apply failed!" -Color Red
    Set-Location $PSScriptRoot
    Stop-Transcript
    exit 1
}
Write-Log "Terraform applied successfully." -Color Green


# --- Step 5: Get outputs from Terraform --- #
Write-Log "=== Step 5: Retrieving Terraform outputs ===" -Color Cyan

try {
    $ClusterName = (terraform output -raw cluster_name 2>&1)
    $RoleArn = (terraform output -raw github_deploy_role_arn 2>&1)
    $EcrRepoUrl = (terraform output -raw ecr_repository_url 2>&1)
    
    Write-Log "Cluster Name: $ClusterName" -Color Green
    Write-Log "GitHub Deploy Role ARN: $RoleArn" -Color Green
    Write-Log "ECR Repository URL: $EcrRepoUrl" -Color Green
} catch {
    Write-Log "WARNING: Could not retrieve all Terraform outputs. Attempting to get Role ARN manually..." -Color Yellow
    $RoleArn = (aws iam get-role --role-name $RoleName --query 'Role.Arn' --output text 2>&1)
}


# --- Step 6: Configure kubectl --- #
Write-Log "=== Step 6: Configuring kubectl ===" -Color Cyan
try {
    aws eks update-kubeconfig --region $Region --name $ClusterName 2>&1 | Out-Null
    Write-Log "kubectl configured successfully." -Color Green
    
    # Verify connection
    Write-Log "Verifying cluster connection..." -Color Cyan
    kubectl get nodes
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Successfully connected to EKS cluster!" -Color Green
    }
} catch {
    Write-Log "WARNING: Could not configure kubectl. You may need to run this manually:" -Color Yellow
    Write-Log "  aws eks update-kubeconfig --region $Region --name $ClusterName" -Color Yellow
}


# --- Step 7: Update CI/CD workflows with role ARN and region --- #
Write-Log "=== Step 7: Updating GitHub Actions workflows ===" -Color Cyan

# Return to script root
Set-Location $PSScriptRoot

if (Test-Path $CiWorkflowFile) {
    try {
        $CiWorkflow = Get-Content $CiWorkflowFile -Raw
        $CiWorkflow = $CiWorkflow `
            -replace "<region>", $Region `
            -replace "role-to-assume:.*", "role-to-assume: $RoleArn"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($CiWorkflowFile, $CiWorkflow, $utf8NoBom)
        Write-Log "CI workflow updated: $CiWorkflowFile" -Color Green
    } catch {
        Write-Log "WARNING: Could not update CI workflow: $_" -Color Yellow
    }
} else {
    Write-Log "WARNING: CI workflow file not found: $CiWorkflowFile" -Color Yellow
}

if (Test-Path $CdWorkflowFile) {
    try {
        $CdWorkflow = Get-Content $CdWorkflowFile -Raw
        $CdWorkflow = $CdWorkflow `
            -replace "<region>", $Region `
            -replace "role-to-assume:.*", "role-to-assume: $RoleArn"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($CdWorkflowFile, $CdWorkflow, $utf8NoBom)
        Write-Log "CD workflow updated: $CdWorkflowFile" -Color Green
    } catch {
        Write-Log "WARNING: Could not update CD workflow: $_" -Color Yellow
    }
} else {
    Write-Log "WARNING: CD workflow file not found: $CdWorkflowFile" -Color Yellow
}

Set-Location $TerraformDir


# --- Summary --- #
Write-Log "====================================" -Color Cyan
Write-Log "✅ Infrastructure setup complete!" -Color Green
Write-Log "====================================" -Color Cyan
Write-Log "Next steps:" -Color Cyan
Write-Log "1. Commit and push workflow changes to trigger CI/CD" -Color White
Write-Log "2. Or use GitHub Actions page to manually trigger workflows" -Color White
Write-Log "3. Access Grafana: kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80" -Color White
Write-Log "   Default credentials: admin / prom-operator" -Color White
Write-Log "Useful commands:" -Color Cyan
Write-Log "  kubectl get pods -A                    # View all pods" -Color White
Write-Log "  kubectl get svc -A                     # View all services" -Color White
Write-Log "  kubectl logs -n kube-system <pod>      # View pod logs" -Color White
Write-Log "Log file saved to: $LogFile" -Color Green

Stop-Transcript