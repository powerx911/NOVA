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

Deployed as a Supabase Edge Function in the existing NOVA Supabase project. MCP transport: stateless Streamable HTTP with JSON responses.

Endpoint:
`https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/nova-control`

Health:
`https://hmrprnjhyzyefocdmnxf.supabase.co/functions/v1/nova-control/health`

## Required secrets

Set these in Supabase Dashboard → Edge Functions → Secrets. Never commit them to Git or paste them into chat.

- `NOVA_GITHUB_TOKEN`: a fine-grained GitHub PAT restricted to `powerx911/NOVA`. Required permissions: Pages (read/write), Administration (write, required by GitHub when creating a Pages site), Actions (read/write). Metadata is granted automatically. Keep an expiry and rotate it periodically.
- `NOVA_MCP_ACCESS_TOKEN`: a separate high-entropy random bearer token used by MCP clients to authenticate to this endpoint. Do not reuse the GitHub token.

## Security

- The function performs its own bearer-token authentication; Supabase gateway JWT verification is disabled only for this function.
- GitHub credentials stay in Supabase Edge Function secrets and are never returned by a tool.
- Mutating tools require an explicit `confirm: true` argument.
- Only the Pages settings and the fixed `pages.yml` workflow can be changed/run.
- Review all new tool capabilities before expanding the allowed repository scope.

## Deploy

Deploy the function from the repository using Supabase CLI:

```sh
supabase functions deploy nova-control --project-ref hmrprnjhyzyefocdmnxf --no-verify-jwt
```

The production secrets are read at runtime and do not need to be committed.
