# SSH Keys Backup from cpq-ssh-keys PVC

This directory contains a backup of all SSH keys from the `cpq-ssh-keys` Persistent Volume Claim in the `oraclecpq` namespace.

## Directory Structure

```
ssh-keys-backup/
├── dev/
│   ├── ssh_host_ed25519_key          # Dev environment SSH host ed25519 private key
│   ├── ssh_host_ed25519_key.pub      # Dev environment SSH host ed25519 public key
│   ├── ssh_host_rsa_key              # Dev environment SSH host RSA private key
│   └── ssh_host_rsa_key.pub          # Dev environment SSH host RSA public key
├── prd/
│   ├── ssh_host_ed25519_key          # Production environment SSH host ed25519 private key
│   ├── ssh_host_ed25519_key.pub      # Production environment SSH host ed25519 public key
│   ├── ssh_host_rsa_key              # Production environment SSH host RSA private key
│   └── ssh_host_rsa_key.pub          # Production environment SSH host RSA public key
├── qa/
│   ├── ssh_host_ed25519_key          # QA environment SSH host ed25519 private key
│   ├── ssh_host_ed25519_key.pub      # QA environment SSH host ed25519 public key
│   ├── ssh_host_rsa_key              # QA environment SSH host RSA private key
│   └── ssh_host_rsa_key.pub          # QA environment SSH host RSA public key
└── README.md                         # This file
```

## Key Details

### Environment-Specific Keys

Each environment (dev, prd, qa) has its own set of SSH host keys:

1. **ed25519 Keys**: Modern, secure SSH key type
   - Private key: `ssh_host_ed25519_key`
   - Public key: `ssh_host_ed25519_key.pub`

2. **RSA Keys**: Traditional SSH key type
   - Private key: `ssh_host_rsa_key`
   - Public key: `ssh_host_rsa_key.pub`

### Key Information

- **Key Type**: SSH host keys for server authentication
- **Owner**: ko25688@uswix564
- **Source**: cpq-ssh-keys PVC in oraclecpq namespace
- **Backup Date**: August 8, 2025
- **Cluster**: OCP-PRD

## Usage

These keys are SSH host keys used for server authentication. They should be:

1. **Securely stored** - These are sensitive private keys
2. **Backed up regularly** - Important for disaster recovery
3. **Used only for authorized purposes** - Server authentication only

## Security Notes

⚠️ **IMPORTANT**: These are private SSH keys and should be handled with appropriate security measures:

- Store in secure locations
- Use appropriate file permissions (600 for private keys)
- Do not share private keys
- Rotate keys regularly as per security policies

## Restoration

To restore these keys to a new PVC or server:

1. Copy the appropriate environment keys to the target location
2. Set correct file permissions (600 for private keys, 644 for public keys)
3. Update SSH configuration to use the new keys
4. Restart SSH service if necessary

## Backup Method

These keys were extracted using a temporary pod with Red Hat UBI image:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpq-ssh-keys-copy
  namespace: oraclecpq
spec:
  containers:
  - name: copy
    image: registry.access.redhat.com/ubi8/ubi-minimal:latest
    command: ["sh", "-c", "ls -la /ssh-keys && find /ssh-keys -type f -exec echo '{}' \\;"]
    volumeMounts:
    - name: ssh-keys
      mountPath: /ssh-keys
  volumes:
  - name: ssh-keys
    persistentVolumeClaim:
      claimName: cpq-ssh-keys
  restartPolicy: Never
```
