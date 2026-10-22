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
docker build --build-arg WORDPRESS_VERSION=7.1.3 -t ghcr.io/bysamio/wordpress:7.1.3 .
```

### Multi-platform Build

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/bysamio/wordpress:latest \
  --push .
```

## Testing and Scanning

```bash
make test         # build, then: UID 1001, restricted context, real install against MariaDB
make scan         # Trivy gate: fails on fixable HIGH/CRITICAL findings
make scan-report  # full JSON report, including findings without a fix
make test-php-release  # fails if php.net has a newer release on the image's PHP branch
```

Prefix any target with `CONTAINER_ENGINE=podman` to use Podman. `make test-health`
(also run by the pre-commit hook) installs WordPress against MariaDB with all
capabilities dropped and `no-new-privileges`, then loads the front page and login
through Apache on port 8080. It also fails on a PHP version vulnerable to PHP2Shell.

### CI and weekly security scan

[`build-wordpress-image.yml`](../.github/workflows/build-wordpress-image.yml) runs on
pull requests, pushes to `main`, a weekly schedule (Mondays 04:29 UTC) and manual
dispatch:

1. **Verify** (every run): build linux/amd64, run the tests above, keep the full Trivy
   JSON report and a CycloneDX SBOM as a 30-day artifact, then fail on fixable
   HIGH/CRITICAL findings. Scheduled runs build without cache, so they pick up the
   current upstream tag and Debian security updates.
2. **Publish** (`main` only, after verify passes): push linux/amd64 and linux/arm64
   by digest, gate each platform on fixable HIGH/CRITICAL findings, and only then apply
   the `7.1.3`, `latest`, commit-SHA and `main` tags. A weekly run therefore
   republishes the same version tag with current OS patches; a failing gate leaves the
   previous image tagged and fails the run.
3. **PHP release check** (weekly and manual runs): Trivy cannot see PHP, which the
   upstream image compiles from source, so this job fails when php.net has a newer
   release on the image's PHP branch. PHP 8.3 only receives security fixes, so a newer
   8.3.x is a security release. The job does not block publication; rebuild once
   upstream ships the release, or bump `WORDPRESS_VERSION` if the current tag is no
   longer rebuilt.

## Vulnerability Status

**PHP2Shell is fixed.** PHP 8.3.36 fixes CVE-2026-109618 and CVE-2026-109619
(GHSA-w8hw-w9fx-j79w, GHSA-6wmf-4rv5-p3rp), unauthenticated remote code execution that
PHP rates most severe under Apache mod_php, the setup this image uses. Images built from
6.9.0 run PHP 8.3.30 and are vulnerable. The image's PHP source matches the official
`php-8.3.36.tar.xz` checksum. Trivy does not report PHP itself; `make test-health` and
the weekly PHP release check cover it.

Scanned 22 October 2026 with Trivy 0.71.1 (DB of the same day) on linux/amd64 and
linux/arm64: **0 fixable HIGH/CRITICAL findings**. Rebasing from 6.9.0 (Debian 13.3,
January 2026) cleared 844 fixable HIGH/CRITICAL CVEs, including 28 CRITICAL.

101 HIGH/CRITICAL CVEs remain (163 package occurrences, 2 CRITICAL). Debian has not
released a fix for any of them, and the counts are identical to upstream
`wordpress:7.1.3-apache`, so this image adds none. The weekly rebuild applies each fix
as soon as Debian publishes it.

| Package(s) | CVEs | Notes |
| --- | --- | --- |
| `linux-libc-dev` | 68, incl. CRITICAL CVE-2026-93221 | Kernel headers kept by the upstream PHP image so `docker-php-ext-install` works. Containers use the node's kernel; patch the node. |
| ImageMagick | 10 | Used by the `imagick` extension for media uploads; core WordPress only accepts those from logged-in users with the `upload_files` capability. |
| `libxml2` | 8, incl. CRITICAL CVE-2026-6653 (denial of service) | Linked by PHP's XML extensions. WordPress parses XML for XML-RPC, feeds and imports; block `xmlrpc.php` at the ingress if you do not use it. |
| util-linux family | 4 | Base system utilities. |
| Perl | 1 | Debian status `fix_deferred`. |
| curl, libtiff, CUPS, X11, ncurses, systemd, acl libraries | 10 | Base and ImageMagick dependency libraries; one libtiff finding is Debian `will_not_fix`. |

For the current numbers, download the `wordpress-linux-amd64-<run id>` artifact from the
latest workflow run or run `make scan-report`.

## Upgrading from 6.9

This release moves WordPress core from 6.9 to 7.1.3, PHP from 8.3.30 to 8.3.36 and
Debian from 13.3 to 13.7. PHP and the OS packages live in the image, so rolling out the
new image applies the PHP2Shell fix immediately, including on existing volumes.

WordPress core is different. The upstream entrypoint copies WordPress into `/var/www/html`
only when that directory has no WordPress yet. Fresh installs get 7.1.3, but an
existing persistent volume keeps its installed core until you update it from the
WordPress dashboard after rolling out the new image. WP-CLI works too, but only when
run as the file owner, UID 1001. Back up the database and volume first.

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
