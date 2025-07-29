# 📋 Corporate Apps Migration - Quick Reference

## 🚀 Quick Commands

### Run Migration
```bash
cd koihler-apps/corporateapps-migration
./migrate-corporateapps.sh
```

### Deploy with ArgoCD
```bash
./deploy-corporateapps-argocd.sh
# OR manually:
oc apply -f gitops/argocd-application.yaml
```

### Monitor Deployment
```bash
oc get application corporateapps-prd -n openshift-gitops -w
oc get all -n corporateapps
```

## 🎯 Applications Included

| Application | Type | Description |
|-------------|------|-------------|
| java-phonelist-prd | Web App | Java-based employee phone directory |
| wins0001173-prd | Windows App | Windows-based application |
| wins0001174-prd | Windows App | Windows-based application |
| dv01b2bd-batch | Batch Job | Batch processing application |
| er13gplu-batch | Batch Job | Batch processing application |

## 📁 Directory Structure

```
corporateapps-migration/
├── migrate-corporateapps.sh          # Migration script
├── deploy-corporateapps-argocd.sh    # Deployment script
├── backup/                           # Original resources
├── gitops/                          # GitOps structure
│   ├── base/                        # Base configuration
│   └── overlays/prd/                # Production overlay
└── README.md                        # Documentation
```

## 🔍 Verification Commands

```bash
# Check ArgoCD app
oc get application corporateapps-prd -n openshift-gitops

# Check pods
oc get pods -n corporateapps

# Check routes
oc get route -n corporateapps

# Check logs
oc logs -n corporateapps deployment/<app-name>
```

## ⚡ Troubleshooting

| Issue | Command | Solution |
|-------|---------|----------|
| Migration fails | `oc whoami && oc get ns corporateapps` | Verify cluster access |
| ArgoCD sync error | `oc describe app corporateapps-prd -n openshift-gitops` | Check application logs |
| Pod not starting | `oc describe pod <pod> -n corporateapps` | Check events and logs |
| Image pull error | `oc get secret -n corporateapps \| grep pull` | Verify image registry access |

## 🔄 Rollback

```bash
# ArgoCD rollback
argocd app rollback corporateapps-prd

# Manual cleanup
oc delete application corporateapps-prd -n openshift-gitops
oc delete namespace corporateapps
```

## 📞 Support

- **Primary**: OpenShift Migration Team
- **Documentation**: See `CORPORATEAPPS-MIGRATION-GUIDE.md`
- **Repository**: https://github.com/rich-p-ai/koihler-apps
