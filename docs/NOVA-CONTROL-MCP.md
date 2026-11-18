# NOVA Control MCP

A narrowly scoped remote MCP server for the `powerx911/NOVA` repository.

## What it can do

- Read GitHub Pages configuration.
- Enable/update Pages to use the `pages.yml` GitHub Actions workflow on `main`.
- Dispatch `pages.yml` manually.
- List recent Pages workflow runs.
- Inspect jobs and step results for a workflow run.

The server is deliberately hard-coded to one repository and one workflow. It does not accept arbitrary owner/repository names, arbitrary workflow paths, shell commands, or arbitrary GitHub API paths.

## Runtime

Deployed as a Supabase Edge Function in the existing NOVA Supabase project by GitHub Actions. MCP transport: stateless Streamable HTTP with JSON responses.

Endpoint:
`https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/nova-control`

Health:
`https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/nova-control/health`

## One-time setup

In GitHub, open **powerx911/NOVA → Settings → Secrets and variables → Actions** and add:

- `SUPABASE_ACCESS_TOKEN`: a Supabase personal access token allowed to deploy Edge Functions to the existing NOVA project.
- `NOVA_GITHUB_TOKEN`: a fine-grained GitHub PAT restricted to this repository. Required repository permissions: **Pages: Read and write**, **Administration: Read and write** (GitHub requires this when creating a Pages site), and **Actions: Read and write**. Metadata read is automatic. Keep an expiry and rotate it periodically.
- `NOVA_MCP_ACCESS_TOKEN`: a separate high-entropy random bearer token for MCP client authentication. Generate one locally, for example with `openssl rand -hex 32`. Do not reuse the GitHub or Supabase token.

Never paste any of these values into chat or commit them to Git.

After these three GitHub Actions secrets are saved, run **Actions → Deploy NOVA Control MCP → Run workflow**, or merge a change to the function files on `main`. The workflow copies the two NOVA runtime secrets into Supabase's Edge Function secret store and deploys the function.

## Security

- The function performs its own bearer-token authentication; Supabase gateway JWT verification is disabled only for this function.
- GitHub credentials stay in Supabase Edge Function secrets and are never returned by a tool.
- Mutating MCP tools require an explicit `confirm: true` argument.
- Only the Pages settings and the fixed `pages.yml` workflow can be changed/run.
- Review all new tool capabilities before expanding the allowed repository scope.

## Deployment

Deployment is managed by `.github/workflows/deploy-nova-control.yml`. Do not deploy this function manually from another hosting platform.
