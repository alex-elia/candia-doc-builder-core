# Docker Strategy

Candia Doc Builder now ships as two layers:

| Layer | Repository | Container Registry Image |
|-------|------------|--------------------------|
| **Core (public)** | `candia-doc-builder-core` | `ghcr.io/alex-elia/candia-doc-builder-core` |
| **Bundle (private)** | `candia-doc-builder` | `ghcr.io/alex-elia/candia-doc-builder` |

The **core image** contains the open-source template engine and generators. The **bundle image** copies the core into a private repo and adds proprietary services, env-specific configs, and deployment manifests.

---

## 1. Core Image (this repo)

### Build locally

```bash
docker build -t candia-doc-builder-core:local .
docker run --rm -p 8000:8000 candia-doc-builder-core:local
```

### GitHub Actions

- `.github/workflows/docker-build.yml` → pushes `latest`, branch, and semver tags to GHCR.
- `.github/workflows/docker-build-staging.yml` → optional staging-only build if you need to test the core image.
- `.github/workflows/docker-build-production.yml` → produces signed `vX.Y.Z` tags.

All workflows push to `ghcr.io/alex-elia/candia-doc-builder-core`.

---

## 2. Bundle Image (private repo)

1. Create `/packages/core` as a git submodule pointing to this repo **or** install it as a pip dependency.
2. Build the bundle image using the core as a base layer:

```dockerfile
FROM ghcr.io/alex-elia/candia-doc-builder-core:latest as core

FROM python:3.11-slim
WORKDIR /app

COPY --from=core /app /app/core
COPY services/elia ./services/elia

RUN pip install --no-cache-dir -r services/elia/requirements.txt

CMD ["uvicorn", "services.elia.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

3. Publish the bundle image under `ghcr.io/alex-elia/candia-doc-builder`.

---

## 3. Deployment Targets

| Environment | Image | Notes |
|-------------|-------|-------|
| OSS demo | `candia-doc-builder-core` | Optional; exposes generic endpoints only |
| Staging (VPS) | `candia-doc-builder:staging-latest` | Uses docker-compose or `scripts/deploy/vps-deploy.*` |
| Production (Kubernetes) | `candia-doc-builder:vX.Y.Z` | Uses manifests in `k8s/` (they assume bundle image) |

### VPS quick deploy (bundle)

```bash
./scripts/deploy/vps-deploy.sh staging-latest
```

### Kubernetes deploy (bundle)

```bash
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/candia-doc-builder -n backend
```

> Update `k8s/deployment.yaml` to reference the bundle image tag before deploying.

---

## 4. Environment Variables

| Variable | Layer | Description |
|----------|-------|-------------|
| `PORT` | Core/Bundle | HTTP port (default 8000) |
| `SUPABASE_URL` | Bundle | Project URL for storage |
| `SUPABASE_SERVICE_ROLE_KEY` | Bundle | Service role (private only) |
| `OVH_*` vars | Bundle | Object storage credentials |

Keep secrets exclusively in the private repo or secret managers.

---

## 5. Testing Checklist

1. `docker build -t candia-doc-builder-core:local .`
2. Run generators inside the container:

```bash
docker run -it --rm \
  -v $(pwd)/scripts:/app/scripts:ro \
  candia-doc-builder-core:local \
  python scripts/presentation/create_premium_template.py
```

3. For bundle builds, replicate the same tests after copying private services.

---

## 6. Release Flow

1. Develop features in the core repo.
2. Cut a tag (`vX.Y.Z`) → triggers production workflow → publishes `candia-doc-builder-core:vX.Y.Z`.
3. In the private repo, bump the submodule/tag, rebuild the bundle image, and deploy to staging/prod.

This keeps the public image clean and reusable while allowing the private bundle to evolve with Elia Go–specific logic.

