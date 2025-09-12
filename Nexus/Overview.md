# Nexus Repository Manager Overview

## 1. What is Nexus Repository Manager?

Nexus Repository Manager (often called Nexus Repository OSS) is a universal artifact repository manager. It acts as a central hub for storing and managing software components ("artifacts") required for development.

### Supported Artifact Types

- **Language Packages**: npm (Node.js), Maven (Java), PyPI (Python), NuGet (.NET), RubyGems  
- **System Packages**: APT (Debian/Ubuntu), Yum/DNF (RHEL/CentOS/Rocky), Docker Images, Helm Charts  
- **Generic Files**: ZIP/TAR archives, scripts, configuration files, firmware images  

### Repository Types

- **Proxy**: Caches remote repositories (e.g., Docker Hub, Maven Central) locally  
- **Hosted**: Stores internally developed artifacts  
- **Group**: Aggregates multiple proxy and hosted repositories under a single URL  

---

## 2. Why Use It? Key Benefits

- **Single Source of Truth**: Centralized dependency management  
- **Improved Performance**: Faster builds via caching  
- **Offline Development**: Cached artifacts available without internet  
- **Security & Stability**: Prevents external disruptions  
- **CI/CD Efficiency**: Local access for build servers  

---

## 3. Features at a Glance

- **Universal Support**: 20+ package formats  
- **High Performance**: Efficient storage and caching  
- **Access Control**: Role-Based Access Control (RBAC)  
- **Extensible**: REST API and scripting  
- **Health Checks**: System and repository monitoring  

---

## 4. Benchmark vs. Alternatives

| Feature             | Nexus Repository     | JFrog Artifactory       | Apache Archiva         |
|---------------------|----------------------|--------------------------|-------------------------|
| Supported Formats   | 20+                  | 25+                      | 5+ (Limited)            |
| High Availability   | Paid                 | Paid                     | No                      |
| User Interface      | Good, intuitive      | Excellent, polished      | Basic, functional       |
| Performance         | Very Good            | Excellent                 | Good for small scale    |
| Cost                | Free (OSS) / Paid    | Paid / Free (limited)    | Free (OSS)              |
| Best For            | Mixed environments   | Enterprise-scale         | Small Java-only teams   |

**Verdict**: Nexus Repository OSS is the best free, general-purpose repository manager with broad format support.

### Extended Comparison: Nexus vs. JFrog Artifactory

#### Nexus Repository Advantages

- Free OSS version with robust features  
- More formats supported in free version  
- Easier setup and configuration  
- Strong community and documentation  
- Excellent Docker registry support  

#### JFrog Artifactory Advantages

- Advanced enterprise features  
- More polished UI/UX  
- Enhanced security scanning  
- Better CI/CD integrations  
- Superior performance at scale  

---

## 5. Core Concepts

### 5.1 Repository Types

- **Proxy**: Caches external repositories  
  - *Use Case*: Speed up `pip install` or `docker pull`  
- **Hosted**: Internal artifact storage  
  - *Use Case*: Store private Python libraries or Docker images  
- **Group**: Combines multiple repositories  
  - *Use Case*: One URL for multiple sources (e.g., `python-all`)  

### 5.2 Blob Store

- **What**: Physical storage abstraction  
- **Types**:  
  - File (default)  
  - S3/Object (Pro feature)  

### 5.3 Cleanup Policy

- **Purpose**: Auto-delete old/unused artifacts  
- **Use Case**: Remove Docker images older than 90 days  

### 5.4 Realm, User, Group, and Privileges

- **Realms**: Authentication sources (e.g., LDAP)  
- **Users & Groups**: Authenticated entities  
- **Privileges**: Specific permissions  
- **Roles**: Collections of privileges  

### 5.5 Other Components

- **Routing Rules**: Pattern-based request handling  
- **Content Selectors** *(Pro)*: Fine-grained visibility control  
- **Email**: SMTP configuration for alerts  
- **Proxy Settings**: Outbound HTTP proxy configuration  

### 5.6 Nexus REST API

- **Purpose**: Full automation  
- **Example**:  

```bash
  curl -u admin:password -X GET 'http://nexus-host:8081/service/rest/v1/repositories'
```
### 5.7 Backup and Restore

- **Backup**: Save the `sonatype-work/nexus3` directory regularly. This directory contains all configurations, databases, and blob store references.
- **Restore**: To restore, stop the Nexus service, replace the `sonatype-work/nexus3` directory with the backup, and restart Nexus.

### 5.8 High Availability and Replication (Pro)

- **High Availability (HA)**: Run multiple Nexus instances in a cluster to ensure fault tolerance and continuous availability.
- **Replication**: Automatically synchronize artifacts between Nexus instances, often across different geographic locations or data centers, to support distributed teams and disaster recovery.

---
