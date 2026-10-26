# Single-node k3s deployment

One VM (Ubuntu 24.04) running k3s, with Docker used only to build the image.

| Piece | How |
|-------|-----|
| App | `web` Deployment (1 replica), image built on the node and imported into k3s containerd (`imagePullPolicy: Never`) |
| Database | `postgres` StatefulSet, `postgres:16`, 5Gi `local-path` volume on the node's disk |
| Ingress | Traefik (bundled with k3s) on the node's port 80 → `web` Service |
| Migrations / seeds | `bin/docker-entrypoint` runs `db:prepare_locked` before Puma, as on Vercel |
| Files | `database` Active Storage service (PostgreSQL), so the web pod stays stateless |
| Daily reminders | `CronJob` at 09:00 Cairo, curls `/internal/cron/subscription_reminders` with `CRON_SECRET` |

## Secrets

Never committed. On the server they live in `/root/village-secrets.env` (mode 600) and are loaded with:

```bash
kubectl -n village create secret generic village-env --from-env-file=/root/village-secrets.env \
  --dry-run=client -o yaml | kubectl apply -f -
```

Keys: `SECRET_KEY_BASE`, `CRON_SECRET`, `POSTGRES_PASSWORD`, `SUPER_ADMIN_PASSWORD`.
`SUPER_ADMIN_PASSWORD` is only read by the seeds, i.e. on the first boot against an empty database.

## Deploy a new version

```bash
SHA=$(git rev-parse --short HEAD)
git archive --format=tar.gz HEAD | ssh root@HOST "rm -rf /opt/village-platform && mkdir -p /opt/village-platform \
  && tar -xzf - -C /opt/village-platform && cd /opt/village-platform \
  && docker build -f Dockerfile.vercel -t village-platform:$SHA . \
  && docker save village-platform:$SHA | k3s ctr images import -"
# bump images[].newTag in kustomization.yaml to $SHA, copy deploy/k8s to the server, then:
ssh root@HOST "kubectl apply -k /opt/village-deploy/deploy/k8s && kubectl -n village rollout status deploy/web"
```

## Useful commands

```bash
kubectl -n village get pods
kubectl -n village logs deploy/web -f
kubectl -n village exec -it deploy/web -- bin/rails console
kubectl -n village create job --from=cronjob/subscription-reminders reminders-manual
kubectl -n village exec postgres-0 -- pg_dump -U village aghour_services_production > backup.sql
```

## Known gaps

- Plain HTTP on the IP. Add a domain + cert-manager (or Traefik's ACME) before real users, then set
  `ASSUME_SSL` / `FORCE_SSL` in `config.yaml`. JWTs and passwords travel in clear text until then.
- No database backups. The data is on one disk of one VM.
- No registry: the image exists only on this node.
