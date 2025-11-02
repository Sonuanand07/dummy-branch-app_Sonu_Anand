# Flask Microloans API + Postgres (Docker)

Minimal REST API for microloans, built with Flask, SQLAlchemy, Alembic, and PostgreSQL (via Docker Compose).

## Quick start

```bash
# 1) Build and start services
docker compose up -d --build

# 2) Run DB migrations
docker compose exec api alembic upgrade head

# 3) Seed dummy data (idempotent)
docker compose exec api python scripts/seed.py

# 4) Hit endpoints
curl http://localhost:8000/health
curl http://localhost:8000/api/loans
```

## Configuration

See `.env.example` for env vars. By default:
- `DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/microloans`
- API listens on `localhost:8000`.

## API

- GET `/health` → `{ "status": "ok" }`
- GET `/api/loans` → list all loans
- GET `/api/loans/:id` → get loan by id
- POST `/api/loans` → create loan (status defaults to `pending`)

Example create:
```bash
curl -X POST http://localhost:8000/api/loans \
  -H 'Content-Type: application/json' \
  -d '{
    "borrower_id": "usr_india_999",
    "amount": 12000.50,
    "currency": "INR",
    "term_months": 6,
    "interest_rate_apr": 24.0
  }'
```

- GET `/api/stats` → aggregate stats: totals, avg, grouped by status/currency.

## Development

- App entrypoint: `wsgi.py` (`wsgi:app`)
- Flask app factory: `app/__init__.py`
- Models: `app/models.py`
- Migrations: `alembic/`

## Notes

- Amounts are validated server-side (0 < amount ≤ 50000).
- No authentication for this prototype.

# Branch Loan API - Production-Ready DevOps Solution

