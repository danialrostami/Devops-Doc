## Installation: Docker Compose with SSL
This setup uses **Nginx** as a reverse proxy to handle SSL termination for Nexus Repository Manager.

1. **Create Directory Structure**


```bash
mkdir -p /opt/nexus/nginx/{conf,logs,certs,html}
```

2. **Generate a Self-Signed SSL Certificate**

Use OpenSSL to generate a certificate in `/opt/nexus/nginx/certs/`
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout private.key \
  -out certificate.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=your-domain.com"

```
3. **Save your Nginx config file to /opt/nexus/nginx/conf/**

4. **Set Proper Ownership**

```
sudo chown -R 1000:1000 /opt/nexus/nginx/

```

5. **`docker compose up -d`**

6. **visit `https://your-server-ip-or-domain/`**
---
## Retrieve the Initial Admin Password
```
# Get the container ID
docker ps

# Access the container's shell
docker exec -it <nexus-container-id-or-name> /bin/bash

# Find the password file
cat /nexus-data/admin.password
```
---
