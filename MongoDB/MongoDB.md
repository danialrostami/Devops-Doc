# MongoDB DevOps Runbook (Integrated)

- A comprehensive, production-ready guide for deploying, configuring, managing, backing up, and restoring MongoDB instances.

**Sample values used throughout this document:**

| Placeholder | Sample Value |
|---|---|
| Server IP | `192.168.1.50` |
| Second server IP (restore target) | `192.168.1.60` |
| Port | `27017` |
| Admin user | `dbadmin` |
| Admin password | `ChangeMe_Str0ng!Pass` |
| Application user | `appuser` |
| Application password | `AppUs3r!Pass` |
| Database name | `sampledb` |
| Collection name | `orders` |
| Field 1 | `customerId` |
| Field 2 | `orderDate` |
| Index name | `idx_customerId_orderDate` |
| Backup directory | `/opt/backups/` |

---

# Part 1 — MongoDB Overview & Review

## 1.1 What is MongoDB?

MongoDB is a **NoSQL, document-oriented database** written in C++. Instead of tables and rows (RDBMS), it stores data as **BSON documents** (binary JSON) inside **collections**, allowing flexible, schema-less (or schema-flexible) data models.

## 1.2 Structure & Hierarchy

```
Deployment (mongod instance / Replica Set / Sharded Cluster)
└── Databases
    └── Collections
        └── Documents (BSON)
            └── Fields / Values
                └── Nested documents & arrays
```

Key structural components:

- **Document:** Basic unit of data; a set of key–value pairs (max 16 MB per document).
- **Collection:** Group of documents (analogous to a table, but without a fixed schema).
- **Database:** Logical container for collections.
- **Replica Set:** Group of `mongod` processes providing **high availability** — one Primary (writes) + Secondaries (replication, failover).
- **Sharding:** Horizontal scaling by distributing data across shards, with `mongos` as the query router and config servers storing cluster metadata.
- **WiredTiger Storage Engine (default):** Document-level concurrency control, compression (snappy/zlib/zstd), and checkpoints/journaling for durability.

Document example:

```json
{
  "_id": ObjectId("65f2a1b9c3d4e5f6a7b8c9d0"),
  "name": "Sample User",
  "role": "readWrite",
  "tags": ["devops", "mongodb"],
  "address": { "city": "SampleCity", "zip": "12345" }
}
```

## 1.3 Comparison: MongoDB vs RDBMS

| Concept | RDBMS (e.g., PostgreSQL) | MongoDB |
|---|---|---|
| Unit of data | Row (tuple) | Document (BSON) |
| Container | Table | Collection |
| Schema | Rigid / Fixed | Flexible / Dynamic |
| Relationships | JOINs | Embedded documents / `$lookup` |
| Scaling | Mostly vertical | Native horizontal (sharding) |
| ACID | Multi-row transactions standard | ACID on single document; multi-document transactions supported (4.0+) |
| Query language | SQL | MQL (JSON-based queries, aggregation pipeline) |
| Best for | Strictly related, normalized data | High write throughput, evolving schemas, hierarchical data |

### MongoDB vs other NoSQL databases

| Database | Type | Strength |
|---|---|---|
| **MongoDB** | Document | Rich queries, flexible schema, aggregation framework |
| Cassandra | Wide-column | Huge write scale, linear scalability |
| Redis | Key-value | In-memory, microsecond latency, caching |
| Elasticsearch | Search/JSON | Full-text search & analytics |
| HBase | Wide-column | Hadoop ecosystem, billions of rows |

## 1.4 Benefits of MongoDB

1. **Flexible schema** — documents in one collection can have different fields; schema evolution without downtime migrations.
2. **High performance** — embedded documents avoid expensive JOINs; WiredTiger caching and compression; efficient indexing.
3. **Horizontal scalability** — native auto-sharding to distribute load across commodity servers.
4. **High availability** — replica sets with automatic failover and elections.
5. **Rich query & aggregation** — indexes (single-field, compound, text, geospatial, TTL) and a powerful aggregation pipeline.
6. **Developer-friendly** — natural JSON-like mapping to application objects; drivers for all major languages.
7. **Operational tooling** — `mongodump`/`mongorestore`, monitoring, and security features (SCRAM auth, TLS, RBAC).

---

# Part 2 — Installing & Configuring MongoDB on Rocky Linux

*(Tested on Rocky Linux 8/9, MongoDB 7.0 Community Edition)*

## 2.1 Add the MongoDB Repository

Create the repository definition file (adjust `mongodb-org/7.0` if you need another version):

