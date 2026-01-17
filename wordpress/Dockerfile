# BySamio WordPress - Non-root WordPress Docker Image
# Runs as non-root user (UID 1001) on port 8080
# Compatible with Kubernetes restricted Pod Security Standards
#
# Build: docker build -t ghcr.io/bysamio/wordpress:latest .
# Run:   docker run -p 8080:8080 ghcr.io/bysamio/wordpress:latest

ARG WORDPRESS_VERSION=6.9.0
FROM wordpress:${WORDPRESS_VERSION}-apache

LABEL org.opencontainers.image.title="BySamio WordPress"
LABEL org.opencontainers.image.description="Non-root WordPress image for Kubernetes"
LABEL org.opencontainers.image.vendor="BySam.io"
LABEL org.opencontainers.image.source="https://github.com/bysamio/charts"
LABEL org.opencontainers.image.licenses="MIT"

# Environment variables
ENV APACHE_RUN_USER=bysamio \
    APACHE_RUN_GROUP=bysamio \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    BYSAMIO_UID=1001 \
    BYSAMIO_GID=1001

# Create non-root user and group
RUN groupadd -g ${BYSAMIO_GID} bysamio && \
    useradd -u ${BYSAMIO_UID} -g bysamio -d /var/www/html -s /sbin/nologin bysamio

# Configure Apache to listen on port 8080 instead of 80
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-enabled/000-default.conf 2>/dev/null || true

# Remove default SSL configuration (we'll handle TLS at ingress level)
RUN a2dissite default-ssl 2>/dev/null || true && \
    rm -f /etc/apache2/sites-available/default-ssl.conf

# Configure Apache to run as non-root
RUN sed -i 's/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=bysamio/' /etc/apache2/envvars && \
    sed -i 's/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=bysamio/' /etc/apache2/envvars

# Create necessary directories and set permissions
RUN mkdir -p /var/run/apache2 /var/lock/apache2 /var/log/apache2 && \
    chown -R ${BYSAMIO_UID}:${BYSAMIO_GID} /var/www/html && \
    chown -R ${BYSAMIO_UID}:${BYSAMIO_GID} /var/run/apache2 && \
    chown -R ${BYSAMIO_UID}:${BYSAMIO_GID} /var/lock/apache2 && \
    chown -R ${BYSAMIO_UID}:${BYSAMIO_GID} /var/log/apache2 && \
    chown -R ${BYSAMIO_UID}:${BYSAMIO_GID} /etc/apache2 && \
    chmod -R g+rwX /var/www/html && \
    chmod -R g+rwX /var/run/apache2 && \
    chmod -R g+rwX /var/lock/apache2 && \
    chmod -R g+rwX /var/log/apache2

# Create wp-content subdirectories with proper permissions
RUN mkdir -p /var/www/html/wp-content/plugins \
             /var/www/html/wp-content/themes \
             /var/www/html/wp-content/uploads \
             /var/www/html/wp-content/upgrade && \
    chown -R ${BYSAMIO_UID}:${BYSAMIO_GID} /var/www/html/wp-content && \
    chmod -R 775 /var/www/html/wp-content

# Copy custom entrypoint script
COPY --chmod=755 entrypoint.sh /usr/local/bin/bysamio-entrypoint.sh

# Expose non-privileged port
EXPOSE 8080

# Switch to non-root user
USER ${BYSAMIO_UID}

# Use custom entrypoint that wraps the original
ENTRYPOINT ["/usr/local/bin/bysamio-entrypoint.sh"]
CMD ["apache2-foreground"]
