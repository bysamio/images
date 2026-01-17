# BySam.io Docker Images

A collection of security-hardened Docker images by the **BySam.io Organization**. These custom images are based on official images (WordPress, Keycloak, etc.) and are optimized for Kubernetes environments with enhanced security features.

## Purpose

This repository contains custom Docker images designed to:

- **Helm Charts**: Used as the default images in [BySam.io Helm Charts](https://github.com/bysamio/charts)
- **Standalone Use**: Can be used directly in Docker, Docker Compose, or Kubernetes deployments
- **Security Hardened**: Optimized for Kubernetes Pod Security Standards (restricted mode)
- **Production Ready**: Tested and maintained for production workloads

## Available Images

### WordPress

A security-hardened WordPress image that runs as non-root user on port 8080.

- **Image**: `ghcr.io/bysamio/wordpress:latest`
- **Documentation**: [wordpress/README.md](wordpress/README.md)
- **Features**:
  - Non-root execution (UID 1001)
  - Non-privileged port (8080)
  - Kubernetes restricted PSS compatible
  - Minimal capabilities

**Quick Start:**
```bash
docker run -d \
  -p 8080:8080 \
  -e WORDPRESS_DB_HOST=mariadb \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=secret \
  -e WORDPRESS_DB_NAME=wordpress \
  ghcr.io/bysamio/wordpress:latest
```

## Image Registry

All images are published to **GitHub Container Registry (GHCR)**:

- **Registry**: `ghcr.io/bysamio/<image-name>`
- **Organization**: [BySam.io](https://github.com/bysamio)

## Using with Helm Charts

These images are the default images in the [BySam.io Helm Charts](https://github.com/bysamio/charts) repository:

```bash
helm install my-wordpress oci://ghcr.io/bysamio/charts/wordpress
```

The Helm charts are pre-configured to use these images with appropriate security contexts and settings.

## Building Images

### Local Build

Each image directory contains a `Dockerfile` and supporting files. To build locally:

```bash
cd wordpress
docker build -t ghcr.io/bysamio/wordpress:latest .
```

### CI/CD

Images are automatically built and pushed to GHCR via GitHub Actions when changes are pushed to the `main` branch. Build workflows are located in `.github/workflows/`.

To trigger a manual build:

1. Navigate to the repository's Actions tab
2. Select the appropriate workflow
3. Click "Run workflow"

## Contributing

When adding a new image:

1. Create a new directory (e.g., `keycloak/`)
2. Add Dockerfile and supporting files
3. Create a `README.md` with image-specific documentation
4. Add a GitHub Actions workflow in `.github/workflows/`
5. Update this README.md with the new image information

## Security

All images in this repository are designed with security best practices:

- **Non-root execution**: All images run as non-root users
- **Minimal capabilities**: Designed to run with `capabilities.drop: ["ALL"]`
- **Pod Security Standards**: Compatible with Kubernetes restricted PSS
- **Regular updates**: Images are updated with security patches
- **Vulnerability scanning**: Automated scanning via Trivy in CI/CD

## Links

- [BySam.io Organization](https://github.com/bysamio)
- [BySam.io Helm Charts](https://github.com/bysamio/charts)
- [GitHub Container Registry](https://github.com/bysamio?tab=packages)

## License

MIT License - See [LICENSE](LICENSE) for details (if applicable).