```bash
sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo <<'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOF
```

## 2.2 Install MongoDB

```bash
sudo dnf install -y mongodb-org
```

This installs: `mongodb-org-server` (mongod), `mongodb-org-mongos`, `mongodb-org-shell` (mongosh), `mongodb-org-tools` (mongodump, mongorestore, ...).

> **Note (if SELinux blocks mongod):** use the targeted policy package from MongoDB docs, or as a quick test: `sudo setenforce 0`. Prefer the custom policy in production.

## 2.3 Configure `mongod`

Edit `/etc/mongod.conf`:

```yaml
storage:
  dbPath: /var/lib/mongo

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1,192.168.1.50   # bind your LAN IP so remote clients can connect

security:
  authorization: enabled           # enable authentication
```

Open the firewall:

```bash
sudo firewall-cmd --permanent --add-port=27017/tcp
sudo firewall-cmd --reload
```

## 2.4 Start and Enable the Service

```bash
sudo systemctl enable --now mongod
sudo systemctl status mongod
```

## 2.5 Create the Admin User (before remote access)

```bash
mongosh
use admin
db.createUser({
  user: "dbadmin",
  pwd: passwordPrompt(),
  roles: [ { role: "root", db: "admin" } ]
})
```

Then restart and verify:

```bash
sudo systemctl restart mongod
mongosh -u dbadmin -p --host 127.0.0.1 --port 27017 --authenticationDatabase admin
```

## 2.6 Useful Post-Install Config

- **Tuning:** disable transparent huge pages (`never`), set `vm.max_map_count=128000`, ulimits for `mongod` (nofile 64000, nproc 64000).
- **Backups:** cron job running `mongodump` (see Part 5).
- **Log rotation:** add a logrotate entry for `/var/log/mongodb/mongod.log`, plus `systemLog.logRotate: reopen` and a `logRotate` signal in `mongod.conf`.

---

# Part 3 — Installing MongoDB with Docker Compose (Host-Mounted Volume)

## 3.1 Project Layout

```
/opt/mongodb/
├── docker-compose.yml
├── init/                      # (optional) .js init scripts, run once
└── data/                      # HOST-MOUNTED VOLUME for DB files
    ├── db/                    # -> /data/db       (mongod data files)
    └── configdb/              # -> /data/configdb (config server files)
```

```bash
sudo mkdir -p /opt/mongodb/data/db /opt/mongodb/data/configdb
cd /opt/mongodb
```

Set correct ownership (UID 999 = `mongodb` user inside the official image):

```bash
sudo chown -R 999:999 /opt/mongodb/data
```

## 3.2 `docker-compose.yml` with Host Volume

```yaml
version: "3.8"

services:
  mongodb:
    image: mongo:7.0
    container_name: mongodb
    restart: unless-stopped
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: dbadmin
      MONGO_INITDB_ROOT_PASSWORD: ChangeMe_Str0ng!Pass
    volumes:
      # HOST-MOUNTED VOLUMES (bind mounts) — data persists on the host
      - /opt/mongodb/data/db:/data/db
      - /opt/mongodb/data/configdb:/data/configdb
      # (optional) auto-run .js init scripts on first start
      # - ./init:/docker-entrypoint-initdb.d:ro
    command:
      - mongod
      - --auth
      - --bind_ip_all
    healthcheck:
      test: ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
```

Key points:

- **Bind mounts** (`/opt/mongodb/data/db:/data/db`) store all database files directly on the host — data survives container recreation, upgrades, and `docker compose down`.
- `MONGO_INITDB_ROOT_*` creates the root user **only on the first start with an empty data directory**.
- `--bind_ip_all` + published port exposes MongoDB on the host — protect it with `authorization: enabled` (default when root user is set) and a firewall rule limiting the source IPs.

## 3.3 Start, Verify, and Operate

```bash
cd /opt/mongodb
docker compose up -d
docker compose ps
docker logs -f mongodb

# enter the shell
docker exec -it mongodb mongosh -u dbadmin -p
show dbs
```

---

# Part 4 — Operational Guide & Commands

## 4.1 Connecting to MongoDB

**Interactive login (password prompted):**

```bash
mongosh -u dbadmin -p --host 192.168.1.50 --port 27017
```

**Login as the application user to the `sampledb` database:**

```bash
mongosh -u appuser -p --host 192.168.1.50 --port 27017 --authenticationDatabase sampledb
```

**Full explicit login with authentication mechanism:**

```bash
mongosh --host=192.168.1.50 --port=27017 \
  --username=appuser --password='AppUs3r!Pass' \
  --authenticationDatabase=sampledb \
  --authenticationMechanism=SCRAM-SHA-256 \
  sampledb
```

