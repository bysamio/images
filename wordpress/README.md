# BySamio WordPress

A security-hardened WordPress Docker image designed for Kubernetes environments.

## Features

- **Non-root execution**: Runs as UID 1001 (bysamio user) from startup
- **Non-privileged port**: Uses port 8080 instead of 80
- **Restricted PSS compatible**: Works with Kubernetes restricted Pod Security Standards
- **Minimal capabilities**: Designed to run with `capabilities.drop: ["ALL"]`
- **Based on official image**: Built on top of `wordpress:apache` for compatibility

## Quick Start

### Docker

```bash
docker run -d \
  -p 8080:8080 \
  -e WORDPRESS_DB_HOST=mariadb \
  -e WORDPRESS_DB_USER=wordpress \
  -e WORDPRESS_DB_PASSWORD=secret \
  -e WORDPRESS_DB_NAME=wordpress \
  ghcr.io/bysamio/wordpress:latest
```

### Docker Compose

```yaml
version: '3.8'
services:
  wordpress:
    image: ghcr.io/bysamio/wordpress:latest
    ports:
      - "8080:8080"
    environment:
      WORDPRESS_DB_HOST: mariadb
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: secret
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress_data:/var/www/html
    depends_on:
      - mariadb

  mariadb:
    image: mariadb:11
    environment:
      MYSQL_ROOT_PASSWORD: rootsecret
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: secret
    volumes:
      - db_data:/var/lib/mysql

volumes:
  wordpress_data:
  db_data:
```

### Kubernetes (with BySamio Helm Chart)

```bash
helm install my-wordpress oci://ghcr.io/bysamio/charts/wordpress
```

## Environment Variables

All standard WordPress environment variables are supported:

| Variable | Description | Default |
|----------|-------------|---------|
| `WORDPRESS_DB_HOST` | Database hostname | `mysql` |
| `WORDPRESS_DB_USER` | Database username | `root` |
| `WORDPRESS_DB_PASSWORD` | Database password | (required) |
| `WORDPRESS_DB_NAME` | Database name | `wordpress` |
| `WORDPRESS_TABLE_PREFIX` | Table prefix | `wp_` |
| `WORDPRESS_DEBUG` | Enable debug mode | `false` |
| `WORDPRESS_CONFIG_EXTRA` | Extra wp-config.php content | |

## Security

### User and Permissions

- **User**: `bysamio` (UID 1001)
- **Group**: `bysamio` (GID 1001)
- **Port**: 8080 (non-privileged)

### Kubernetes Security Context

```yaml
securityContext:
  runAsUser: 1001
  runAsGroup: 1001
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

### Pod Security Standards

This image is compatible with the **restricted** Pod Security Standard, the most restrictive policy available in Kubernetes.

## Volume Permissions

When using persistent volumes, ensure the volume has correct permissions for UID 1001:

```bash
# Using an init container
initContainers:
  - name: fix-permissions
    image: busybox
    command: ["sh", "-c", "chown -R 1001:1001 /var/www/html"]
    volumeMounts:
      - name: wordpress-data
        mountPath: /var/www/html
    securityContext:
      runAsUser: 0
```

Or set `fsGroup` in the pod security context:

```yaml
securityContext:
  fsGroup: 1001
```

## Building

### Local Build

```bash
cd wordpress
docker build -t ghcr.io/bysamio/wordpress:latest .
```

### Build with specific WordPress version

```bash
docker build --build-arg WORDPRESS_VERSION=6.9.0 -t ghcr.io/bysamio/wordpress:6.9.0 .
```

### Multi-platform Build

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/bysamio/wordpress:latest \
  --push .
```

## Differences from Official WordPress Image

| Feature | Official Image | BySamio Image |
|---------|---------------|---------------|
| Default user | root (UID 0) | bysamio (UID 1001) |
| Default port | 80 | 8080 |
| Privilege escalation | Required | Not required |
| Capabilities | Full root | None needed |
| PSS compatibility | privileged | restricted |

## Migration from Official Image

If migrating from the official WordPress image:

1. Update your deployment to use port 8080
2. Update security context to use UID 1001
3. Ensure volumes have correct permissions (UID 1001)
4. Update service targetPort to 8080

## Troubleshooting

### Permission denied errors

Ensure your persistent volume has correct permissions:

```bash
kubectl exec -it <pod> -- ls -la /var/www/html
```

Files should be owned by UID 1001.

### Apache won't start

Check if the container has the required permissions:

```bash
kubectl logs <pod>
```

Ensure `allowPrivilegeEscalation: false` and `runAsNonRoot: true` are set.

### Database connection issues

Verify environment variables are set correctly:

```bash
kubectl exec -it <pod> -- printenv | grep WORDPRESS_DB
```

## License

MIT License - See [LICENSE](../LICENSE) for details.

## Links

- [BySamio Helm Charts](https://github.com/bysamio/charts)
- [Official WordPress Image](https://hub.docker.com/_/wordpress)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
