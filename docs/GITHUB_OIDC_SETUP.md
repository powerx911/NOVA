# NEXORA GitHub OIDC exporter setup

The new Firestore exporter runs from GitHub Actions and imports through the `nexora-migration-import` Edge Function. It does not use a service-account JSON key or a Supabase service-role key in GitHub.

## One-time Google Cloud setup

Run these commands as a Google Cloud project administrator. The existing runtime service account is reused; the new GitHub identity pool is separate from the Vercel pool. The commands discover the numeric project number instead of assuming it.

```bash
PROJECT_NUMBER="$(gcloud projects describe gen-lang-client-0074900177 --format='value(projectNumber)')"

gcloud iam workload-identity-pools create nexora-github-pool \
  --project=gen-lang-client-0074900177 \
  --location=global \
  --display-name="NEXORA GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc nexora-github \
  --project=gen-lang-client-0074900177 \
  --location=global \
  --workload-identity-pool=nexora-github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository == 'luffyk124-del/nexora-game' && (assertion.ref == 'refs/heads/feature/nexora-social-economy-mobile-overhaul' || assertion.ref == 'refs/heads/main') && assertion.actor == 'luffyk124-del'"

gcloud iam service-accounts add-iam-policy-binding \
  nexora-vercel-runtime@gen-lang-client-0074900177.iam.gserviceaccount.com \
  --project=gen-lang-client-0074900177 \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/nexora-github-pool/attribute.repository/luffyk124-del/nexora-game"
```

The service account must retain Firestore read access (`roles/datastore.viewer`) on project `gen-lang-client-0074900177`. Do not grant broader Firestore write permissions.

## One GitHub repository variable

Create this repository Actions variable (not a secret):

- Name: `GCP_GITHUB_WIF_PROVIDER`
- Value: `projects/145581837596/locations/global/workloadIdentityPools/nexora-github-pool/providers/nexora-github`

No Firebase private key, Google service-account key, or Supabase service-role key is required in GitHub.

## Run and verify

1. Open [NEXORA Firestore Export workflow](https://github.com/luffyk124-del/nexora-game/actions/workflows/nexora-firestore-export.yml).
2. Run it with mode `scan` first. This reads Firestore and prints per-collection counts without writing to Supabase.
3. Compare the counts with the NEXORA archive and inspect the workflow logs.
4. Only after reviewing the scan, run mode `import`. The importer verifies the GitHub OIDC issuer, audience, repository, branch, workflow path, event, and actor; batch checksums make retries idempotent.
5. Keep Firebase authoritative until read/write parity and authenticated end-to-end tests pass.

Automatic scheduling is intentionally disabled until the Google Cloud federation and first scan/import are verified. Use manual mode `scan` first; `import` is a separate explicit action. The legacy Vercel exporter remains as a rollback path until the first GitHub scan and import have both succeeded; do not run both exporters at the same time.