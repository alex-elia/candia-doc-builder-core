# Candia Doc Builder Dual-Repo Architecture

This document explains how to keep the **public core** open source while allowing proprietary business logic to live in a separate **bundle** repository.

## 1. Repositories

| Name | Visibility | Contents | Examples |
|------|------------|----------|----------|
| `candia-doc-builder-core` | Public | Template engine, generators, scripts, docker base, public docs | `pptx`, `latex`, showcase examples |
| `candia-doc-builder` | Private | Proprietary workflows, API routes, integrations, secrets, deployment manifests | Elia Go RFP builders, Supabase storage adapters |

## 2. Dependency Options

### A. Git Submodule (Recommended)

```bash
git submodule add https://github.com/alex-elia/candia-doc-builder-core.git packages/core
```

- Keeps the entire core repo available.
- Bundle repo controls which commit/tag is used.

### B. Package Dependency

1. Package the core (pip/poetry).
2. Install via `pip install candia-doc-builder-core@git+https://...`.

## 3. Directory Layout (Bundle Repo)

```
candia-doc-builder/
├── packages/
│   └── core/                 # Submodule reference
├── services/
│   └── elia/
│       ├── api/              # FastAPI routers
│       ├── workflows/        # Proprietary flows
│       └── templates/        # Private templates
├── deploy/
│   ├── k8s/                  # Production manifests
│   └── vps/                  # Staging docker-compose
├── Dockerfile
└── README.md
```

## 4. Docker Strategy

1. Build the open-source image once (optional) → `candia-doc-builder-core`.
2. In the private repo, copy the core into the image and add proprietary modules.

Example multi-stage Dockerfile (bundle repo):

```dockerfile
FROM ghcr.io/alex-elia/candia-doc-builder-core:latest as core

FROM python:3.11-slim
WORKDIR /app

COPY --from=core /app /app/core
COPY services/elia ./services/elia

# Install private requirements
RUN pip install --no-cache-dir -r services/elia/requirements.txt

CMD ["uvicorn", "services.elia.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 5. Configuration & Secrets

- `.env` is only stored in the private repo.
- Use typed settings classes (`pydantic-settings`) to load env vars.
- Feature flags (e.g., `MODE=oss|enterprise`) determine which routers load.

## 6. Deployment Workflow

| Environment | Source Repo | Target | Notes |
|-------------|-------------|--------|-------|
| OSS Demo | core | Optional | Could publish to GHCR |
| Staging | bundle | VPS docker-compose | Uses `staging-latest` tag |
| Production | bundle | Kubernetes | Uses `vX.Y.Z` tags |

## 7. Contribution Flow

1. Build reusable features in the core first.
2. Expose extension hooks (interfaces/protocols).
3. Implement private adapters in the bundle repo.

By keeping the layers isolated, the public repo remains safe to share while the private repo can evolve quickly with Elia Go–specific logic.



