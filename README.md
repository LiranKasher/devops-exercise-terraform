# DevOps Exercise: Flask on EKS via Terraform with CI/CD and Monitoring

A complete DevOps project featuring a simple interactive Flask application deployed to AWS EKS (Elastic Kubernetes Service) with full CI/CD automation via GitHub Actions, comprehensive monitoring with Prometheus/Grafana, and centralized logging through CloudWatch via Fluent Bit.

## 🏗️ Architecture Overview

This project demonstrates a production-ready deployment pipeline:

- **Application**: Flask web app with health checks and custom metrics endpoint
- **Container**: Docker image built and stored in AWS ECR
- **Orchestration**: Kubernetes deployment on AWS EKS with 2-4 nodes (t3.small)
- **CI/CD**: GitHub Actions workflows with AWS OIDC authentication
- **Ingress**: AWS Application Load Balancer (ALB) for external access
- **Monitoring**: Prometheus + Grafana for metrics visualization
- **Logging**: Fluent Bit shipping logs to CloudWatch Logs

## 📋 Prerequisites

### Required Tools
All tools are automatically installed by the setup script:
- AWS CLI v2
- eksctl
- kubectl
- Helm
- Terraform

### Required Access
- **AWS Account** with permissions to create:
  - EKS clusters
  - ECR repositories
  - IAM roles and policies
  - VPC and networking resources
  - Application Load Balancers
  - CloudWatch log groups
- **GitHub Repository** with Actions enabled
- **Windows PowerShell** with administrator privileges

## 🚀 Quick Start

### 1. Initial Setup

Run the automated setup script as administrator:

```powershell
# Open PowerShell as Administrator
.\Setup-DevOps-Exercise-Infrastructure.ps1
```

**What the setup script does:**
- ✅ Installs required tools (AWS CLI, eksctl, kubectl, Helm, Terraform)
- ✅ Gathers AWS account and GitHub repository information
- ✅ Creates EKS cluster with all required add-ons
- ✅ Provisions ECR repository for Docker images
- ✅ Sets up IAM roles for GitHub OIDC authentication
- ✅ Installs AWS Load Balancer Controller
- ✅ Deploys Prometheus/Grafana monitoring stack
- ✅ Configures Fluent Bit for CloudWatch logging
- ✅ Updates GitHub Actions workflow files with proper credentials
- ✅ Configures kubectl for cluster access

**Estimated time:** 15-20 minutes

### 2. Deploy the Application

After setup completes, trigger deployment by either:

**Option A: Push to main branch**
```bash
git add .
git commit -m "Deploy application"
git push origin main
```

**Option B: Manual trigger via GitHub Actions**
1. Go to your repository on GitHub
2. Click **Actions** tab
3. Select **CI** workflow
4. Click **Run workflow** → **Run workflow**

### 3. Access Your Application

Once deployment completes:

```powershell
# Get the Application Load Balancer URL
kubectl get ingress -n app

# Example output:
# NAME        CLASS   HOSTS   ADDRESS                                      PORTS   AGE
# flask-app   alb     *       k8s-app-flaskapp-xxxxxxxxxxxx.us-east-1.elb.amazonaws.com   80      5m
```

Open the ADDRESS URL in your browser to access the Flask application.

## 📊 Monitoring and Observability

### Grafana Dashboard

Access Grafana for metrics visualization:

```powershell
# Port-forward Grafana service
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80

# Open browser to: http://localhost:3000
# Default credentials:
#   Username: admin
#   Password: prom-operator
```

**Available Metrics:**
- Custom application metrics at `/metrics` endpoint
  - `custom_requests_total`: Total number of requests
  - `custom_uptime_seconds`: Application uptime
- Kubernetes cluster metrics (CPU, memory, network)
- Pod and container metrics

### CloudWatch Logs

View application logs in AWS CloudWatch:

```powershell
# View logs via AWS CLI
aws logs tail /eks/devops-exercise/application --follow

# Or access via AWS Console:
# CloudWatch → Logs → Log groups → /eks/devops-exercise/application
```

### Kubernetes Commands

```powershell
# View all pods across namespaces
kubectl get pods -A

# View application pods
kubectl get pods -n app

# View application logs
kubectl logs -n app -l app=flask-app

# View service status
kubectl get svc -A

# View ingress status
kubectl get ingress -n app

# Describe deployment
kubectl describe deployment flask-app -n app
```

## 🔄 CI/CD Pipeline

### CI Workflow (`.github/workflows/ci.yaml`)

Triggers on:
- Push to `main` branch
- Pull requests
- Manual workflow dispatch

**Steps:**
1. Checkout code
2. Set up Python environment
3. Run syntax validation
4. Authenticate to AWS via OIDC
5. Build Docker image
6. Tag image with commit SHA
7. Push image to ECR

