# Server Preparation and Hardening Ansible Role

This Ansible role automates the initial configuration, package management, and security hardening of freshly provisioned Linux servers.

---

## What This Role Does

1. **Package Management**: Updates system package repositories and installs a defined list of essential troubleshooting, networking, and system tools (supporting Debian and Red Hat families).
2. **Network & DNS Configuration**: Standardizes DNS resolution by configuring `/etc/resolv.conf` using customizable primary and secondary upstream DNS resolvers.
3. **Firewall Setup (iptables)**: Deploys robust firewall rules via a Jinja2 template. It secures incoming/outgoing traffic, permits loopback communication, accepts established connections, and restricts ports to trusted networks.
4. **SSH Daemon Hardening**: Hardens SSH access by securing authentication parameters (disabling root login if configured, enforcing SSH keys, specifying allowed groups/users, and changing the port) and deploys a strict legal banner at login.

---

## Essential Prerequisites (Before Running)

Prior to running this Ansible playbook, ensure the following steps are completed:

1. **SSH Key Distribution**:
   Ensure your local SSH public key is added to the target host's `authorized_keys` file for the user executing the playbook:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub user@target_host_ip
   ```
2. **Sudo Privileges**:
   The execution user on the target systems must have passwordless `sudo` privileges configured, or you must run the playbook with the `--ask-become-pass` (`-K`) flag to supply the sudo password.
3. **Inventory & Host Groups Setup**:
   Define your target IP addresses under the `train-servers` (or desired host group) inside your Ansible inventory file.
4. **Define Variables**:
   Customize the variables located in `inventory/group_vars/all/` (such as `packages.yml`, `iptables_config.yml`, `resolved_config.yml`, and `sshd_config.yml`) to match your network policy and SSH access controls.

---

## Role Components & Configurations

### Variables (`inventory/group_vars/all/` & Defaults)
* **`packages.yml`**: Defines target-specific software to install (e.g., `curl`, `vim`, `htop`, `net-tools`).
* **`iptables_config.yml`**: Specifies paths, custom rules, allowed ports, and trusted IP ranges.
* **`resolved_config.yml`**: Sets primary and secondary DNS servers (e.g., `dns_nameservers: ['8.8.8.8', '1.1.1.1']`).
* **`sshd_config.yml`**: Houses security adjustments like `sshd_port`, `permit_root_login`, `password_authentication`, and permitted user groups.

### Templates (`roles/preparing-server/templates/`)
* **`iptables.j2`**: Renders standard iptables rule chains allowing safe state management, loopback interfaces, and custom admin/service ports.
* **`resolv.conf.j2`**: Configures DNS nameservers dynamically based on your environment variables.
* **`sshd_config.j2`**: Employs variables to generate a secure `/etc/ssh/sshd_config` daemon file.

### Static Files (`roles/preparing-server/files/`)
* **`ssh_banner`**: Standard pre-login notice presented to users detailing authorized-use-only policy.

---

## How to Run

Execute the playbook targeting your configured hosts:

```bash
ansible-playbook -i inventory/hosts playbook/preparing-setup.yml --ask-become-pass
```
# Server Preparation and Hardening Ansible Role

This Ansible role automates the initial configuration, package management, and security hardening of freshly provisioned Linux servers.

---

## What This Role Does

1. **Package Management**: Updates system package repositories and installs a defined list of essential troubleshooting, networking, and system tools (supporting Debian and Red Hat families).
2. **Network & DNS Configuration**: Standardizes DNS resolution by configuring `/etc/resolv.conf` using customizable primary and secondary upstream DNS resolvers.
3. **Firewall Setup (iptables)**: Deploys robust firewall rules via a Jinja2 template. It secures incoming/outgoing traffic, permits loopback communication, accepts established connections, and restricts ports to trusted networks.
4. **SSH Daemon Hardening**: Hardens SSH access by securing authentication parameters (disabling root login if configured, enforcing SSH keys, specifying allowed groups/users, and changing the port) and deploys a strict legal banner at login.

---

## Essential Prerequisites (Before Running)

Prior to running this Ansible playbook, ensure the following steps are completed:

1. **SSH Key Distribution**:
   Ensure your local SSH public key is added to the target host's `authorized_keys` file for the user executing the playbook:
   ```bash
   ssh-copy-id -i ~/.ssh/id_rsa.pub user@target_host_ip
   ```
2. **Sudo Privileges**:
   The execution user on the target systems must have passwordless `sudo` privileges configured, or you must run the playbook with the `--ask-become-pass` (`-K`) flag to supply the sudo password.
3. **Inventory & Host Groups Setup**:
   Define your target IP addresses under the `train-servers` (or desired host group) inside your Ansible inventory file.
4. **Define Variables**:
   Customize the variables located in `inventory/group_vars/all/` (such as `packages.yml`, `iptables_config.yml`, `resolved_config.yml`, and `sshd_config.yml`) to match your network policy and SSH access controls.

---

## Role Components & Configurations

### Variables (`inventory/group_vars/all/` & Defaults)
* **`packages.yml`**: Defines target-specific software to install (e.g., `curl`, `vim`, `htop`, `net-tools`).
* **`iptables_config.yml`**: Specifies paths, custom rules, allowed ports, and trusted IP ranges.
* **`resolved_config.yml`**: Sets primary and secondary DNS servers (e.g., `dns_nameservers: ['8.8.8.8', '1.1.1.1']`).
* **`sshd_config.yml`**: Houses security adjustments like `sshd_port`, `permit_root_login`, `password_authentication`, and permitted user groups.

### Templates (`roles/preparing-server/templates/`)
* **`iptables.j2`**: Renders standard iptables rule chains allowing safe state management, loopback interfaces, and custom admin/service ports.
* **`resolv.conf.j2`**: Configures DNS nameservers dynamically based on your environment variables.
* **`sshd_config.j2`**: Employs variables to generate a secure `/etc/ssh/sshd_config` daemon file.

### Static Files (`roles/preparing-server/files/`)
* **`ssh_banner`**: Standard pre-login notice presented to users detailing authorized-use-only policy.

---

## How to Run

Execute the playbook targeting your configured hosts:

```bash
ansible-playbook -i inventory/hosts.yml playbook/preparing-setup.yml --ask-become-pass

# Only run SSH hardening
ansible-playbook -i inventory/hosts.yml playbook/preparing-setup.yml --tags "ssh"
```
