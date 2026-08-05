# HAProxy  Practical Guide

A  production-grade guide covering the installation, architecture, core concepts, and practical configurations of HAProxy.

---

## Table of Contents
- [Overview & Key Features](overview--key-features)
- [Core Architecture](core-architecture)
- [Installation](installation)
- [Global & Default Configurations](global--default-configurations)
- [Layer 4 vs Layer 7 Load Balancing](layer-4-vs-layer-7-load-balancing)
- [Load-Balancing Algorithms](load-balancing-algorithms)
- [Health Checks](#health-checks)
- [Layer 7 HTTP Routing with ACLs](layer-7-http-routing-with-acls)
- [Host-Based Routing](host-based-routing)
- [Sticky Sessions with Cookies](sticky-sessions-with-cookies)
- [Regular Expressions (Regex) in HAProxy](regular-expressions-regex-in-haproxy)
- [Manipulating HTTP Responses](manipulating-http-responses)
- [Monitoring & Statistics Dashboard](monitoring--statistics-dashboard)
- [Best Practices & Security Hardening](best-practices--security-hardening)

---

##  Overview & Key Features

HAProxy (High Availability Proxy) is an industry-standard, open-source TCP/HTTP load balancer and proxying solution. It is designed to distribute incoming traffic across multiple backend servers to prevent resource exhaustion, optimize resource utilization, and guarantee high availability.

### Key Use Cases
* **Load Balancing:** Seamlessly distributes incoming network traffic across a cluster of backend servers.
* **Reverse Proxying:** Acts as an intermediary to inspect, filter, modify, or route incoming client requests before they reach backend application servers.
* **High Availability:** Performs active health checks to detect server failures and dynamically reroutes traffic to healthy nodes.
* **SSL/TLS Termination:** Offloads CPU-intensive cryptographic handshake and encryption processes from application servers.

---

##  Core Architecture

The configuration of HAProxy is structured into three primary structural blocks:

* **Frontend:** Defines how HAProxy listens for connections. It binds to specific IP addresses and ports, accepts incoming traffic, and applies routing logic.
* **Backend:** A pool of target servers that actually process the requests. It defines the load-balancing algorithm and health check parameters.
* **Listeners / Stats:** Special blocks (often configured using `listen`) that combine frontend and backend capabilities in a single definition, commonly used for monitoring dashboards.

---

##  Installation

### On Debian / Ubuntu
```bash
sudo apt update
sudo apt install haproxy -y
```

### On CentOS / RHEL / Rocky Linux 9
```bash
sudo dnf install epel-release -y
sudo dnf install haproxy -y
```

Verify the installation and check the version:
```bash
haproxy -v
```

---

##  Global & Default Configurations

The primary configuration file is located at `/etc/haproxy/haproxy.cfg`.

### Global vs Defaults
* **`global`:** Defines process-wide parameters such as security privileges, system logging, and global limits.
* **`defaults`:** Specifies fallback settings for timeouts, logs, and options applied to all subsequent frontend and backend declarations.

### Example Settings:
```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    daemon
    stats socket /var/run/haproxy.sock mode 600 level admin

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  forwardfor
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    timeout http-request 10s
    timeout http-keep-alive 10s
    timeout queue 30s
    retries 3
```

### Configuration Breakdown
* **`log /dev/log local0`:** Sends operational logs to the local syslog socket `/dev/log` under the syslog facility `local0`.
* **`maxconn 4096`:** Sets the maximum limit of concurrent connections the HAProxy process is allowed to accept.
* **`mode http`:** Enables HTTP-aware processing. Use `mode tcp` for protocol-agnostic TCP forwarding.
* **`daemon`:** Forces HAProxy to run in the background as a system service.
* **`option forwardfor`:** Adds `X-Forwarded-For` to HTTP requests.
* **`timeout http-request`:** Maximum time allowed to receive and parse an HTTP request.
* **`stats socket ...`:** Exposes a UNIX domain socket for real-time runtime API operations and administration.
* **`option httplog`:** Enables verbose HTTP request logging (including client IP, status codes, request URI, and timers).
* **`timeout connect 5000ms`:** Specifies the maximum time to wait for a TCP connection establishment to a backend server.
* **`timeout client 50000ms` / `timeout server 50000ms`:** Defines the maximum inactivity periods allowed on the client and backend server sides respectively.

---

##  Layer 4 vs Layer 7 Load Balancing

HAProxy operates at two primary layers of the OSI model:

### Layer 4 (TCP Level)
Decisions are made based on IP address and TCP/UDP port data without inspecting the packet payload. This is highly performant and ideal for database clusters (PostgreSQL, MySQL) or generic TCP streams.

```haproxy
frontend tcp_front
    bind *:443
    mode tcp
    default_backend tcp_back

backend tcp_back
    mode tcp
    balance roundrobin
    server server1 192.168.1.101:443 check
    server server2 192.168.1.102:443 check
```

### Layer 7 (Application Level)
Decisions are made based on the actual application payload (HTTP headers, cookies, query parameters, URI paths). This is standard for modern web architectures.
Minimal HTTP Load Balancer
```
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 10000
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  forwardfor
    timeout connect 5s
    timeout client  30s
    timeout server  30s

frontend public_http
    bind :80
    default_backend web_servers

backend web_servers
    balance roundrobin
    option httpchk GET /healthz
    http-check expect status 200
    server web01 192.168.10.11:80 check
    server web02 192.168.10.12:80 check
    server web03 192.168.10.13:80 check
```
- The `/healthz` endpoint should be a lightweight endpoint that returns HTTP `200` only when the server is ready to receive traffic. A TCP `check` alone proves that a port is open; it does not prove that the application is healthy.
---

## Load-Balancing Algorithms

### Round Robin

```haproxy
backend web_servers
    balance roundrobin
```

Servers are selected sequentially. This is a good default when backend servers have similar capacity and requests have similar cost.

### Least Connections

```haproxy
backend web_servers
    balance leastconn
```

New connections are sent to the server with the fewest active connections. This is often useful for requests with variable processing time.

### Source Hashing

```haproxy
backend web_servers
    balance source
```

The client source IP is hashed to select a server. This can provide persistence without a cookie, but it is less reliable behind NAT, proxies, or changing client addresses.

### Server Weights

```haproxy
backend web_servers
    balance roundrobin
    server web01 192.168.10.11:80 check weight 2
    server web02 192.168.10.12:80 check weight 1
```

`web01` receives approximately twice as much traffic as `web02`, assuming both are healthy.

## Health Checks

### HTTP Health Check

```haproxy
backend api_servers
    option httpchk
    http-check send meth GET uri /readyz ver HTTP/1.1 hdr Host api.internal.example.com
    http-check expect status 200
    server api01 192.168.20.11:8080 check inter 3s fall 3 rise 2
    server api02 192.168.20.12:8080 check inter 3s fall 3 rise 2
```

- `inter 3s`: Check interval.
- `fall 3`: Mark a server down after three consecutive failures.
- `rise 2`: Mark it healthy after two consecutive successes.

### Backup and Maintenance Servers

```haproxy
backend web_servers
    server web01 192.168.10.11:80 check
    server web02 192.168.10.12:80 check
    server web-maintenance 192.168.10.50:80 check backup
```

A `backup` server receives traffic only when all regular servers are unavailable. Use `disabled` for a server that should remain configured but receive no traffic until enabled through the runtime socket.

---
##  Layer 7 HTTP Routing with ACLs

Access Control Lists (ACLs) allow flexible request routing by matching criteria in HTTP headers or paths.

### Sample Configuration
```haproxy
frontend http_front
    bind *:80
    mode http

    # Define ACL to check if path starts with "/api"
    acl is_api path_beg /api

    # Direct traffic to specific backends based on matching ACL
    use_backend api_servers if is_api
    default_backend web_servers

backend api_servers
    mode http
    balance roundrobin
    server api1 192.168.1.201:80 check
    server api2 192.168.1.202:80 check

backend web_servers
    mode http
    balance roundrobin
    server web1 192.168.1.101:80 check
    server web2 192.168.1.102:80 check
```

### Description & Use Cases
* **How it Works:** The `path_beg /api` ACL matches any incoming HTTP request whose path begins with `/api` (e.g., `http://example.com/api/v1/users`). When a match occurs, the `use_backend api_servers` directive overrides the default routing and sends the request to the dedicated API backend pool. All other requests fall back to `web_servers`.
* **Where to Use:** This is highly practical in Microservices and Single Page Application (SPA) architectures where API endpoints (`/api/*`) must be routed to high-performance API services, while standard static assets and UI files are served by standard web servers.

---

##  Host-Based Routing

Host-Based Routing distributes incoming traffic to different backends based on the HTTP `Host` header (the domain name requested by the client).

### Sample Configuration
```haproxy
frontend http_front
    bind *:80
    mode http

    # Check Host header (case-insensitive)
    acl host_app1 hdr(host) -i app1.example.com
    acl host_app2 hdr(host) -i app2.example.com

    # Route request to corresponding backend
    use_backend app1_back if host_app1
    use_backend app2_back if host_app2
    default_backend default_back

backend app1_back
    mode http
    balance roundrobin
    server app1_1 192.168.1.101:80 check
    server app1_2 192.168.1.102:80 check

backend app2_back
    mode http
    balance roundrobin
    server app2_1 192.168.2.101:80 check
    server app2_2 192.168.2.102:80 check

backend default_back
    mode http
    balance roundrobin
    server def_1 192.168.3.101:80 check
```

### Description & Use Cases
* **How it Works:** The `hdr(host)` directive extracts the value of the HTTP `Host` header sent by the browser. The `-i` flag forces case-insensitive matching against specified domain strings (`app1.example.com` or `app2.example.com`). If the domain matches one of the rules, HAProxy routes the request to its dedicated backend server pool.
* **Where to Use:** Extremely useful for hosting multiple distinct applications or multi-tenant SaaS platforms on a single public IP address (using standard HTTP/HTTPS ports 80 and 443). This eliminates the need to run separate load balancers for each sub-domain.

---

##  Sticky Sessions with Cookies

Session persistence ensures that a client is consistently routed to the same backend server that handled their initial request, preserving session state.

### Sample Configuration
```haproxy
backend web_back
    mode http
    balance roundrobin
    
    # Enable sticky sessions using a custom cookie named "SERVERID"
    cookie SERVERID insert indirect nocache
    
    # Assign a specific cookie value to each backend server
    server web01 192.168.1.101:80 check cookie web01
    server web02 192.168.1.102:80 check cookie web02
    server web03 192.168.1.103:80 check cookie web03
```

### Description & Use Cases
* **How it Works:** 
  * `cookie SERVERID` defines the name of the tracking cookie.
  * `insert` tells HAProxy to insert a `Set-Cookie` header into the server's HTTP response.
  * `indirect` prevents HAProxy from passing this cookie back to the application server itself on subsequent requests.
  * `nocache` ensures intermediate caches (like CDNs) do not cache the cookie.
  * When a user first connects, HAProxy assigns them to a backend server based on `roundrobin` and appends `Set-Cookie: SERVERID=web01`. For subsequent requests, the browser includes `Cookie: SERVERID=web01`, which instructs HAProxy to bypass load balancing and route the user directly to `web01`.
* **Where to Use:** Crucial for stateful legacy web applications where user sessions (such as active shopping carts, user login states, or multi-step wizard forms) are stored locally in the server's memory rather than in a shared database or Redis cache.

---

##  Regular Expressions (Regex) in HAProxy

HAProxy supports Regular Expressions for advanced ACL matching, path alterations, and request filtering.

### Example: Path Matching with Regex
```haproxy
frontend http_front
    bind *:80
    mode http

    acl is_admin path_reg ^/admin.*$
    use_backend admin_back if is_admin
```

### Example: Blocking Spambots via User-Agent Match
```haproxy
frontend http_front
    bind *:80
    mode http

    # Case-insensitive check if the User-Agent contains the word "bot"
    acl is_bot hdr_sub(User-Agent) -i bot
    http-request deny if is_bot
```

---

##  Manipulating HTTP Responses

Modern HAProxy versions use `http-response` syntax instead of deprecated commands like `rsprep` to alter server responses dynamically.

### Adding and Deleting Headers
```haproxy
backend http_back
    mode http
    # Append custom identification header
    http-response set-header X-Custom-Header "Powered-By-HAProxy"
    
    # Strip deprecated or sensitive backend headers
    http-response del-header X-Deprecated-Header
```

### Modifying Cookie Attributes (Replacing Domains)
To rewrite the domain of backend-generated cookies to match your public domain:
```haproxy
backend http_back
    mode http
    # Replace Domain value in Set-Cookie headers
    http-response replace-value Set-Cookie (.*)Domain=.*?;(.*) Domain=mydomain.com;
```

---

##  Monitoring & Statistics Dashboard

HAProxy contains an interactive web dashboard for real-time traffic statistics and backend monitoring.

### Dashboard Configuration
```haproxy
listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats auth admin:SecurePassword123
    stats refresh 10s
```

* Navigate to `http://<haproxy-ip>:8080/stats` and log in using `admin` / `SecurePassword123`.

---

##  Best Practices & Security Hardening

* **Use Modern TLS Settings:** Disable older protocols (TLS 1.0, 1.1) and enforce TLS 1.2 or 1.3 with secure cipher suites.
* **Keep Software Updated:** Regularly install security updates to protect against discovered CVEs.
* **Restrict Dashboard Access:** Secure the `/stats` endpoint behind strong credentials, a non-standard port, or restrict access to specific management IPs using ACLs.
* **Implement Rate Limiting:** Prevent DDoS attacks using HAProxy "stick tables" to throttle IPs making too many requests.