### CD Workflow (`.github/workflows/cd.yaml`)

Triggers on:
- Successful CI workflow completion
- Manual workflow dispatch

**Steps:**
1. Checkout code
2. Authenticate to AWS via OIDC
3. Update kubeconfig for EKS access
4. Patch deployment manifest with image SHA
5. Apply Kubernetes manifests:
   - Namespace
   - Deployment
   - Service
   - Ingress
   - ServiceMonitor
6. Wait for rollout to complete
7. Debug on failure (show pods, events, logs)

## 📁 Project Structure

```
devops-exercise/
├── app/
│   ├── main.py              # Flask application
│   ├── requirements.txt     # Python dependencies
│   └── templates/
│       └── index.html       # Frontend template
├── k8s/
│   ├── namespace.yaml       # Kubernetes namespace
│   ├── deployment.yaml      # Application deployment
│   ├── service.yaml         # ClusterIP service
│   ├── ingress.yaml         # ALB ingress
│   └── servicemonitor.yaml  # Prometheus monitoring
├── terraform/
│   ├── main.tf              # Main Terraform config
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   ├── eks.tf               # EKS cluster resources
│   ├── ecr.tf               # ECR repository
│   ├── iam.tf               # IAM roles and policies
│   └── monitoring.tf        # Monitoring stack
├── .github/
│   └── workflows/
│       ├── ci.yaml          # CI pipeline
│       └── cd.yaml          # CD pipeline
├── Dockerfile               # Container definition
├── Setup-DevOps-Exercise-Infrastructure.ps1
├── Teardown-DevOps-Exercise.ps1
└── README.md
```

## 🧪 Testing the Application

### Health Check
```bash
curl http://<ALB-URL>/healthz
# Expected: {"status":"ok"}
```

### Custom Metrics
```bash
curl http://<ALB-URL>/metrics
# Expected:
# custom_requests_total 42
# custom_uptime_seconds 3600
```

### Echo Endpoint
```bash
curl -X POST http://<ALB-URL>/echo -d "message=Hello"
# Expected: You said: Hello
#           Aha! I knew you were going to say that. :)
```

## 🛠️ Troubleshooting

### Check Pod Status
```powershell
kubectl get pods -n app
kubectl describe pod <pod-name> -n app
kubectl logs <pod-name> -n app
```

### Check Deployment
```powershell
kubectl get deployment flask-app -n app
kubectl describe deployment flask-app -n app
```

### Check Ingress
```powershell
kubectl get ingress -n app
kubectl describe ingress flask-app -n app
```

### Check Events
```powershell
kubectl get events -n app --sort-by='.lastTimestamp'
```

### Verify IAM Role Trust
```powershell
aws iam get-role --role-name GitHubOIDCDeployRole
```

### Re-apply Manifests Manually
```powershell
kubectl apply -f k8s/
```

## 🧹 Cleanup

To tear down all infrastructure:

```powershell
# Run as Administrator
.\Teardown-DevOps-Exercise.ps1
```

**What the teardown script does:**
- ✅ Destroys all Terraform-managed resources:
  - EKS cluster and node groups
  - ECR repository and images
  - IAM roles and policies
  - VPC and networking components
  - Load balancers
  - Monitoring stack
- ✅ Resets GitHub Actions workflow files to placeholder values
- ✅ Preserves Terraform state for reference

**Estimated time:** 10-15 minutes

### Manual Cleanup (if needed)

```powershell
# Remove Helm releases
helm uninstall kube-prom -n monitoring
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall fluent-bit -n kube-system

# Delete Kubernetes resources
kubectl delete -f k8s/

# Delete cluster (if Terraform fails)
eksctl delete cluster --name devops-exercise --region <region>
```

## 📝 Configuration Details

### Environment Variables
- `PORT`: Application port (default: 8080)
- `PYTHONDONTWRITEBYTECODE`: Prevents .pyc files
- `PYTHONUNBUFFERED`: Forces stdout/stderr to be unbuffered

### Resource Requests/Limits
Defined in `k8s/deployment.yaml`:
- CPU: 100m (request) / 200m (limit)
- Memory: 128Mi (request) / 256Mi (limit)

### Autoscaling
- Min replicas: 2
- Max replicas: 4
- Node scaling handled by EKS node group

## 🔐 Security Considerations

- **OIDC Authentication**: No long-lived AWS credentials in GitHub
- **IAM Least Privilege**: Deploy role has minimal required permissions
- **Private ECR**: Images stored in private repository
- **Network Policies**: Can be added to `k8s/` directory
- **Secrets Management**: Consider AWS Secrets Manager for sensitive data

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📚 Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Flask Documentation](https://flask.palletsprojects.com/)

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

**Built with ❤️ for DevOps excellence**
