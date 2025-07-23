# Applications Directory

This directory will contain future OpenShift application deployments for Kohler Co.

## Structure

Each application should follow this structure:
```
application-name/
├── README.md
├── gitops/
│   ├── base/
│   └── overlays/
│       ├── dev/
│       ├── test/
│       └── prd/
└── scripts/
```

## Current Applications

- **data-analytics**: See `../data-analytics-migration/` for the migration project
