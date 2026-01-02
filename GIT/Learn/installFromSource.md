##  Installing Git from Source on Rocky Linux 9.5

This guide explains how to download, compile, and install **Git from source** on **Rocky Linux 9.5**. Installing from source is useful when you need a newer Git version than what is available in the default repositories.

---

### Prerequisites

Ensure your system is up to date and has the required build tools and libraries.

```bash
sudo dnf update -y
sudo dnf groupinstall -y "Development Tools"
```
### Install required dependencies for building Git:
```
sudo dnf install -y \
  curl-devel \
  expat-devel \
  gettext-devel \
  openssl-devel \
  perl-ExtUtils-MakeMaker \
  zlib-devel

```
### Download Git Source Code
```
cd /usr/src/
sudo wget https://www.kernel.org/pub/software/scm/git/git-2.52.0.tar.gz
sudo tar -xzf git-2.52.0.tar.gz
cd git-2.52.0
```
### Compile, Build and install Git
```
#Generate the configure script:

sudo make configure


#Configure the build environment:

sudo ./configure --prefix=/usr/local


#Compile Git:

sudo make all

#Install Git

sudo make install

# Update PATH (If Needed)
echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

```
### Verify Installation
```
/usr/local/bin/git --version

```
### unistall git from source
```
cd /usr/src/git-2.52.0
sudo make uninstall

```
