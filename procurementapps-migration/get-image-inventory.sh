#!/bin/bash

# Get all available image tags from source registry
# This script helps identify which images need to be migrated

set -e

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="procurementapps"
IMAGE_NAME="pm-procedures-webapp"

echo -e "${BLUE}=== PROCUREMENT APPS IMAGE INVENTORY ===${NC}"
echo

# Check if logged into OCP4
if ! oc whoami &> /dev/null; then
    echo -e "${YELLOW}[ERROR]${NC} Not logged into OpenShift. Please run 'oc login'"
    exit 1
fi

CURRENT_SERVER=$(oc whoami --show-server)
if [[ "$CURRENT_SERVER" != *"ocp4"* ]]; then
    echo -e "${YELLOW}[WARNING]${NC} Not connected to OCP4. Current: $CURRENT_SERVER"
fi

echo -e "${YELLOW}[INFO]${NC} Getting image tags from namespace: $NAMESPACE"
echo -e "${YELLOW}[INFO]${NC} Image stream: $IMAGE_NAME"
echo

# Get all tags
echo -e "${BLUE}=== AVAILABLE TAGS ===${NC}"
TAGS=$(oc get imagestream $IMAGE_NAME -n $NAMESPACE -o jsonpath='{.status.tags[*].tag}' 2>/dev/null)

if [ -z "$TAGS" ]; then
    echo "No tags found or imagestream doesn't exist"
    exit 1
fi

# Convert to array and sort
IFS=' ' read -r -a TAG_ARRAY <<< "$TAGS"
SORTED_TAGS=($(printf '%s\n' "${TAG_ARRAY[@]}" | sort -V))

echo "Found ${#SORTED_TAGS[@]} tags:"
echo

# Group tags by type
LATEST_TAGS=()
TEST_TAGS=()
DATED_TAGS=()
OTHER_TAGS=()

for tag in "${SORTED_TAGS[@]}"; do
    if [[ "$tag" == "latest" ]]; then
        LATEST_TAGS+=("$tag")
    elif [[ "$tag" == "test" ]]; then
        TEST_TAGS+=("$tag")
    elif [[ "$tag" =~ ^20[0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]$ ]]; then
        DATED_TAGS+=("$tag")
    else
        OTHER_TAGS+=("$tag")
    fi
done

# Display categorized tags
if [ ${#LATEST_TAGS[@]} -gt 0 ]; then
    echo -e "${GREEN}Latest Tags:${NC}"
    printf '  %s\n' "${LATEST_TAGS[@]}"
    echo
fi

if [ ${#TEST_TAGS[@]} -gt 0 ]; then
    echo -e "${GREEN}Test Tags:${NC}"
    printf '  %s\n' "${TEST_TAGS[@]}"
    echo
fi

if [ ${#DATED_TAGS[@]} -gt 0 ]; then
    echo -e "${GREEN}Dated Tags (most recent first):${NC}"
    # Reverse sort dated tags to show newest first
    REVERSED_DATED=($(printf '%s\n' "${DATED_TAGS[@]}" | sort -rV))
    printf '  %s\n' "${REVERSED_DATED[@]}"
    echo
fi

if [ ${#OTHER_TAGS[@]} -gt 0 ]; then
    echo -e "${GREEN}Other Tags:${NC}"
    printf '  %s\n' "${OTHER_TAGS[@]}"
    echo
fi

# Show recommended tags for migration
echo -e "${BLUE}=== RECOMMENDED MIGRATION TAGS ===${NC}"
echo "For production migration, consider these key tags:"
echo

# Get the 5 most recent dated tags
RECENT_DATED=($(printf '%s\n' "${DATED_TAGS[@]}" | sort -rV | head -5))

echo -e "${GREEN}Essential:${NC}"
echo "  latest    (production baseline)"
echo "  test      (testing version)"
echo

echo -e "${GREEN}Recent Versions:${NC}"
printf '  %s\n' "${RECENT_DATED[@]}"
echo

# Generate migration command
echo -e "${BLUE}=== MIGRATION COMMAND ===${NC}"
echo "To update the migration script with specific tags, edit:"
echo "  migrate-images-to-quay.sh"
echo
echo "Update the TAGS_TO_MIGRATE array with your desired tags:"
echo 'TAGS_TO_MIGRATE=('
printf '  "%s"\n' "latest" "test" "${RECENT_DATED[@]}"
echo ')'
echo

# Show image details for latest tag
echo -e "${BLUE}=== LATEST IMAGE DETAILS ===${NC}"
oc get imagestream $IMAGE_NAME -n $NAMESPACE -o jsonpath='{.status.tags[?(@.tag=="latest")].items[0]}' | jq . 2>/dev/null || echo "Latest tag details not available"

echo
echo -e "${GREEN}✓ Image inventory complete${NC}"
