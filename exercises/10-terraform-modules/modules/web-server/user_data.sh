#!/bin/bash
# Boot script for a lab web server. ${server_name} is filled in by
# Terraform's templatefile() from the module's name variable.
dnf install -y nginx
systemctl enable --now nginx
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>cloud-devops-lab</title></head>
<body>
<h1>Hello from ${server_name}</h1>
<p>A server built by a reusable Terraform module.</p>
</body>
</html>
EOF
