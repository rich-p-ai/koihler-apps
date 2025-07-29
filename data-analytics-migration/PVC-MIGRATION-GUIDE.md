# í³¦ PVC Data Migration Guide

## Overview
- **Date**: Wed, Jul 23, 2025 10:46:21 AM
- **Source**: OCP4 (https://api.ocp4.kohlerco.com:6443)
- **Target**: OCP-PRD
- **Namespace**: data-analytics
- **PVCs**: 8 total

## PVC List
```
NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                         AGE
cdh-callfinder-vol01        Bound    pvc-34097b5b-bff8-434b-93c5-f2124fbebb90   2Gi        RWX            ocs-external-storagecluster-cephfs   684d
migration-backup-storage    Bound    pvc-b8bed632-c2e4-469f-9d88-79c82d70053d   50Gi       RWX            ocs-external-storagecluster-cephfs   5m9s
nfspvcdataanalyticsdata01   Bound    nfspvdataanalyticsdata01                   10Gi       RWX            nfs                                  4y17d
sci-scorecard-dev-vol01     Bound    pvc-a6fe3c3f-9698-487c-8652-cc2e34bb99ba   2Gi        RWX            ocs-external-storagecluster-cephfs   693d
sftp-analytics-01           Bound    pvc-31a78975-4210-4795-95c4-a364a1371e57   2Gi        RWO            thin                                 4y39d
sftp-analytics-data01       Bound    csipscale-9d3f70bb02                       10Gi       RWX            isilon-storageclass                  4y39d
sftp-datalake-01            Bound    pvc-19a9af7d-426d-4ba6-9fdf-65978d442731   1Gi        RWX            ocs-external-storagecluster-cephfs   3y312d
sftp-datalake-data01        Bound    csipscale-ca2b9e6e4d                       5Gi        RWX            isilon-storageclass-v6               3y312d
```

## Migration Steps

### 1. Export Data from OCP4
```bash
cd /tmp/data-analytics-pvc-migration/scripts
./run-exports.sh
```

### 2. Monitor Export Progress
```bash
oc get jobs -n data-analytics -l migration=data-analytics
oc logs -n data-analytics -l migration=data-analytics --follow
```

### 3. Switch to OCP-PRD and Import
```bash
oc login https://api.ocp-prd.kohlerco.com:6443
cd /tmp/data-analytics-pvc-migration/scripts  
./run-imports.sh
```

### 4. Verify Migration
```bash
oc get pods -n data-analytics
# Check if applications can access the data
```

## Files Generated
backup-storage.yaml
export-cdh-callfinder-vol01.yaml
export-migration-backup-storage.yaml
export-nfspvcdataanalyticsdata01.yaml
export-sci-scorecard-dev-vol01.yaml
export-sftp-analytics-01.yaml
export-sftp-analytics-data01.yaml
export-sftp-datalake-01.yaml
export-sftp-datalake-data01.yaml
import-cdh-callfinder-vol01.yaml
import-migration-backup-storage.yaml
import-nfspvcdataanalyticsdata01.yaml
import-sci-scorecard-dev-vol01.yaml
import-sftp-analytics-01.yaml
import-sftp-analytics-data01.yaml
import-sftp-datalake-01.yaml
import-sftp-datalake-data01.yaml
run-exports.sh
run-imports.sh
target-backup-storage.yaml

**Ready to migrate!** íº€
