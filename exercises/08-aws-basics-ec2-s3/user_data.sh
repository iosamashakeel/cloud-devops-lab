#!/bin/bash
# Boot script for the Exercise 08 EC2 instance (user_data).
# Runs once, on first boot: installs nginx and serves a small page
# so you can tell the instance apart from the default welcome page.
set -euo pipefail

dnf install -y nginx
systemctl enable nginx
systemctl start nginx

cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Hello from EC2</title></head>
<body>
<h1>Hello from EC2</h1>
<p>This page was installed by user_data on an Amazon Linux 2023 instance.</p>
</body>
</html>
HTML