A comprehensive DevOps transformation of the Branch Loan API service, featuring containerization, multi-environment support, CI/CD automation, and observability.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Environment Setup](#environment-setup)
- [Running Locally](#running-locally)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring & Observability](#monitoring--observability)
- [Troubleshooting](#troubleshooting)
- [Design Decisions](#design-decisions)

## Quick Start

### Prerequisites

- Docker and Docker Compose (v20.10+)
- Node.js 18+ (for local development)
- Git
- OpenSSL (for certificate generation)

### Run Locally in 5 Minutes

\`\`\`bash
# 1. Clone and setup
git clone <your-fork-url>
cd <repo>

# 2. Generate SSL certificates
chmod +x scripts/generate-certs.sh
./scripts/generate-certs.sh

# 3. Setup local domain
chmod +x scripts/setup-local-domain.sh
./scripts/setup-local-domain.sh

# 4. Start development environment
docker-compose --env-file .env.development up -d

# 5. Wait for containers to be healthy
docker-compose ps

# 6. Access the API
curl -k https://branchloans.com/health
\`\`\`

The API will be available at `https://branchloans.com` (self-signed certificate in dev).

## Architecture

\`\`\`
┌─────────────────────────────────────────────────┐
│           Local Machine / Production            │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │      HTTPS Load Balancer / Ingress       │  │
│  │     (branchloans.com:443)                │  │
│  └────────────────┬─────────────────────────┘  │
│                   │                             │
│  ┌────────────────▼─────────────────────────┐  │
│  │    Loan API Container                    │  │
│  │  ┌──────────────────────────────────┐   │  │
│  │  │ Node.js Express Server           │   │  │
│  │  │ - Health Check (/health)         │   │  │
│  │  │ - Loan APIs (/api/loans/*)       │   │  │
│  │  │ - Metrics (/metrics)             │   │  │
│  │  │ - Stats (/api/stats)             │   │  │
│  │  └──────────────────────────────────┘   │  │
│  └────────────────┬─────────────────────────┘  │
│                   │                             │
│  ┌────────────────▼─────────────────────────┐  │
│  │    PostgreSQL Database Container        │  │
│  │  ┌──────────────────────────────────┐   │  │
│  │  │ Loans Table                      │   │  │
│  │  │ Indices, Health Checks           │   │  │
│  │  │ Persistent Volume                │   │  │
│  │  └──────────────────────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │   Monitoring Stack (Optional)            │  │
│  │  ┌─────────────┐  ┌──────────────────┐  │  │
│  │  │ Prometheus  │  │ Grafana (3001)   │  │  │
│  │  │ (9090)      │  │ dashboards       │  │  │
│  │  └─────────────┘  └──────────────────┘  │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
\`\`\`

## Environment Setup

### Development Environment

**Purpose**: Local development with hot-reload and debug logging

- **Database**: Single PostgreSQL instance (512MB memory)
- **API**: Single instance with debug logging, hot-reload enabled
- **Configuration**: `.env.development`
- **Use Case**: Developer laptops, local testing

\`\`\`bash
export ENV=dev
docker-compose --env-file .env.development up -d
\`\`\`

### Staging Environment

**Purpose**: Pre-production testing that mirrors production configuration

- **Database**: PostgreSQL with medium resources (1GB memory)
- **API**: Single instance with standard logging
- **Configuration**: `.env.staging`
- **Use Case**: QA testing, performance validation, production rehearsal

\`\`\`bash
export ENV=staging
docker-compose --env-file .env.staging up -d
\`\`\`

### Production Environment

**Purpose**: High-availability production deployment

- **Database**: Large PostgreSQL with resource limits (2GB memory), persistent storage
- **API**: Multiple instances (use Kubernetes or orchestration in real production)
- **Configuration**: `.env.production` (use secrets management)
- **Use Case**: Customer-facing service, monitoring, high-availability

\`\`\`bash
# Use secrets management in production, not .env files
docker-compose --env-file .env.production up -d
\`\`\`

## Running Locally

### 1. Initial Setup

\`\`\`bash
# Generate self-signed SSL certificates
./scripts/generate-certs.sh

# This creates:
# - certs/server.key
# - certs/server.crt

# Setup local domain resolution
./scripts/setup-local-domain.sh

# This adds "127.0.0.1 branchloans.com" to your /etc/hosts
\`\`\`

### 2. Start All Services

\`\`\`bash
# Development (with hot-reload)
docker-compose --env-file .env.development up -d

# Staging
docker-compose --env-file .env.staging up -d

# Production (requires .env.production)
docker-compose --env-file .env.production up -d
\`\`\`

### 3. Verify Everything is Running

\`\`\`bash
# Check container status
docker-compose ps

# Expected output:
# NAME                  STATUS              PORTS
# branch-db-dev         Up (healthy)        0.0.0.0:5432->5432/tcp
# branch-api-dev        Up (healthy)        0.0.0.0:3000->3000/tcp, 0.0.0.0:443->443/tcp

# Check API health
curl -k https://branchloans.com/health

# Response should be: {"status": "ok", "timestamp": "..."}

# Get loan statistics
curl -k https://branchloans.com/api/stats

# List all loans
curl -k https://branchloans.com/api/loans
\`\`\`

### 4. Switch Environments

\`\`\`bash
# Stop current environment
docker-compose down

# Start different environment
docker-compose --env-file .env.staging up -d

# Each environment has isolated:
# - Data volumes
# - Resource limits
# - Environment variables
# - Port mappings
\`\`\`

### 5. View Logs

\`\`\`bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api

# Specific service with timestamps
docker-compose logs -f --timestamps db
\`\`\`

### 6. Access Database Directly

\`\`\`bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U postgres -d branch_loans

# Inside psql:
# \dt                 - List tables
# SELECT * FROM loans; - View all loans
# \q                  - Exit
\`\`\`

## CI/CD Pipeline

The GitHub Actions workflow automates the entire deployment process:

### Pipeline Stages

1. **Test Stage** (`test`)
   - Runs unit tests against PostgreSQL test database
   - Runs code linting
   - Fails pipeline if tests don't pass
   - Runs in parallel with security scanning

2. **Build Stage** (`build`)
   - Builds Docker image with optimizations
   - Caches layers for faster builds
   - Generates metadata tags (commit SHA, branch, version)
   - Uploads image as artifact for security scanning

3. **Security Scan Stage** (`security-scan`)
   - Runs Trivy vulnerability scanner on Docker image
   - Scans for CRITICAL and HIGH severity vulnerabilities
   - Uploads results to GitHub Security dashboard
   - **Fails pipeline** if critical vulnerabilities found

4. **Push Stage** (`push`)
   - Only runs on `main` branch after successful tests and scans
   - Pushes image to GitHub Container Registry (ghcr.io)
   - Tags with:
     - `latest` (for main branch)
     - `<commit-sha>` (for traceability)
     - `v<version>` (for semantic versioning)

### Trigger Conditions

- **Full pipeline**: `git push` to `main` or `develop` branches
- **Tests & scans only**: Pull requests to `main` or `develop`
- **Push to registry**: Only on `main` branch after all checks pass

### Configuration

All sensitive data is stored as GitHub Secrets:
- `GITHUB_TOKEN` - Automatically available for registry authentication
- Database credentials - Use secrets in `.env.production`

### Example Workflow

\`\`\`
Developer creates PR
    ↓
GitHub Actions triggers tests + build + security scan
    ↓
PR review + approval
    ↓
git merge → main
    ↓
Tests pass ✓
Build succeeds ✓
Security scan passes ✓
    ↓
Image pushed to ghcr.io
    ↓
Deployment system pulls image
    ↓
Service updated
\`\`\`

## Monitoring & Observability

### Health Check Endpoint

The API includes a comprehensive health check that verifies service readiness:

\`\`\`bash
curl -k https://branchloans.com/health

# Response:
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:45Z",
  "database": "connected",
  "uptime": 3600
}
\`\`\`

The endpoint:
- Checks API process is running
- Verifies database connectivity
- Reports uptime
- Used by Docker health checks and load balancers

### Structured Logging

The application outputs structured JSON logs for easier parsing and analysis:

\`\`\`json
{
  "timestamp": "2024-01-15T10:30:45Z",
  "level": "info",
  "requestId": "req-12345",
  "method": "GET",
  "path": "/api/loans",
  "statusCode": 200,
  "duration": 45,
  "userId": "user-001"
}
\`\`\`

Log levels configurable via `LOG_LEVEL` environment variable:
- `debug` - Development: verbose logs
- `info` - Staging: key events
- `warn` - Production: warnings and errors only

### Prometheus Metrics (Bonus)

Enable monitoring with:

\`\`\`bash
docker-compose --profile monitoring -f docker-compose.yml up -d
\`\`\`

This starts:
- **Prometheus** (http://localhost:9090) - Metrics database
- **Grafana** (http://localhost:3001) - Visualization dashboards

Available metrics at `/metrics`:
- `http_requests_total` - Total API requests
- `http_request_duration_seconds` - Request latency
- `http_errors_total` - Error count
- `db_query_duration_seconds` - Database query time

Default Grafana credentials: `admin` / `admin`

## Troubleshooting

### Common Issues

#### 1. "branchloans.com not found" after setup

**Problem**: The local domain isn't resolving

**Solution**:
\`\`\`bash
# Verify it's in /etc/hosts
cat /etc/hosts | grep branchloans

# If missing, re-run setup script
./scripts/setup-local-domain.sh

# For macOS, may need to flush DNS
sudo dscacheutil -flushcache

# Test DNS resolution
nslookup branchloans.com
\`\`\`

#### 2. "Connection refused" on HTTPS

**Problem**: Port 443 is already in use or SSL certificate missing

**Solution**:
\`\`\`bash
# Check if port 443 is in use
lsof -i :443  # macOS/Linux
netstat -ano | findstr :443  # Windows

# Kill the process using port 443 or use different port
# Regenerate certificates
./scripts/generate-certs.sh

# Check certificate exists
ls -la certs/
\`\`\`

#### 3. "Failed to connect to database"

**Problem**: PostgreSQL container not starting

**Solution**:
\`\`\`bash
# Check container logs
docker-compose logs postgres

# Verify PostgreSQL is healthy
docker-compose ps postgres

# Restart the database
docker-compose restart postgres

# Check if port 5432 is available
lsof -i :5432
\`\`\`

#### 4. "Permission denied" running scripts

**Problem**: Scripts aren't executable

**Solution**:
\`\`\`bash
chmod +x scripts/*.sh
\`\`\`

#### 5. Docker image build fails

**Problem**: Dependencies not installing

**Solution**:
\`\`\`bash
# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker-compose build --no-cache

# Check Docker logs
docker-compose logs api
\`\`\`

#### 6. "CORS or SSL certificate" errors in browser

**Problem**: Self-signed certificate warnings

**Solution**:
\`\`\`bash
# For development, accept the certificate warning in browser
# Or import certificate to your system trust store

# macOS:
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/server.crt

# Linux (Ubuntu):
sudo cp certs/server.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Windows:
# Right-click certs/server.crt → Install Certificate
\`\`\`

### Debugging Commands

\`\`\`bash
# View all running containers
docker ps -a

# View container resource usage
docker stats

# Enter container shell
docker exec -it branch-api-dev sh

# View container environment variables
docker exec branch-api-dev env

# Monitor logs in real-time
docker-compose logs --follow --timestamps

# Check Docker network connectivity
docker-compose exec api ping postgres
\`\`\`

## Design Decisions

### 1. Multi-Stage Dockerfile

**Decision**: Use separate development and production Dockerfiles

**Why**:
- Production image (`Dockerfile.prod`) is optimized and minimal
- Development image (`Dockerfile`) includes hot-reload capabilities
- Reduces production image size by ~60%
- Better security posture in production

**Trade-off**: Requires maintaining two Dockerfiles

### 2. Docker Compose for All Environments

**Decision**: Single docker-compose.yml with environment variable profiles

**Why**:
- One source of truth for service definitions
- Environment differences are parameterized (.env files)
- Easy to switch between environments locally
- Mirrors how Kubernetes specs work

**Trade-off**: Some flexibility lost compared to platform-specific configs

### 3. Health Checks at Multiple Levels

**Decision**: Health checks in Dockerfile, docker-compose, and application

**Why**:
- Dockerfile: Initial startup verification
- Docker-compose: Service dependency management
- Application: Deep system health monitoring
- Orchestrators use this data for automatic recovery

**Trade-off**: Slight performance overhead from health check frequency

### 4. GitHub Container Registry

**Decision**: Use ghcr.io over Docker Hub

**Why**:
- Free for public and private repos
- Integrated GitHub authentication
- Automatic SBOM generation
- Tight GitHub Actions integration

**Trade-off**: Tied to GitHub ecosystem

### 5. Prometheus + Grafana for Observability

**Decision**: Industry-standard open-source monitoring stack

**Why**:
- Zero cost, widely adopted
- Excellent for early-stage companies
- Easy migration path if needed
- Native Docker support

**Trade-off**: Self-hosted requires ops knowledge; consider managed services at scale

### 6. Non-Root User in Containers

**Decision**: Run containers as unprivileged `nodejs` user

**Why**:
- Reduces blast radius of container escape
- Follows Docker security best practices
- Prevents accidental privilege escalation
- Required for production deployments

### 7. dumb-init Process Manager

**Decision**: Use dumb-init to handle signals properly

**Why**:
- Ensures graceful shutdown (SIGTERM handling)
- Prevents zombie processes
- Docker sends PID 1 signals; Node.js doesn't handle them by default
- Crucial for orchestrators to stop containers cleanly

## Next Steps

### For Production Deployment

1. **Kubernetes**: Migrate from Docker Compose to Kubernetes manifests
2. **Secrets Management**: Use AWS Secrets Manager, HashiCorp Vault, or similar
3. **Database**: Switch to managed PostgreSQL (RDS, Cloud SQL, Managed Kubernetes)
4. **CDN/Load Balancer**: Add CloudFlare, AWS ALB, or nginx
5. **Logging**: Centralize logs to ELK, CloudWatch, or Datadog
6. **Alerting**: Set up PagerDuty or similar for on-call

### For Scalability

1. **Horizontal Scaling**: Run multiple API instances behind load balancer
2. **Caching**: Add Redis for session/data caching
3. **Database Optimization**: Read replicas, connection pooling
4. **Async Jobs**: Implement message queue (RabbitMQ, AWS SQS) for long-running tasks

### Security Hardening

1. **Network Policies**: Restrict service-to-service communication
2. **RBAC**: Implement role-based access control
3. **Audit Logging**: Track all API access and changes
4. **Rate Limiting**: Add rate limiting to API endpoints
5. **Data Encryption**: Encrypt data at rest and in transit

## Additional Resources

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Prometheus Getting Started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Node.js Best Practices](https://nodejs.org/en/docs/guides/nodejs-docker-webapp/)

---

**Created**: January 2024
**Version**: 1.0.0
**Author**: DevOps Team, Branch
