#!/bin/bash

# Fixed DeploymentConfig to Deployment Converter
set -e

BACKUP_DIR="$(pwd)/backup"
CLEANED_DIR="$BACKUP_DIR/cleaned"

echo "=== CONVERTING DEPLOYMENTCONFIGS TO DEPLOYMENTS ==="

# Create cleaned directory if it doesn't exist
mkdir -p "$CLEANED_DIR"

# Process each DeploymentConfig individually
yq eval '.items[]' "$BACKUP_DIR/raw/deploymentconfigs.yaml" | yq eval '. as $item ireduce ({}; . *+ {"---": ""} *+ $item)' | \
while IFS= read -r -d '' deployment || [[ -n "$deployment" ]]; do
    if [[ "$deployment" == "---" ]]; then
        continue
    fi
    
    # Extract deployment name
    dc_name=$(echo "$deployment" | yq eval '.metadata.name // ""')
    
    if [[ -n "$dc_name" && "$dc_name" != "null" && "$dc_name" != "---" ]]; then
        echo "Converting DeploymentConfig: $dc_name"
        
        # Create Deployment YAML
        cat > "$CLEANED_DIR/deployment-${dc_name}.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${dc_name}
  namespace: procurementapps
  labels:
$(echo "$deployment" | yq eval '.metadata.labels' | sed 's/^/    /')
  annotations:
    migrated-from: DeploymentConfig
    migration-date: $(date -Iseconds)
spec:
  replicas: $(echo "$deployment" | yq eval '.spec.replicas // 1')
  selector:
    matchLabels:
      app: ${dc_name}
      deployment: ${dc_name}
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ${dc_name}
        deployment: ${dc_name}
$(echo "$deployment" | yq eval '.spec.template.metadata.labels // {}' | sed 's/^/        /')
    spec:
$(echo "$deployment" | yq eval '.spec.template.spec' | sed 's/^/      /')
---
EOF
    fi
done < <(yq eval '.items[] | (. + {"separator": "---"})' "$BACKUP_DIR/raw/deploymentconfigs.yaml" -0)

echo "Deployment conversion completed!"
