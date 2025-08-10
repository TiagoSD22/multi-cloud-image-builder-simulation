#!/bin/bash

# NGINX Installation and Configuration Script
# This script replaces the Chef cookbook functionality

set -e

echo "🔧 Starting NGINX installation and configuration..."

# Update package cache
echo "📦 Updating package cache..."
sudo apt-get update

# Install nginx package
echo "📦 Installing NGINX..."
sudo apt-get install -y nginx

# Create custom index.html
echo "📄 Creating custom welcome page..."
sudo tee /var/www/html/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Multi-Cloud NGINX Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            color: #333;
            border-bottom: 2px solid #007acc;
            padding-bottom: 20px;
        }
        .info {
            margin: 20px 0;
            padding: 15px;
            background: #e7f3ff;
            border-left: 4px solid #007acc;
        }
        .success {
            color: #28a745;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Multi-Cloud NGINX Server</h1>
            <p>Successfully deployed across AWS and GCP</p>
        </div>
        
        <div class="info">
            <h2>Server Information</h2>
            <p><strong>Server:</strong> NGINX</p>
            <p><strong>OS:</strong> Ubuntu 22.04 LTS</p>
            <p><strong>Provisioned with:</strong> Packer + Shell Scripts</p>
            <p><strong>Status:</strong> <span class="success">✅ Running</span></p>
        </div>
        
        <div class="info">
            <h2>Cloud Deployment Ready</h2>
            <ul>
                <li>☁️ AWS EC2 AMI</li>
                <li>☁️ Google Cloud GCE Image</li>
                <li>☁️ GCP Image</li>
            </ul>
        </div>
        
        <div class="info">
            <h2>Health Check</h2>
            <p>Visit <a href="/health">/health</a> for service status monitoring</p>
        </div>
        
        <footer style="text-align: center; margin-top: 30px; color: #666;">
            <p>Provisioned with ❤️ using Packer</p>
        </footer>
    </div>
</body>
</html>
EOF

# Set proper permissions for index.html
sudo chown www-data:www-data /var/www/html/index.html
sudo chmod 644 /var/www/html/index.html

# Configure nginx with optimized settings
echo "⚙️ Configuring NGINX..."
sudo tee /etc/nginx/sites-available/default > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;

    location / {
        try_files $uri $uri/ =404;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # Deny access to .htaccess files
    location ~ /\.ht {
        deny all;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Create a simple health check file
echo "🏥 Creating health check endpoint..."
echo 'OK' | sudo tee /var/www/html/health > /dev/null
sudo chown www-data:www-data /var/www/html/health
sudo chmod 644 /var/www/html/health

# Test nginx configuration
echo "🧪 Testing NGINX configuration..."
sudo nginx -t

# Enable and start nginx service
echo "🚀 Enabling and starting NGINX service..."
sudo systemctl enable nginx
sudo systemctl start nginx

# Open firewall for HTTP traffic (if ufw is present)
echo "🔥 Configuring firewall..."
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow 'Nginx Full' || echo "UFW rule already exists or UFW not active"
fi

# Verify nginx is running
echo "✅ Verifying NGINX status..."
sudo systemctl status nginx --no-pager

echo "🎉 NGINX installation and configuration completed successfully!"
echo "📋 NGINX is running and configured with:"
echo "   - Custom welcome page"
echo "   - Security headers"
echo "   - Gzip compression"
echo "   - Health check endpoint at /health"
