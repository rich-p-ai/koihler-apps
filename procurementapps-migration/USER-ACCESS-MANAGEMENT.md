# 👥 User Access Management for Procurement Apps

## Overview

This document describes the user access management for the `procurementapps` namespace using OpenShift Groups and Role-Based Access Control (RBAC).

## Group Structure

### `procurementapps-admins` Group

**Purpose**: Administrators with full access to the `procurementapps` namespace

**Permissions**: 
- Full administrative access to all resources in the `procurementapps` namespace
- Can create, read, update, and delete all resources
- Can manage secrets, configmaps, and deployments
- Can view logs and execute into pods

**Current Members**:
- Jeyasri.Babuji@kohler.com

## RBAC Configuration

### Group Definition
```yaml
# gitops/base/group.yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: procurementapps-admins
users:
  - Jeyasri.Babuji@kohler.com
```

### Role Binding
```yaml
# gitops/base/group-rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: procurementapps-admins-binding
  namespace: procurementapps
subjects:
  - kind: Group
    name: procurementapps-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
```

## Managing Group Membership

### Adding Users

To add a new user to the `procurementapps-admins` group:

1. Edit `gitops/base/group.yaml`
2. Add the user's email to the `users` list:
   ```yaml
   users:
     - Jeyasri.Babuji@kohler.com
     - new.user@kohler.com
   ```
3. Commit and push changes
4. Sync the ArgoCD application

### Removing Users

To remove a user from the group:

1. Edit `gitops/base/group.yaml`
2. Remove the user's email from the `users` list
3. Commit and push changes
4. Sync the ArgoCD application

## Additional Groups (Future)

You can create additional groups for different access levels:

### Example: Read-Only Group
```yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: procurementapps-viewers
users:
  - viewer.user@kohler.com
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: procurementapps-viewers-binding
  namespace: procurementapps
subjects:
  - kind: Group
    name: procurementapps-viewers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

### Example: Developer Group
```yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: procurementapps-developers
users:
  - developer.user@kohler.com
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: procurementapps-developers-binding
  namespace: procurementapps
subjects:
  - kind: Group
    name: procurementapps-developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

## Permission Levels

| Role | Permissions | Use Case |
|------|-------------|----------|
| `admin` | Full access to namespace resources | Administrators, DevOps team |
| `edit` | Create, update, delete most resources (not RBAC) | Developers, operators |
| `view` | Read-only access to most resources | Stakeholders, support team |

## Verification Commands

After deployment, verify the group and access:

```bash
# Check if group exists
oc get group procurementapps-admins

# Check group members
oc get group procurementapps-admins -o yaml

# Check role binding
oc get rolebinding procurementapps-admins-binding -n procurementapps

# Check what permissions a user has
oc auth can-i --list --as=Jeyasri.Babuji@kohler.com -n procurementapps
```

## Security Notes

1. **Principle of Least Privilege**: Users should only have the minimum permissions required for their role
2. **Regular Audits**: Periodically review group membership and remove inactive users
3. **GitOps Managed**: All access changes should go through Git for audit trail
4. **No Direct Cluster Changes**: Avoid making manual changes to groups/RBAC outside of GitOps

## Contact

For access requests or questions about permissions, contact the platform team or create an issue in the repository.
