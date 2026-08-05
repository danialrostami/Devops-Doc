# Comprehensive Ansible Guide - Practical Structured Edition

 A practical  Ansible document with a clean learning structure: concepts, architecture, configuration, inventory, playbooks, roles, safe execution, troubleshooting, production practices, and a complete Rocky Linux 9 Nginx role review.

## Table of Contents

- [1. Ansible Concept and Overview](#1-ansible-concept-and-overview)
- [2. Architecture and How Ansible Works](#2-architecture-and-how-ansible-works)
- [3. Ansible Configuration](#3-ansible-configuration)
- [4. SSH Connectivity and Privilege Escalation](#4-ssh-connectivity-and-privilege-escalation)
- [5. Recommended Project Layout](#5-recommended-project-layout)
- [6. Inventory, Hosts, Groups, `host_vars`, and `group_vars`](#6-inventory-hosts-groups-hostvars-and-groupvars)
- [7. Dynamic Inventory Overview](#7-dynamic-inventory-overview)
- [8. Playbooks and Playbook Components](#8-playbooks-and-playbook-components)
- [9. Execution Strategies, Rolling Updates, and Limits](#9-execution-strategies-rolling-updates-and-limits)
- [10. Check Mode, Diff Mode, and Safe Execution](#10-check-mode-diff-mode-and-safe-execution)
- [11. Roles and Role Components](#11-roles-and-role-components)
- [12. Collections and Requirements Management](#12-collections-and-requirements-management)
- [13. Ad-Hoc Commands](#13-ad-hoc-commands)
- [14. Ansible Vault](#14-ansible-vault)
- [15. Testing, Linting, and Validation](#15-testing-linting-and-validation)
- [16. Troubleshooting Guide](#16-troubleshooting-guide)
- [17. Production Best Practices Checklist](#17-production-best-practices-checklist)
- [18. Practical Review Role: Nginx on Rocky Linux 9](#18-practical-review-role-nginx-on-rocky-linux-9)
- [19. Useful Commands](#19-useful-commands)
- [20. Final Notes](#20-final-notes)

## How to Use This Document

This document is structured as a practical learning path:

```text
Concepts -> Architecture -> Configuration -> Inventory -> Playbooks -> Roles -> Advanced/Safe Execution -> Practice Role
```

Recommended reading order:

1. Understand what Ansible is and how it works.
2. Learn inventory, hosts, groups, and variables.
3. Learn playbook anatomy and task control.
4. Learn roles for reusable automation.
5. Learn safe execution, testing, troubleshooting, and production practices.
6. Review everything through the complete Rocky Linux 9 Nginx role.

## 1. Ansible Concept and Overview

**Ansible** is an open-source automation tool used for:

- Configuration management
- Application deployment
- Server provisioning
- Orchestration
- Infrastructure automation
- Day-2 operations

Ansible is usually executed from a **control node** and manages remote machines called **managed nodes**.

### Key Characteristics

| Feature | Description |
|---|---|
| Agentless | No agent is required on managed nodes. Ansible mainly uses SSH for Linux/Unix systems. |
| Declarative | You describe the desired state, and Ansible applies it. |
| Idempotent | Running the same playbook multiple times should not cause unwanted repeated changes. |
| YAML-based | Automation is written mostly in YAML. |
| Modular | Uses modules like `dnf`, `copy`, `template`, `service`, `user`, `file`, etc. |
| Extensible | Supports custom modules, plugins, roles, and collections. |

### Common Use Cases

- Install packages
- Configure services
- Manage users and SSH keys
- Configure firewalls
- Deploy applications
- Manage Kubernetes nodes
- Configure load balancers
- Automate Linux hardening
- Run operational commands across many servers

---

## 2. Architecture and How Ansible Works

Ansible uses a simple architecture:

- **Control Node**: The machine where Ansible is installed and executed.
- **Inventory**: List of managed hosts and groups.
- **Playbooks**: YAML files describing what should be done.
- **Modules**: Small units of work executed on managed nodes.
- **Plugins**: Extend Ansible behavior.
- **Collections**: Packaged content including modules, roles, and plugins.
- **Managed Nodes**: Target servers controlled by Ansible.

### GitHub-Friendly Architecture Map

```text
+------------------------------------------------------------+
|                        Control Node                         |
|                                                            |
|  ansible / ansible-playbook                                 |
|        |                                                   |
|        | reads                                             |
|        v                                                   |
|  +-------------+      +-------------+      +-------------+  |
|  | Inventory   |      | Playbooks   |      | Roles       |  |
|  | hosts.ini   |      | site.yml    |      | nginx/      |  |
|  +-------------+      +-------------+      +-------------+  |
|        |                    |                    |          |
|        +--------------------+--------------------+          |
|                             |                               |
|                             v                               |
|                    SSH / WinRM connection                   |
+-----------------------------|------------------------------+
                              |
              +---------------+---------------+
              |               |               |
              v               v               v
       +-------------+ +-------------+ +-------------+
       | Managed     | | Managed     | | Managed     |
       | Node 1      | | Node 2      | | Node 3      |
       | Rocky 9     | | Ubuntu      | | RHEL        |
       +-------------+ +-------------+ +-------------+
```

### Execution Flow

```text
1. User runs ansible-playbook
2. Ansible reads configuration and inventory
3. Ansible parses playbook and variables
4. Ansible connects to target hosts, usually by SSH
5. Ansible transfers required module code to remote host
6. Remote host executes module
7. Module returns JSON result
8. Ansible displays changed/ok/failed/skipped result
```

---

---

## 3. Ansible Configuration

Ansible behavior is controlled by configuration files. The most common file is `ansible.cfg`.

### Configuration File Search Order

Ansible searches for configuration in this order:

```text
1. ANSIBLE_CONFIG environment variable
2. ./ansible.cfg in current directory
3. ~/.ansible.cfg
4. /etc/ansible/ansible.cfg
```

Check active configuration:

```bash
ansible --version
ansible-config dump --only-changed
ansible-config view
```

### Practical `ansible.cfg` for Git Projects

```ini
[defaults]
inventory = inventories/lab/hosts.ini
roles_path = roles
collections_path = collections
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
bin_ansible_callbacks = True
interpreter_python = auto_silent
forks = 20
timeout = 30
remote_tmp = /tmp/.ansible-${USER}/tmp
local_tmp = /tmp/.ansible-${USER}/tmp

# Useful for readable output
callbacks_enabled = timer, profile_tasks

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
control_path = %(directory)s/%%h-%%p-%%r

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

### Notes About Proxies

If your control node or managed nodes are behind HTTP/HTTPS proxies, define proxy variables where needed.

Example in `group_vars/all.yml`:

```yaml
proxy_env:
  http_proxy: "http://proxy.example.local:8080"
  https_proxy: "http://proxy.example.local:8080"
  no_proxy: "localhost,127.0.0.1,.example.local"
```

Use it in tasks:

```yaml
- name: Download file through proxy
  ansible.builtin.get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
  environment: "{{ proxy_env }}"
```

For package managers such as `dnf`, you may also need OS-level proxy config:

```ini
# /etc/dnf/dnf.conf
proxy=http://proxy.example.local:8080
```

---

---

## 4. SSH Connectivity and Privilege Escalation

Most Linux automation needs privileged access. Ansible uses `become` for privilege escalation.

### Play-Level Become

```yaml
---
- name: Configure servers
  hosts: all
  become: true
  tasks:
    - name: Install package
      ansible.builtin.dnf:
        name: vim
        state: present
```

### Task-Level Become

```yaml
- name: Read normal user file without sudo
  ansible.builtin.command: whoami
  become: false
```

### Inventory SSH Variables

```ini
[all:vars]
ansible_user=ansible
ansible_port=22
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_become=true
ansible_become_method=sudo
ansible_become_user=root
```

### Sudoers Example for Automation User

Create `/etc/sudoers.d/ansible`:

```sudoers
ansible ALL=(ALL) NOPASSWD: ALL
```

Recommended permission:

```bash
chmod 440 /etc/sudoers.d/ansible
visudo -cf /etc/sudoers.d/ansible
```

### SSH Key Best Practices

- Use SSH keys, not passwords.
- Protect private keys with strict permissions.
- Use a dedicated automation user.
- Avoid using `root` directly when possible.
- In production, keep `host_key_checking=True` and manage known hosts.

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

---

---

## 5. Recommended Project Layout

A clean project layout helps maintainability and scalability.

```text
ansible-project/
├── ansible.cfg
├── inventories/
│   ├── dev/
│   │   ├── hosts.ini
│   │   ├── group_vars/
│   │   │   ├── all.yml
│   │   │   └── webservers.yml
│   │   └── host_vars/
│   │       └── web01.yml
│   ├── prod/
│   │   ├── hosts.ini
│   │   ├── group_vars/
│   │   │   ├── all.yml
│   │   │   └── webservers.yml
│   │   └── host_vars/
│   │       └── web01.yml
├── playbooks/
│   ├── site.yml
│   └── nginx.yml
├── roles/
│   └── nginx/
│       ├── defaults/
│       │   └── main.yml
│       ├── vars/
│       │   └── main.yml
│       ├── tasks/
│       │   └── main.yml
│       ├── handlers/
│       │   └── main.yml
│       ├── templates/
│       │   └── nginx.conf.j2
│       ├── files/
│       ├── meta/
│       │   └── main.yml
│       └── README.md
├── collections/
│   └── requirements.yml
└── README.md
```

### Example `ansible.cfg`

```ini
[defaults]
inventory = inventories/dev/hosts.ini
roles_path = roles
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
interpreter_python = auto_silent

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

> Note: Disabling `host_key_checking` is convenient in labs, but in production you should manage SSH host keys properly.

---

---

## 6. Inventory, Hosts, Groups, `host_vars`, and `group_vars`

An inventory defines managed hosts and groups.

### INI Inventory Example

```ini
[webservers]
web01 ansible_host=192.168.56.11
web02 ansible_host=192.168.56.12

[dbservers]
db01 ansible_host=192.168.56.21

[rocky9:children]
webservers
dbservers

[all:vars]
ansible_user=ansible
ansible_port=22
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### YAML Inventory Example

```yaml
all:
  vars:
    ansible_user: ansible
    ansible_port: 22
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
  children:
    webservers:
      hosts:
        web01:
          ansible_host: 192.168.56.11
        web02:
          ansible_host: 192.168.56.12
    dbservers:
      hosts:
        db01:
          ansible_host: 192.168.56.21
```

### `group_vars`

Variables assigned to a group.

```text
inventories/dev/group_vars/webservers.yml
```

```yaml
nginx_worker_processes: auto
nginx_listen_port: 80
nginx_server_name: example.local
```

### `host_vars`

Variables assigned to a specific host.

```text
inventories/dev/host_vars/web01.yml
```

```yaml
nginx_server_name: web01.example.local
custom_motd: "Managed by Ansible"
```

### Variable Precedence Reminder

Ansible has many precedence levels. In simple terms:

```text
role defaults < inventory group_vars < inventory host_vars < play vars < task vars < extra vars
```

`--extra-vars` has very high precedence.

---

---

## 7. Dynamic Inventory Overview

Static inventories are simple, but dynamic environments often need dynamic inventory.

Examples:

- Cloud instances
- VMware inventory
- Kubernetes nodes
- CMDB-backed inventory
- Custom API inventory

### Dynamic Inventory Command

```bash
ansible-inventory -i inventory_script.py --list
```

### Minimal Dynamic Inventory JSON

```json
{
  "webservers": {
    "hosts": ["web01", "web02"],
    "vars": {
      "ansible_user": "ansible"
    }
  },
  "_meta": {
    "hostvars": {
      "web01": {
        "ansible_host": "192.168.56.11"
      },
      "web02": {
        "ansible_host": "192.168.56.12"
      }
    }
  }
}
```

### Inventory Plugin Example Pattern

For cloud or virtualization platforms, prefer inventory plugins over custom scripts when possible.

```yaml
plugin: some.collection.inventory_plugin
strict: false
compose:
  ansible_host: private_ip_address
keyed_groups:
  - key: tags.Environment
    prefix: env
```

---

---

## 8. Playbooks and Playbook Components

A playbook is a YAML file containing one or more **plays**. Each play maps hosts to tasks.

---

### 8.1 Playbook Structure

```yaml
---
- name: Configure web servers
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    package_name: nginx

  tasks:
    - name: Install package
      ansible.builtin.dnf:
        name: "{{ package_name }}"
        state: present
```

Main parts:

| Part | Description |
|---|---|
| `name` | Human-readable play name |
| `hosts` | Target hosts or groups |
| `become` | Enable privilege escalation |
| `gather_facts` | Collect system facts |
| `vars` | Variables defined inside play |
| `tasks` | Ordered list of actions |
| `handlers` | Triggered actions, usually service restart |
| `roles` | Roles applied to hosts |

---

### 8.2 Facts

Facts are system information collected from managed nodes.

```yaml
- name: Show OS family
  ansible.builtin.debug:
    msg: "OS family is {{ ansible_facts['os_family'] }}"
```

Common facts:

```yaml
ansible_facts['hostname']
ansible_facts['fqdn']
ansible_facts['distribution']
ansible_facts['distribution_major_version']
ansible_facts['default_ipv4']['address']
ansible_facts['memtotal_mb']
ansible_facts['processor_vcpus']
```

Disable fact gathering when not needed:

```yaml
gather_facts: false
```

Gather facts manually:

```yaml
- name: Gather facts manually
  ansible.builtin.setup:
```

---

### 8.3 Variables

Variables allow reusable and dynamic playbooks.

```yaml
vars:
  app_name: nginx
  app_port: 80
```

Usage:

```yaml
- name: Print variable
  ansible.builtin.debug:
    msg: "Application {{ app_name }} listens on port {{ app_port }}"
```

Variables can be defined in:

- Playbooks
- Inventory
- `group_vars`
- `host_vars`
- Role defaults
- Role vars
- Extra vars
- Registered task output
- Facts

Pass extra vars:

```bash
ansible-playbook playbooks/site.yml -e "app_port=8080"
```

---

### 8.4 Tasks

A task calls an Ansible module.

```yaml
- name: Ensure Nginx is installed
  ansible.builtin.dnf:
    name: nginx
    state: present
```

Task result states:

| State | Meaning |
|---|---|
| `ok` | No change was required |
| `changed` | Task changed remote system |
| `failed` | Task failed |
| `skipped` | Task was skipped because condition was false |

---

### 8.5 Outline Procedure

Typical automation procedure:

```text
1. Validate OS/version
2. Install required packages
3. Create users/directories
4. Render configuration files
5. Validate configuration
6. Enable and restart service
7. Verify service state
```

Example:

```yaml
- name: Configure application
  hosts: appservers
  become: true

  tasks:
    - name: Install package
      ansible.builtin.dnf:
        name: myapp
        state: present

    - name: Deploy config
      ansible.builtin.template:
        src: myapp.conf.j2
        dest: /etc/myapp/myapp.conf
      notify: Restart myapp

    - name: Ensure service is running
      ansible.builtin.service:
        name: myapp
        state: started
        enabled: true

  handlers:
    - name: Restart myapp
      ansible.builtin.service:
        name: myapp
        state: restarted
```

---

### 8.6 `register` and `when`

`register` saves task output into a variable.

```yaml
- name: Check Nginx version
  ansible.builtin.command: nginx -v
  register: nginx_version
  changed_when: false

- name: Show Nginx version command result
  ansible.builtin.debug:
    var: nginx_version.stderr
```

Use with `when`:

```yaml
- name: Run only if command succeeded
  ansible.builtin.debug:
    msg: "Nginx command worked"
  when: nginx_version.rc == 0
```

---

### 8.7 Conditionals

Run tasks only when conditions match.

```yaml
- name: Install packages on RedHat family
  ansible.builtin.dnf:
    name: nginx
    state: present
  when: ansible_facts['os_family'] == "RedHat"
```

Multiple conditions:

```yaml
when:
  - ansible_facts['distribution'] == "Rocky"
  - ansible_facts['distribution_major_version'] == "9"
```

Boolean variable:

```yaml
- name: Enable firewall rule
  ansible.posix.firewalld:
    service: http
    permanent: true
    immediate: true
    state: enabled
  when: nginx_manage_firewall | bool
```

---

### 8.8 `until`, `retries`, and `delay`

Useful for retrying commands until a condition becomes true.

```yaml
- name: Wait until HTTP endpoint is available
  ansible.builtin.uri:
    url: "http://{{ inventory_hostname }}"
    status_code: 200
  register: http_check
  until: http_check.status == 200
  retries: 10
  delay: 3
```

---

### 8.9 `import` and `include`

Ansible has static imports and dynamic includes.

### Static Import

Parsed before execution.

```yaml
- name: Import tasks statically
  ansible.builtin.import_tasks: install.yml
```

### Dynamic Include

Evaluated during execution.

```yaml
- name: Include tasks dynamically
  ansible.builtin.include_tasks: "{{ ansible_facts['os_family'] }}.yml"
```

### Common Rules

| Feature | Static `import_*` | Dynamic `include_*` |
|---|---|---|
| Parsed | Before execution | During execution |
| Supports dynamic filenames | Limited | Yes |
| Better for predictable flow | Yes | Sometimes |
| Better for conditions/loops | Sometimes | Yes |

---

### 8.10 Start at Specific Task

You can start playbook execution from a specific task name:

```bash
ansible-playbook playbooks/site.yml --start-at-task "Deploy Nginx configuration"
```

Useful during debugging.

> Task name must match exactly.

---

### 8.11 Jinja2 Templates

Jinja2 templates allow dynamic config generation.

Example template:

```jinja2
server {
    listen {{ nginx_listen_port }};
    server_name {{ nginx_server_name }};

    location / {
        root {{ nginx_web_root }};
        index index.html;
    }
}
```

Deploy template:

```yaml
- name: Deploy Nginx config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
  notify: Restart nginx
```

Useful Jinja2 filters:

```jinja2
{{ variable | default('value') }}
{{ list_variable | join(',') }}
{{ string_variable | lower }}
{{ bool_variable | bool }}
{{ dict_variable | to_nice_yaml }}
```

---

### 8.12 Lists

Define a list:

```yaml
packages:
  - nginx
  - curl
  - vim
```

Use list in loop:

```yaml
- name: Install packages
  ansible.builtin.dnf:
    name: "{{ item }}"
    state: present
  loop: "{{ packages }}"
```

Better package installation:

```yaml
- name: Install packages at once
  ansible.builtin.dnf:
    name: "{{ packages }}"
    state: present
```

---

### 8.13 Blocks, Rescue, and Always

Use `block`, `rescue`, and `always` for structured error handling.

```yaml
- name: Example block with rescue
  block:
    - name: Run risky command
      ansible.builtin.command: /usr/bin/some-command

  rescue:
    - name: Handle failure
      ansible.builtin.debug:
        msg: "The risky command failed. Running fallback."

  always:
    - name: Always run cleanup
      ansible.builtin.debug:
        msg: "Cleanup or final reporting"
```

---

### 8.14 Loops

Simple loop:

```yaml
- name: Create users
  ansible.builtin.user:
    name: "{{ item }}"
    state: present
  loop:
    - devops
    - monitoring
    - backup
```

Loop over dictionaries:

```yaml
- name: Create application directories
  ansible.builtin.file:
    path: "{{ item.path }}"
    owner: "{{ item.owner }}"
    group: "{{ item.group }}"
    mode: "{{ item.mode }}"
    state: directory
  loop:
    - { path: /opt/app, owner: app, group: app, mode: '0755' }
    - { path: /var/log/app, owner: app, group: app, mode: '0750' }
```

---

### 8.15 Practical Modules

Commonly used modules:

| Module | Usage |
|---|---|
| `ansible.builtin.ping` | Test connectivity |
| `ansible.builtin.command` | Run command without shell features |
| `ansible.builtin.shell` | Run command with shell features |
| `ansible.builtin.copy` | Copy static files |
| `ansible.builtin.template` | Render Jinja2 templates |
| `ansible.builtin.file` | Manage files/directories/symlinks |
| `ansible.builtin.lineinfile` | Manage a single line in a file |
| `ansible.builtin.blockinfile` | Manage a block of text in a file |
| `ansible.builtin.dnf` | Manage packages on RHEL/Rocky/Fedora |
| `ansible.builtin.apt` | Manage packages on Debian/Ubuntu |
| `ansible.builtin.service` | Manage services |
| `ansible.builtin.systemd_service` | Manage systemd services |
| `ansible.builtin.user` | Manage users |
| `ansible.builtin.group` | Manage groups |
| `ansible.builtin.uri` | HTTP/API calls |
| `ansible.builtin.get_url` | Download files |
| `ansible.builtin.unarchive` | Extract archives |
| `ansible.posix.firewalld` | Manage firewalld |

---

### 8.16 Tags

Tags allow running selected parts of a playbook.

```yaml
- name: Install Nginx
  ansible.builtin.dnf:
    name: nginx
    state: present
  tags:
    - install
    - nginx
```

Run only specific tags:

```bash
ansible-playbook playbooks/nginx.yml --tags install
```

Skip tags:

```bash
ansible-playbook playbooks/nginx.yml --skip-tags firewall
```

---

### 8.17 Delegation, `run_once`, `when`, and `register`

### Delegate Task to Another Host

```yaml
- name: Run task on localhost instead of target host
  ansible.builtin.debug:
    msg: "This runs on control node"
  delegate_to: localhost
```

### Run Once

```yaml
- name: Generate cluster token once
  ansible.builtin.command: /usr/local/bin/generate-token
  register: cluster_token
  run_once: true
```

### Combine `run_once`, `delegate_to`, and `register`

```yaml
- name: Query API once from control node
  ansible.builtin.uri:
    url: https://api.example.local/status
    method: GET
    return_content: true
  register: api_status
  run_once: true
  delegate_to: localhost
```

### Conditional Delegated Task

```yaml
- name: Restart load balancer only from first web server
  ansible.builtin.command: systemctl reload haproxy
  delegate_to: lb01
  run_once: true
  when: inventory_hostname in groups['webservers']
```

---

### 8.18 Error Handling

Ignore errors:

```yaml
- name: Run command and ignore failure
  ansible.builtin.command: /bin/false
  ignore_errors: true
```

Define failure condition:

```yaml
- name: Check application status
  ansible.builtin.command: systemctl is-active myapp
  register: app_status
  changed_when: false
  failed_when: app_status.rc not in [0, 3]
```

Define changed condition:

```yaml
- name: Run check command without reporting changed
  ansible.builtin.command: nginx -t
  register: nginx_test
  changed_when: false
```

Force handlers even after failure:

```yaml
- name: Example play
  hosts: webservers
  force_handlers: true
```

Abort play after failure percentage:

```yaml
- name: Rolling update
  hosts: webservers
  max_fail_percentage: 20
```

Limit parallel hosts:

```yaml
- name: Rolling deployment
  hosts: webservers
  serial: 2
```

---

---

## 9. Execution Strategies, Rolling Updates, and Limits

Ansible can control how tasks are executed across hosts.

### Forks

`forks` controls parallelism.

```ini
[defaults]
forks = 20
```

CLI override:

```bash
ansible-playbook playbooks/site.yml -f 30
```

### Serial Rolling Update

Useful for web servers behind a load balancer.

```yaml
---
- name: Rolling update web servers
  hosts: webservers
  become: true
  serial: 2

  tasks:
    - name: Update application
      ansible.builtin.debug:
        msg: "Updating {{ inventory_hostname }}"
```

### Percentage Serial

```yaml
serial: "25%"
```

### Limit Hosts

```bash
ansible-playbook playbooks/site.yml --limit web01
ansible-playbook playbooks/site.yml --limit 'webservers:&prod'
ansible-playbook playbooks/site.yml --limit 'webservers:!web02'
```

### Strategies

Default strategy is `linear`, meaning all hosts complete a task before moving to the next task.

```yaml
strategy: linear
```

Free strategy lets each host run as fast as possible:

```yaml
strategy: free
```

### Maximum Failure Control

```yaml
max_fail_percentage: 20
any_errors_fatal: true
```

---

---

## 10. Check Mode, Diff Mode, and Safe Execution

Before running changes in production, use safe execution methods.

### Syntax Check

```bash
ansible-playbook playbooks/site.yml --syntax-check
```

### Check Mode

```bash
ansible-playbook playbooks/site.yml --check
```

### Diff Mode

```bash
ansible-playbook playbooks/site.yml --diff
```

### Check and Diff Together

```bash
ansible-playbook playbooks/site.yml --check --diff
```

### Task-Level Check Mode Control

Force a task to run even in check mode:

```yaml
- name: Always run validation command
  ansible.builtin.command: nginx -t
  check_mode: false
  changed_when: false
```

Skip a task in check mode:

```yaml
- name: Restart service only in real run
  ansible.builtin.service:
    name: nginx
    state: restarted
  when: not ansible_check_mode
```

### Diff for Templates

```yaml
- name: Deploy config with diff support
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
  diff: true
```

---

---

## 11. Roles and Role Components

Roles organize reusable automation.

Create a role:

```bash
ansible-galaxy role init roles/nginx
```

Role structure:

```text
roles/nginx/
├── defaults/
│   └── main.yml
├── vars/
│   └── main.yml
├── tasks/
│   └── main.yml
├── handlers/
│   └── main.yml
├── templates/
│   └── nginx.conf.j2
├── files/
├── meta/
│   └── main.yml
└── README.md
```

| Directory | Purpose |
|---|---|
| `defaults/` | Default variables, low precedence |
| `vars/` | Role variables, higher precedence |
| `tasks/` | Main automation tasks |
| `handlers/` | Handlers triggered by notify |
| `templates/` | Jinja2 templates |
| `files/` | Static files copied without templating |
| `meta/` | Role metadata and dependencies |
| `README.md` | Role documentation |

Use role in playbook:

```yaml
---
- name: Configure Nginx servers
  hosts: webservers
  become: true
  roles:
    - nginx
```

---

---

## 12. Collections and Requirements Management

Collections package Ansible content such as modules, plugins, and roles.

### Install a Collection

```bash
ansible-galaxy collection install ansible.posix
```

### `collections/requirements.yml`

```yaml
---
collections:
  - name: ansible.posix
    version: ">=1.5.0"
  - name: community.general
    version: ">=8.0.0"
```

Install requirements:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

### Role Requirements

`roles/requirements.yml`:

```yaml
---
roles:
  - name: geerlingguy.nginx
    version: 3.2.0
```

Install roles:

```bash
ansible-galaxy role install -r roles/requirements.yml -p roles/
```

### Use Fully Qualified Collection Names

Recommended:

```yaml
ansible.builtin.copy
ansible.builtin.template
ansible.posix.firewalld
community.general.seport
```

This improves readability and avoids module name conflicts.

---

---

## 13. Ad-Hoc Commands

Ad-hoc commands are quick one-time commands.

### Ping Hosts

```bash
ansible all -m ansible.builtin.ping
```

### Check Uptime

```bash
ansible all -m ansible.builtin.command -a "uptime"
```

### Install Package

```bash
ansible webservers -b -m ansible.builtin.dnf -a "name=nginx state=present"
```

### Restart Service

```bash
ansible webservers -b -m ansible.builtin.service -a "name=nginx state=restarted"
```

### Copy File

```bash
ansible webservers -b -m ansible.builtin.copy -a "src=./index.html dest=/usr/share/nginx/html/index.html mode=0644"
```

### Gather Facts

```bash
ansible webservers -m ansible.builtin.setup
```

Limit facts:

```bash
ansible webservers -m ansible.builtin.setup -a "filter=ansible_distribution*"
```

---

---

## 14. Ansible Vault

Ansible Vault encrypts sensitive data such as passwords, tokens, and private variables.

### Create Encrypted File

```bash
ansible-vault create inventories/prod/group_vars/all/vault.yml
```

### Edit Encrypted File

```bash
ansible-vault edit inventories/prod/group_vars/all/vault.yml
```

### Encrypt Existing File

```bash
ansible-vault encrypt secrets.yml
```

### Decrypt File

```bash
ansible-vault decrypt secrets.yml
```

### View Encrypted File

```bash
ansible-vault view secrets.yml
```

### Run Playbook with Vault Prompt

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

### Run with Vault Password File

```bash
ansible-playbook playbooks/site.yml --vault-password-file ~/.vault_pass.txt
```

> Protect the vault password file with strict permissions:

```bash
chmod 600 ~/.vault_pass.txt
```

### Example Vault Variable

Encrypted file:

```yaml
vault_db_password: "SuperSecretPassword"
```

Normal variable file:

```yaml
db_password: "{{ vault_db_password }}"
```

---

---

## 15. Testing, Linting, and Validation

For production repositories, add linting and testing.

### Install Tools

```bash
python3 -m pip install ansible ansible-lint yamllint
```

### `yamllint`

```bash
yamllint .
```

Example `.yamllint`:

```yaml
---
extends: default

rules:
  line-length:
    max: 140
    level: warning
  truthy:
    allowed-values: ['true', 'false']
```

### `ansible-lint`

```bash
ansible-lint
ansible-lint playbooks/nginx.yml
```

Example `.ansible-lint`:

```yaml
---
profile: production
exclude_paths:
  - .cache/
  - collections/
  - roles/external/
```

### Template Validation

For services like Nginx, always validate config before replacing active config.

```yaml
- name: Deploy Nginx config safely
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    validate: 'nginx -t -c %s'
  notify: Restart nginx
```

### Molecule Overview

Molecule is commonly used for role testing.

```bash
python3 -m pip install molecule molecule-plugins[docker]
molecule init scenario
molecule test
```

Basic lifecycle:

```text
create -> converge -> idempotence -> verify -> destroy
```

---

---

## 16. Troubleshooting Guide

### Increase Verbosity

```bash
ansible-playbook playbooks/site.yml -v
ansible-playbook playbooks/site.yml -vv
ansible-playbook playbooks/site.yml -vvv
ansible-playbook playbooks/site.yml -vvvv
```

### Test SSH Connectivity

```bash
ssh ansible@192.168.56.11
ansible web01 -m ping -vvvv
```

### Common Errors

| Error | Possible Cause | Fix |
|---|---|---|
| `UNREACHABLE` | SSH/network problem | Check IP, port, firewall, SSH key, user |
| `Permission denied` | Wrong SSH key/user | Validate inventory SSH variables |
| `Missing sudo password` | Sudo requires password | Configure NOPASSWD or use `--ask-become-pass` |
| `MODULE FAILURE` | Python issue on remote | Install Python or set `ansible_python_interpreter` |
| `template error` | Jinja variable/filter issue | Check variable names and defaults |
| `No package matching` | Repo issue | Check repositories, proxy, package name |

### Python Interpreter Issues

Set interpreter in inventory:

```ini
[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

Or in `ansible.cfg`:

```ini
interpreter_python = auto_silent
```

### Debug Variables

```yaml
- name: Print all facts
  ansible.builtin.debug:
    var: ansible_facts

- name: Print selected variable
  ansible.builtin.debug:
    var: nginx_listen_port
```

### Inspect Host Variables

```bash
ansible-inventory -i inventories/lab/hosts.ini --host web01
```

### Common Rocky/RHEL Checks

```bash
ansible webservers -b -m command -a "cat /etc/os-release"
ansible webservers -b -m command -a "dnf repolist"
ansible webservers -b -m command -a "systemctl status nginx --no-pager"
ansible webservers -b -m command -a "journalctl -u nginx -n 50 --no-pager"
```

---

---

## 17. Production Best Practices Checklist

Use this checklist before running automation in production.

### Repository

- [ ] Clear directory layout
- [ ] `README.md` exists
- [ ] `ansible.cfg` is included
- [ ] Inventory separated by environment
- [ ] Roles are reusable
- [ ] Secrets are encrypted with Ansible Vault
- [ ] Collections and roles have requirements files
- [ ] Git commits are signed if possible

### Playbooks

- [ ] Tasks have meaningful names
- [ ] Modules are preferred over `shell` and `command`
- [ ] Templates use `validate` where possible
- [ ] Handlers are used for restarts/reloads
- [ ] Tags are added for operational control
- [ ] `serial` is used for rolling production changes
- [ ] `--check --diff` tested before real run
- [ ] Idempotency tested by running twice

### Security

- [ ] Dedicated automation user exists
- [ ] SSH keys are protected
- [ ] Sudo rules are minimal and reviewed
- [ ] Vault password is protected
- [ ] Sensitive variables are not logged
- [ ] `no_log: true` is used for secret tasks

Example secret-safe task:

```yaml
- name: Create application user with password
  ansible.builtin.user:
    name: appuser
    password: "{{ vault_appuser_password_hash }}"
  no_log: true
```

### Operations

- [ ] Limit runs to target hosts when needed
- [ ] Logs are reviewed after execution
- [ ] Failed hosts are investigated before rerun
- [ ] Rollback procedure exists
- [ ] Monitoring is checked after deployment
- [ ] Service health checks are included

### Documentation

- [ ] Variables are documented
- [ ] Role usage examples exist
- [ ] Inventory examples exist
- [ ] Troubleshooting notes exist
- [ ] Ownership/copyright metadata exists

---

---

## 18. Practical Review Role: Nginx on Rocky Linux 9

This section provides a complete practice role to install and configure Nginx on Rocky Linux 9.

This final practice role is a complete review of the previous topics. It demonstrates:

- Inventory groups and group variables
- Role directory layout
- Defaults and variables
- Tasks split with `import_tasks`
- OS validation using facts and assertions
- Package installation with `dnf`
- Jinja2 templates
- Handlers for restart/reload
- Conditional firewall management
- Loops
- Tags
- Validation with `nginx -t`
- Verification using `uri` and `wait_for`


### Final Project Tree

```text
ansible-nginx-rocky9/
├── ansible.cfg
├── inventories/
│   └── lab/
│       ├── hosts.ini
│       └── group_vars/
│           └── webservers.yml
├── playbooks/
│   └── nginx.yml
└── roles/
    └── nginx/
        ├── defaults/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        ├── meta/
        │   └── main.yml
        ├── tasks/
        │   ├── main.yml
        │   ├── install.yml
        │   ├── configure.yml
        │   ├── firewall.yml
        │   └── verify.yml
        ├── templates/
        │   ├── nginx.conf.j2
        │   └── index.html.j2
        └── README.md
```

---

### `ansible.cfg`

```ini
[defaults]
inventory = inventories/lab/hosts.ini
roles_path = roles
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
interpreter_python = auto_silent

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

---

### Inventory: `inventories/lab/hosts.ini`

```ini
[webservers]
web01 ansible_host=192.168.56.11
web02 ansible_host=192.168.56.12

[webservers:vars]
ansible_user=ansible
ansible_port=22
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

---

### Group Variables: `inventories/lab/group_vars/webservers.yml`

```yaml
---
nginx_package_name: nginx
nginx_service_name: nginx

nginx_worker_processes: auto
nginx_worker_connections: 1024

nginx_listen_port: 80
nginx_server_name: "_"
nginx_web_root: /usr/share/nginx/html
nginx_index_file: index.html

nginx_manage_firewall: true
nginx_firewall_services:
  - http

nginx_custom_message: "Nginx is managed by Ansible on Rocky Linux 9"
```

---

### Playbook: `playbooks/nginx.yml`

```yaml
---
- name: Install and configure Nginx on Rocky Linux 9
  hosts: webservers
  become: true
  gather_facts: true

  roles:
    - nginx
```

---

### Role Defaults: `roles/nginx/defaults/main.yml`

```yaml
---
nginx_package_name: nginx
nginx_service_name: nginx

nginx_worker_processes: auto
nginx_worker_connections: 1024

nginx_listen_port: 80
nginx_server_name: "_"
nginx_web_root: /usr/share/nginx/html
nginx_index_file: index.html

nginx_manage_firewall: false
nginx_firewall_services:
  - http

nginx_custom_message: "Welcome to Nginx managed by Ansible"
```

---

### Role Meta: `roles/nginx/meta/main.yml`

```yaml
---
galaxy_info:
  role_name: nginx
  author: your_name
  description: Install and configure Nginx on Rocky Linux 9
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: EL
      versions:
        - "9"

dependencies: []
```

---

### Main Tasks: `roles/nginx/tasks/main.yml`

```yaml
---
- name: Validate supported operating system
  ansible.builtin.assert:
    that:
      - ansible_facts['os_family'] == 'RedHat'
      - ansible_facts['distribution_major_version'] == '9'
    fail_msg: "This role supports Rocky/RHEL compatible Linux 9 only."
    success_msg: "Supported OS detected."
  tags:
    - always

- name: Include installation tasks
  ansible.builtin.import_tasks: install.yml
  tags:
    - install
    - nginx

- name: Include configuration tasks
  ansible.builtin.import_tasks: configure.yml
  tags:
    - configure
    - nginx

- name: Include firewall tasks
  ansible.builtin.import_tasks: firewall.yml
  when: nginx_manage_firewall | bool
  tags:
    - firewall
    - nginx

- name: Include verification tasks
  ansible.builtin.import_tasks: verify.yml
  tags:
    - verify
    - nginx
```

---

### Install Tasks: `roles/nginx/tasks/install.yml`

```yaml
---
- name: Ensure Nginx package is installed
  ansible.builtin.dnf:
    name: "{{ nginx_package_name }}"
    state: present
  notify: Restart nginx

- name: Ensure Nginx service is enabled and started
  ansible.builtin.systemd_service:
    name: "{{ nginx_service_name }}"
    enabled: true
    state: started
```

---

### Configure Tasks: `roles/nginx/tasks/configure.yml`

```yaml
---
- name: Ensure web root directory exists
  ansible.builtin.file:
    path: "{{ nginx_web_root }}"
    state: directory
    owner: root
    group: root
    mode: '0755'

- name: Deploy custom index page
  ansible.builtin.template:
    src: index.html.j2
    dest: "{{ nginx_web_root }}/{{ nginx_index_file }}"
    owner: root
    group: root
    mode: '0644'
  notify: Reload nginx

- name: Deploy Nginx main configuration from Jinja2 template
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    backup: true
    validate: 'nginx -t -c %s'
  notify: Restart nginx
```

---

### Firewall Tasks: `roles/nginx/tasks/firewall.yml`

```yaml
---
- name: Ensure firewalld is installed
  ansible.builtin.dnf:
    name: firewalld
    state: present

- name: Ensure firewalld is enabled and running
  ansible.builtin.systemd_service:
    name: firewalld
    enabled: true
    state: started

- name: Open required firewall services
  ansible.posix.firewalld:
    service: "{{ item }}"
    permanent: true
    immediate: true
    state: enabled
  loop: "{{ nginx_firewall_services }}"
```

> If `ansible.posix.firewalld` is missing, install the collection:

```bash
ansible-galaxy collection install ansible.posix
```

---

### Verify Tasks: `roles/nginx/tasks/verify.yml`

```yaml
---
- name: Test Nginx configuration
  ansible.builtin.command: nginx -t
  register: nginx_config_test
  changed_when: false

- name: Show Nginx configuration test result
  ansible.builtin.debug:
    var: nginx_config_test.stderr_lines

- name: Check Nginx service status
  ansible.builtin.systemd_service:
    name: "{{ nginx_service_name }}"
    state: started
  register: nginx_service_status

- name: Wait for Nginx HTTP port
  ansible.builtin.wait_for:
    host: "{{ ansible_facts['default_ipv4']['address'] | default(inventory_hostname) }}"
    port: "{{ nginx_listen_port }}"
    timeout: 30

- name: Validate HTTP response locally on managed node
  ansible.builtin.uri:
    url: "http://127.0.0.1:{{ nginx_listen_port }}/"
    status_code: 200
    return_content: true
  register: nginx_http_check
  retries: 5
  delay: 2
  until: nginx_http_check.status == 200

- name: Show HTTP validation result
  ansible.builtin.debug:
    msg: "Nginx responded with HTTP status {{ nginx_http_check.status }}"
```

---

### Handlers: `roles/nginx/handlers/main.yml`

```yaml
---
- name: Restart nginx
  ansible.builtin.systemd_service:
    name: "{{ nginx_service_name }}"
    state: restarted

- name: Reload nginx
  ansible.builtin.systemd_service:
    name: "{{ nginx_service_name }}"
    state: reloaded
```

---

### Nginx Config Template: `roles/nginx/templates/nginx.conf.j2`

```jinja2
# Managed by Ansible
# Do not edit manually. Changes will be overwritten.

user nginx;
worker_processes {{ nginx_worker_processes }};
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections {{ nginx_worker_connections }};
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 4096;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen {{ nginx_listen_port }};
        server_name {{ nginx_server_name }};

        root {{ nginx_web_root }};
        index {{ nginx_index_file }};

        location / {
            try_files $uri $uri/ =404;
        }

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
}
```

---

### Index Page Template: `roles/nginx/templates/index.html.j2`

```jinja2
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Nginx on {{ inventory_hostname }}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background-color: #f7f7f7;
        }
        .box {
            background: white;
            padding: 24px;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0,0,0,0.08);
        }
        code {
            background: #eee;
            padding: 2px 5px;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="box">
        <h1>{{ nginx_custom_message }}</h1>
        <p><strong>Host:</strong> {{ inventory_hostname }}</p>
        <p><strong>Distribution:</strong> {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}</p>
        <p><strong>Managed by:</strong> Ansible</p>
        <p><strong>Listen Port:</strong> <code>{{ nginx_listen_port }}</code></p>
    </div>
</body>
</html>
```

---

### Role README: `roles/nginx/README.md`

```markdown
# Nginx Role

Installs and configures Nginx on Rocky Linux 9.

---

## 19. Useful Commands

### Check Inventory

```bash
ansible-inventory -i inventories/lab/hosts.ini --list
```

### Ping All Hosts

```bash
ansible all -i inventories/lab/hosts.ini -m ping
```

### Syntax Check

```bash
ansible-playbook playbooks/nginx.yml --syntax-check
```

### Dry Run / Check Mode

```bash
ansible-playbook playbooks/nginx.yml --check
```

### Show Changes in Check Mode

```bash
ansible-playbook playbooks/nginx.yml --check --diff
```

### Run Playbook

```bash
ansible-playbook playbooks/nginx.yml
```

### Run Only Install Tasks

```bash
ansible-playbook playbooks/nginx.yml --tags install
```

### Skip Firewall Tasks

```bash
ansible-playbook playbooks/nginx.yml --skip-tags firewall
```

### Limit to One Host

```bash
ansible-playbook playbooks/nginx.yml --limit web01
```

### Start at Specific Task

```bash
ansible-playbook playbooks/nginx.yml --start-at-task "Deploy Nginx main configuration from Jinja2 template"
```



---

Best practices:

- Keep playbooks small and readable.
- Use roles for reusable automation.
- Store environment-specific data in inventories.
- Use `group_vars` and `host_vars` cleanly.
- Use Ansible Vault for secrets.
- Prefer idempotent modules over raw shell commands.
- Use `template` for dynamic configuration files.
- Use handlers for service restarts.
- Use tags for partial execution.
- Test with `--check --diff` before production runs.
- Sign Git commits and keep documentation versioned in GitHub.
