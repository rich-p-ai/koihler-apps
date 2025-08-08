#!/usr/bin/env python3
import re

def clean_deployments_yaml():
    with open('deployments.yaml', 'r') as f:
        content = f.read()
    
    # Split the content into lines
    lines = content.split('\n')
    cleaned_lines = []
    in_status_section = False
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if we're entering a status section
        if line.strip().startswith('conditions:') or line.strip().startswith('observedGeneration:') or line.strip().startswith('readyReplicas:') or line.strip().startswith('replicas:') or line.strip().startswith('updatedReplicas:'):
            in_status_section = True
            i += 1
            continue
        
        # Check if we're exiting a status section (next deployment or end of file)
        if in_status_section and (line.strip().startswith('  - apiVersion:') or line.strip().startswith('kind: List') or line.strip().startswith('metadata: {}')):
            in_status_section = False
        
        # Only add lines that are not in status section
        if not in_status_section:
            cleaned_lines.append(line)
        
        i += 1
    
    # Write the cleaned content back
    with open('deployments.yaml', 'w') as f:
        f.write('\n'.join(cleaned_lines))

if __name__ == "__main__":
    clean_deployments_yaml()
    print("Deployments.yaml cleaned successfully!")
