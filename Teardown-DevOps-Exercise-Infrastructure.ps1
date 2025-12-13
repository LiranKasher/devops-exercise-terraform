# Define log file path with timestamp and start logging
$LogFile = Join-Path $PSScriptRoot ("logs\Teardown-DevOps-Exercise_" + (Get-Date -Format 'dd-MM-yyyy_HH-mm-ss') + ".log")

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


# --- Step 1: Change to terraform directory --- #
Write-Log "=== Step 1: Navigating to Terraform directory ===" -Color Cyan
Set-Location $TerraformDir
Write-Log "Working directory: $(Get-Location)" -Color Green


# --- Step 2: Destroy Terraform infrastructure --- #
Write-Log "=== Step 2: Destroying Terraform infrastructure ===" -Color Cyan
Write-Log "This will remove all AWS resources created by Terraform..." -Color Yellow

terraform destroy `
    -var="account_id=$AccountId" `
    -var="region=$Region" `
    -var="github_org=$GitHubOrg" `
    -var="github_repo=$GitHubRepo" `
    -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Terraform destroy failed!" -Color Red
    Set-Location $PSScriptRoot
    Stop-Transcript
    exit 1
}
Write-Log "Terraform infrastructure destroyed successfully." -Color Green


# --- Step 3: Clean up Terraform state (optional) --- #
Write-Log "=== Step 3: Cleaning up Terraform files (optional) ===" -Color Cyan
Write-Log "Uncomment the following lines in the script for a completely clean slate:" -Color Yellow
Write-Log "  Remove-Item .terraform.lock.hcl" -Color White
Write-Log "  Remove-Item -Recurse -Force .terraform" -Color White
Write-Log "  Remove-Item terraform.tfstate -ErrorAction SilentlyContinue" -Color White
Write-Log "  Remove-Item terraform.tfstate.backup -ErrorAction SilentlyContinue" -Color White

# Uncomment the following lines for clean slate on the next setup
# Remove-Item .terraform.lock.hcl -ErrorAction SilentlyContinue
# Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue
# Remove-Item terraform.tfstate -ErrorAction SilentlyContinue
# Remove-Item terraform.tfstate.backup -ErrorAction SilentlyContinue
# if ($?) {
#     Write-Log "Terraform state files cleaned up." -Color Green
# }


# --- Step 4: Reset CI/CD workflows --- #
Write-Log "=== Step 4: Resetting GitHub Actions workflows ===" -Color Cyan

# Return to script root
Set-Location $PSScriptRoot

# Reset CI workflow
if (Test-Path $CiWorkflowFile) {
    try {
        $CiWorkflow = Get-Content $CiWorkflowFile -Raw
        $CiWorkflow = $CiWorkflow `
            -replace $Region, "<region>" `
            -replace "role-to-assume:.*", "role-to-assume: arn:aws:iam::<account-id>:role/<role-name>"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($CiWorkflowFile, $CiWorkflow, $utf8NoBom)
        Write-Log "CI workflow reset: $CiWorkflowFile" -Color Green
    } catch {
        Write-Log "WARNING: Could not reset CI workflow: $_" -Color Yellow
    }
} else {
    Write-Log "WARNING: CI workflow file not found: $CiWorkflowFile" -Color Yellow
}

# Reset CD workflow
if (Test-Path $CdWorkflowFile) {
    try {
        $CdWorkflow = Get-Content $CdWorkflowFile -Raw
        $CdWorkflow = $CdWorkflow `
            -replace $Region, "<region>" `
            -replace "role-to-assume:.*", "role-to-assume: arn:aws:iam::<account-id>:role/<role-name>"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($CdWorkflowFile, $CdWorkflow, $utf8NoBom)
        Write-Log "CD workflow reset: $CdWorkflowFile" -Color Green
    } catch {
        Write-Log "WARNING: Could not reset CD workflow: $_" -Color Yellow
    }
} else {
    Write-Log "WARNING: CD workflow file not found: $CdWorkflowFile" -Color Yellow
}

# Return to Terraform root
Set-Location $PSScriptRoot


# --- Summary --- #
Write-Log "====================================" -Color Cyan
Write-Log "✅ Infrastructure teardown complete!" -Color Green
Write-Log "====================================" -Color Cyan
Write-Log "What was cleaned up:" -Color Cyan
Write-Log "  • EKS Cluster and all associated resources" -Color White
Write-Log "  • ECR Repository" -Color White
Write-Log "  • IAM Roles and Policies" -Color White
Write-Log "  • VPC, Subnets, and Networking components" -Color White
Write-Log "  • GitHub Actions workflow configurations reset" -Color White
Write-Log "What was preserved:" -Color Cyan
Write-Log "  • Terraform state file (terraform.tfstate)" -Color White
Write-Log "  • Terraform lock file (.terraform.lock.hcl)" -Color White
Write-Log "  • Terraform plugins (.terraform directory)" -Color White
Write-Log "Next steps:" -Color Cyan
Write-Log "1. Commit workflow changes if you want to preserve the reset state" -Color White
Write-Log "2. Run Setup-DevOps-Exercise-Infrastructure.ps1 to recreate infrastructure" -Color White
Write-Log "Log file saved to: $LogFile" -Color Green

Stop-Transcript