## 4.2 Basic Shell Commands

```javascript
show dbs;            // List all databases

use sampledb;        // Switch to the "sampledb" database

help                 // Show shell help

show collections     // List all collections in the current database
```

## 4.3 Database & Collection Statistics

**Show all databases (size overview):**

```javascript
show dbs
```

**Stats for a specific collection (sizes in GB):**

```javascript
db.orders.stats(1024*1024*1024)
```

**Plain stats:**

```javascript
db.orders.stats()
```

### Key Metrics

| Metric | Meaning |
|---|---|
| `count` | Number of documents in the collection |
| `size` | Raw uncompressed data size (in memory / WiredTiger) |
| `storageSize` | Actual space occupied on disk (compressed data) |
| `nindexes` | Number of indexes on the collection |

### Example `stats()` output (sample data)

```json
{
  "ns": "sampledb.orders",
  "size": 314887163344,
  "count": 11958891,
  "avgObjSize": 26330,
  "storageSize": 63749804032,
  "freeStorageSize": 581095424,
  "capped": false,
  "wiredTiger": { "metadata": { "formatVersion": 1 } }
}
```

> **Estimating dump size:** `size` is in bytes. In the sample above, `314,887,163,344` bytes ≈ **293 GB**, so you need **at least ~300 GB** of free disk space on the machine where you run the dump.

## 4.4 Indexing Strategy

**List current indexes:**

```javascript
db.orders.getIndexes()
```

**Creating a compound index:**

```javascript
db.orders.createIndex(
  { "customerId": 1, "orderDate": -1 },
  { name: "idx_customerId_orderDate" }
)
```

### Considerations Before Creating Indexes

- **Disk space:** Building a new index requires temporary space for sorting, in addition to the final index file. Make sure the database drive has enough free space — **at least 20–30% of the collection's `storageSize`** must be free on the database partition.
- **RAM / index size:** Ideally, all indexes should fit in RAM to keep read/write performance high. If the total `totalIndexSize` after building new indexes exceeds the WiredTiger cache size (usually **50% of the server's RAM**), the database will suffer from **Disk Thrashing** (severe performance degradation).

## 4.5 User Management

**List users defined in a specific database (with roles):**

```javascript
use sampledb
db.getUsers()
```

**List all users (across all databases):**

```javascript
use admin
db.system.users.find()
```

**Create a user for the `sampledb` database:**

```javascript
db.createUser({
  user: "appuser",
  pwd: "AppUs3r!Pass",
  roles: [{ role: "readWrite", db: "sampledb" }]
})
```

**Reset a user's password:**

1. Login as `dbadmin`
2. Switch to the target DB: `use sampledb`
3. List users to identify the target: `db.getUsers()`
4. Change the password:
   ```javascript
   db.changeUserPassword("appuser", "NewS3cure!Pass")
   ```

---

# Part 5 — Backup & Restore

## 5.1 Dump (mongodump)

```bash
mongodump --host=192.168.1.50 --port=27017 \
          --db=sampledb --collection=orders \
          --username=appuser --password='AppUs3r!Pass' \
          --authenticationDatabase=sampledb \
          --authenticationMechanism=SCRAM-SHA-256 \
          --out=/opt/backups/
```

Then copy the dump to the destination MongoDB server, e.g.:

```bash
scp -r /opt/backups/sampledb user@192.168.1.60:/opt/backups/
```

## 5.2 Restore (mongorestore)

> ⚠️ **WARNING:** `--drop` **removes the existing target collection completely** before restoring. Use with extreme care.

```bash
mongorestore --host=192.168.1.60 --port=27017 \
             --username=appuser --password='AppUs3r!Pass' \
             --authenticationDatabase=sampledb \
             --authenticationMechanism=SCRAM-SHA-256 \
             --drop \
             --nsInclude="sampledb.orders" \
             /opt/backups/
```

## 5.3 Backup & Restore of the Dockerized Instance

```bash
# Dump to a directory inside the container
docker exec mongodb mongodump \
  -u dbadmin -p"ChangeMe_Str0ng!Pass" --authenticationDatabase admin \
  --db sampledb --out /backup

# If /backup is not a mount, copy it out of the container:
docker cp mongodb:/backup /opt/mongodb/backup

# Restore
docker exec -it mongodb mongorestore \
  -u dbadmin -p"ChangeMe_Str0ng!Pass" --authenticationDatabase admin --drop \
  /backup/sampledb
```

---
