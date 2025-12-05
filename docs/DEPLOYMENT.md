# PotatoStack Deployment Guide

This guide explains how to deploy PotatoStack to your target infrastructure using the provided deployment scripts.

## Deployment Script

PotatoStack includes a comprehensive deployment script (`deploy.sh`) that automates the process of deploying the stack to a remote server via SSH.

### Prerequisites

Before deploying, ensure you have:

1. Target server with SSH access
2. SSH key-based authentication configured
3. Docker and Docker Compose available on the target server (script will install if missing)
4. Properly configured `.env` file with all required credentials
5. Access to the necessary storage volumes on the target server

### Using the Deployment Script

#### Basic Usage

```bash
# Deploy to staging environment
./deploy.sh staging --server your-server.com --user admin

# Deploy to production environment
./deploy.sh production --server lepotato.local --user root
```

#### Advanced Options

```bash
# Dry run to see what would be executed
./deploy.sh staging --server your-server.com --dry-run

# Deploy with custom target directory
./deploy.sh production --server your-server.com --dir /opt/potatostack --user admin

# Deploy with custom SSH key
./deploy.sh staging --server your-server.com --ssh-key ~/.ssh/custom_key
```

#### All Available Options

- `--server`: Target server hostname/IP (required)
- `--user`: Target server user (default: root)
- `--dir`: Target directory on server (default: /opt/potatostack)
- `--ssh-key`: Path to SSH private key (default: ~/.ssh/id_rsa)
- `--dry-run`: Show what would be done without executing
- `-h, --help`: Show help message

### CI/CD Integration

The deployment script is designed to work with the CI/CD pipeline defined in `.github/workflows/cd.yml`. In the CI/CD context, the deployment will be triggered manually with the workflow dispatch and will:

1. Validate all tests pass
2. Build and verify Docker images
3. Create a deployment package
4. Deploy to the selected environment (staging or production)
5. Perform post-deployment validation
6. Send notification of deployment status

### Deployment Process

The deployment script performs the following steps:

1. **Validation**: Checks that the script is run from the project root and all required files exist
2. **Package Creation**: Creates a tarball containing all necessary files for deployment
3. **Upload**: Transfers the deployment package to the target server
4. **Setup**: Extracts the package and ensures Docker/Docker Compose are available
5. **Configuration**: Copies environment files and performs any necessary setup steps
6. **Deployment**: Pulls latest Docker images and starts the services
7. **Validation**: Checks that services are running properly
8. **Cleanup**: Removes temporary files

### Environment-Specific Configuration

For different environments, you should have different `.env` files configured:

- `staging` environment: Less restrictive settings, test credentials
- `production` environment: Secure settings, production credentials

### Security Considerations

- Never commit your `.env` file to version control
- Use strong, unique passwords for all services
- Restrict SSH access to the deployment server
- Ensure proper firewall rules are in place
- For production deployments, always verify the deployment script behavior in staging first

### Troubleshooting

#### Common Issues

1. **Permission Denied**: Ensure your SSH key has the correct permissions (600) and is added to ssh-agent
2. **Docker Not Found**: The script will try to install Docker automatically, but you may need to do this manually
3. **Service Fails to Start**: Check the logs with `docker-compose logs -f` on the target server

#### Verify Deployment

After deployment, verify everything is working:

```bash
# Check service status
ssh user@server 'cd /opt/potatostack && docker-compose ps'

# Check logs for any errors
ssh user@server 'cd /opt/potatostack && docker-compose logs'

# Verify specific services are accessible
curl http://your-server:3003  # Homepage should return HTML
```

### Rollback Process

If you need to rollback a deployment:

```bash
# On the target server
cd /opt/potatostack
docker-compose down
git checkout <previous-commit-hash>
docker-compose up -d
```

Or using the deployment script with a previous package if you have one available.

### Monitoring Deployment Status

After deployment, monitor the services:

- Homepage Dashboard: Check the status of all services
- Grafana: Monitor system and container metrics
- Uptime Kuma: Verify all services are responding as expected
- Dozzle: Review container logs for any issues