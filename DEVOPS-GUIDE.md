# DevOps Guide - Branch Microloans API

This guide covers containerization, local development, CI/CD automation, and production deployment.

## Table of Contents
1. [Local Development Setup](#local-development-setup)
2. [Docker Environments](#docker-environments)
3. [CI/CD Pipeline](#cicd-pipeline)
4. [Production Deployment](#production-deployment)
5. [Troubleshooting](#troubleshooting)

## Local Development Setup

### Prerequisites
- Docker Desktop (v4.0+)
- Docker Compose (v2.0+)
- Git
- Python 3.11 (for local testing without Docker)

### Quick Start

1. **Clone the repository**
\`\`\`bash
git clone https://github.com/YOUR-USERNAME/dummy-branch-app.git
cd dummy-branch-app
\`\`\`

2. **Copy environment file**
\`\`\`bash
cp .env.example .env.development
# For local dev, the defaults are fine. Modify if needed.
\`\`\`

3. **Start services**
\`\`\`bash
docker-compose --env-file .env.development up -d
\`\`\`

4. **Initialize database**
\`\`\`bash
# Run migrations
docker-compose exec api alembic upgrade head

# Seed dummy data
docker-compose exec api python scripts/seed.py
\`\`\`

5. **Verify the API**
\`\`\`bash
# Health check
curl http://localhost:8000/health

# Get all loans
curl http://localhost:8000/api/loans

# Get stats
curl http://localhost:8000/api/stats
\`\`\`

### Development Workflow

**View logs:**
\`\`\`bash
# All services
docker-compose logs -f

# Just API
docker-compose logs -f api

# Just Database
docker-compose logs -f db
\`\`\`

**Stop services:**
\`\`\`bash
docker-compose down
\`\`\`

**Rebuild after dependency changes:**
\`\`\`bash
docker-compose --env-file .env.development up -d --build
\`\`\`

**Access database directly:**
\`\`\`bash
docker-compose exec db psql -U postgres -d microloans
\`\`\`

**Running tests locally:**
\`\`\`bash
# Without Docker
python -m pytest

# With Docker
docker-compose exec api pytest
\`\`\`

## Docker Environments

### Development Environment (`.env.development`)
- **Use case:** Local machine development
- **Database:** SQLite or local PostgreSQL
- **Auto-reload:** Enabled (gunicorn --reload)
- **Logging:** DEBUG level
- **Resource limits:** 256MB DB, 512MB API
- **Command:** `docker-compose up -d`

Example:
\`\`\`bash
docker-compose --env-file .env.development up -d --build
\`\`\`

### Staging Environment (`.env.staging`)
- **Use case:** Pre-production testing
- **Database:** Separate staging database
- **Auto-reload:** Disabled
- **Logging:** INFO level
- **Resource limits:** 1GB for both DB and API
- **Command:** `docker-compose up -d`

Example:
\`\`\`bash
docker-compose --env-file .env.staging up -d --build
\`\`\`

### Production Environment (`.env.production`)
- **Use case:** Production deployment
- **Database:** Managed RDS/Cloud SQL (not containerized)
- **Auto-reload:** Disabled
- **Logging:** WARN level (minimal logs)
- **Resource limits:** 2GB for both DB and API
- **Command:** Use with orchestration (Kubernetes, Docker Swarm, etc.)

Note: In production, use environment variables from your secret manager (AWS Secrets Manager, GitHub Secrets, Vault, etc.)

## CI/CD Pipeline

### GitHub Actions Workflow

The pipeline is defined in `.github/workflows/ci-cd.yml` and runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

### Pipeline Stages

1. **Test Stage**
   - Runs on Ubuntu latest
   - Sets up PostgreSQL service container
   - Runs pytest with coverage reporting
   - Uploads coverage to Codecov (optional)

2. **Build Stage**
   - Builds Docker image using Dockerfile.prod
   - Exports image for scanning
   - Caches layers for faster builds

3. **Security Scan Stage**
   - Scans image with Trivy for vulnerabilities
   - Fails on CRITICAL findings
   - Uploads results to GitHub Security tab

4. **Push Stage** (main branch only)
   - Authenticates with GitHub Container Registry
   - Pushes image with semantic versioning tags
   - Tags include: commit SHA, branch name, version numbers

### Pipeline Status

Check pipeline status: `https://github.com/YOUR-USERNAME/dummy-branch-app/actions`

View specific run details and logs for debugging.

## Production Deployment

### Prerequisites
- Managed PostgreSQL instance (AWS RDS, Google Cloud SQL, etc.)
- Container orchestration platform (Kubernetes, Docker Swarm, ECS, Cloud Run, etc.)
- CI/CD pipeline pushing images to container registry

### Deployment Methods

#### Option 1: Docker Swarm
\`\`\`bash
# Deploy service
docker service create \
  --name microloans-api \
  --env-file .env.production \
  --publish 8000:8000 \
  ghcr.io/your-username/dummy-branch-app:latest
\`\`\`

#### Option 2: Kubernetes
\`\`\`bash
# Create secret for environment variables
kubectl create secret generic microloans-env --from-file=.env.production

# Deploy using manifest
kubectl apply -f k8s/deployment.yaml
\`\`\`

Sample Kubernetes manifest (`k8s/deployment.yaml`):
\`\`\`yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microloans-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: microloans-api
  template:
    metadata:
      labels:
        app: microloans-api
    spec:
      containers:
      - name: api
        image: ghcr.io/your-username/dummy-branch-app:latest
        ports:
        - containerPort: 8000
        envFrom:
        - secretRef:
            name: microloans-env
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
\`\`\`

#### Option 3: Cloud Run (Google Cloud)
\`\`\`bash
# Build and push image
gcloud builds submit --tag gcr.io/PROJECT-ID/microloans-api

# Deploy
gcloud run deploy microloans-api \
  --image gcr.io/PROJECT-ID/microloans-api \
  --platform managed \
  --region us-central1 \
  --set-env-vars="DATABASE_URL=postgresql://..." \
  --memory 1Gi \
  --cpu 1
\`\`\`

### Database Migrations in Production

Before deploying new code:
\`\`\`bash
# Connect to container
kubectl exec -it microloans-api-pod -- /bin/bash

# Run migrations
alembic upgrade head

# Check migration status
alembic current
\`\`\`

Or use a Kubernetes Job for migrations:
\`\`\`yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: microloans-migrate
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: ghcr.io/your-username/dummy-branch-app:latest
        command: ["alembic", "upgrade", "head"]
        envFrom:
        - secretRef:
            name: microloans-env
      restartPolicy: Never
\`\`\`

### Monitoring & Logging

**Health Check Endpoint:**
\`\`\`bash
curl https://api.branchloans.com/health
\`\`\`

**View Logs:**
\`\`\`bash
# Kubernetes
kubectl logs -f deployment/microloans-api

# Docker
docker logs -f microloans-api

# Cloud Run
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=microloans-api" --limit 50
\`\`\`

## Troubleshooting

### Issue: "Connection refused" on localhost:8000

**Solution:**
\`\`\`bash
# Check if container is running
docker ps | grep api

# View logs
docker-compose logs api

# Restart services
docker-compose down
docker-compose up -d
\`\`\`

### Issue: Database migration failed

**Solution:**
\`\`\`bash
# Check migration status
docker-compose exec api alembic current

# View migration history
docker-compose exec api alembic history

# Downgrade and retry
docker-compose exec api alembic downgrade -1
docker-compose exec api alembic upgrade head
\`\`\`

### Issue: Port already in use

**Solution:**
\`\`\`bash
# Find process using port 8000
lsof -i :8000

# Kill process or use different port
docker-compose --env-file .env.development -e PORT=8001 up -d
\`\`\`

### Issue: Image build fails with permission denied

**Solution:**
\`\`\`bash
# Ensure Docker daemon is running
sudo systemctl restart docker  # Linux
# Or restart Docker Desktop on Mac/Windows

# Clear build cache
docker builder prune

# Rebuild
docker-compose up -d --build
\`\`\`

### Issue: Out of disk space

**Solution:**
\`\`\`bash
# Clean unused Docker resources
docker system prune -a

# Remove all stopped containers
docker container prune

# Remove all unused images
docker image prune -a
\`\`\`

## Security Best Practices

1. **Never commit `.env.production`** - Use environment variables from secret managers
2. **Use multi-stage builds** - Reduces final image size and attack surface
3. **Run as non-root user** - Containers run as `appuser` (UID 1001)
4. **Security scanning** - Trivy scans all images automatically in CI/CD
5. **Database encryption** - Enable encryption at rest for managed databases
6. **Network isolation** - Use VPC/security groups to restrict database access
7. **Secrets rotation** - Regularly rotate database passwords and API keys

## Additional Resources

- [Docker Documentation](https://docs.docker.com)
- [Docker Compose Documentation](https://docs.docker.com/compose)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flask Documentation](https://flask.palletsprojects.com)
- [Alembic Documentation](https://alembic.sqlalchemy.org)
- [Kubernetes Documentation](https://kubernetes.io/docs)
