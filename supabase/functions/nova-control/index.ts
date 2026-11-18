import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

import { McpServer } from 'npm:@modelcontextprotocol/sdk@1.25.3/server/mcp.js'
import { WebStandardStreamableHTTPServerTransport } from 'npm:@modelcontextprotocol/sdk@1.25.3/server/webStandardStreamableHttp.js'
import { Hono } from 'npm:hono@4.9.7'
import { z } from 'npm:zod@4.1.13'

const OWNER = 'powerx911'
const REPO = 'NOVA'
const DEFAULT_BRANCH = 'main'
const WORKFLOW_FILE = 'pages.yml'
const GITHUB_API = 'https://api.github.com'

function constantTimeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a)
  const right = new TextEncoder().encode(b)
  let diff = left.length ^ right.length
  const length = Math.max(left.length, right.length)
  for (let i = 0; i < length; i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0)
  }
  return diff === 0
}

async function githubRequest(path: string, method = 'GET', body?: unknown) {
  const token = Deno.env.get('NOVA_GITHUB_TOKEN')
  if (!token) throw new Error('Server is not configured: NOVA_GITHUB_TOKEN is missing.')
  const response = await fetch(`${GITHUB_API}${path}`, {
    method,
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2026-03-10',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  })
  const raw = await response.text()
  const data = raw ? (() => { try { return JSON.parse(raw) } catch { return raw } })() : null
  if (!response.ok) {
    const detail = typeof data === 'object' && data ? (data.message ?? JSON.stringify(data)) : String(data ?? response.statusText)
    throw new Error(`GitHub API ${response.status}: ${detail}`)
  }
  return data
}

const server = new McpServer({
  name: 'nova-control',
  version: '0.1.0',
})

server.registerTool(
  'get_pages_status',
  {
    title: 'Get GitHub Pages status',
    description: 'Read the current GitHub Pages configuration for powerx911/NOVA.',
    inputSchema: {},
  },
  async () => {
    try {
      const result = await githubRequest(`/repos/${OWNER}/${REPO}/pages`)
      return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      if (message.includes('GitHub API 404')) {
        return { content: [{ type: 'text', text: JSON.stringify({ enabled: false, message: 'GitHub Pages is not configured for this repository.' }) }] }
      }
      throw error
    }
  },
)

server.registerTool(
  'enable_pages',
  {
    title: 'Enable GitHub Pages',
    description: 'Enable GitHub Pages for powerx911/NOVA using GitHub Actions on main. This changes repository settings.',
    inputSchema: { confirm: z.literal(true).describe('Must be true to confirm changing Pages settings.') },
  },
  async () => {
    const payload = { build_type: 'workflow', source: { branch: DEFAULT_BRANCH, path: '/' } }
    let current = null
    try {
      current = await githubRequest(`/repos/${OWNER}/${REPO}/pages`)
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      if (!message.includes('GitHub API 404')) throw error
    }
    const result = current
      ? await githubRequest(`/repos/${OWNER}/${REPO}/pages`, 'PUT', payload)
      : await githubRequest(`/repos/${OWNER}/${REPO}/pages`, 'POST', payload)
    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          success: true,
          operation: current ? 'updated' : 'created',
          repository: `${OWNER}/${REPO}`,
          build_type: 'workflow',
          source: payload.source,
          result,
        }, null, 2),
      }],
    }
  },
)

server.registerTool(
  'dispatch_pages_workflow',
  {
    title: 'Run Pages workflow',
    description: 'Manually start the pages.yml GitHub Actions workflow on main for powerx911/NOVA.',
    inputSchema: { confirm: z.literal(true).describe('Must be true to confirm starting the workflow.') },
  },
  async () => {
    await githubRequest(`/repos/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches`, 'POST', { ref: DEFAULT_BRANCH })
    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ success: true, workflow: WORKFLOW_FILE, ref: DEFAULT_BRANCH, message: 'Workflow dispatch accepted by GitHub. Check workflow runs for the final result.' }, null, 2),
      }],
    }
  },
)

server.registerTool(
  'list_pages_workflow_runs',
  {
    title: 'List Pages workflow runs',
    description: 'List recent GitHub Actions runs for pages.yml, including status and conclusion.',
    inputSchema: { per_page: z.number().int().min(1).max(50).optional().default(10) },
  },
  async ({ per_page }) => {
    const result = await githubRequest(`/repos/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}/runs?per_page=${per_page}`)
    const runs = Array.isArray(result?.workflow_runs) ? result.workflow_runs.map((run: Record<string, unknown>) => ({
      id: run.id,
      name: run.name,
      event: run.event,
      status: run.status,
      conclusion: run.conclusion,
      html_url: run.html_url,
      created_at: run.created_at,
      updated_at: run.updated_at,
      head_branch: run.head_branch,
      head_sha: run.head_sha,
    })) : []
    return { content: [{ type: 'text', text: JSON.stringify({ total_count: result?.total_count ?? runs.length, workflow_runs: runs }, null, 2) }] }
  },
)

server.registerTool(
  'get_pages_workflow_run_jobs',
  {
    title: 'Inspect Pages workflow jobs',
    description: 'Read job and step status for a specific Pages workflow run.',
    inputSchema: { run_id: z.number().int().positive() },
  },
  async ({ run_id }) => {
    const result = await githubRequest(`/repos/${OWNER}/${REPO}/actions/runs/${run_id}/jobs?per_page=100`)
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] }
  },
)

const app = new Hono().basePath('/nova-control')

app.get('/health', (c) => c.json({ ok: true, service: 'nova-control-mcp', repository: `${OWNER}/${REPO}` }))

app.all('*', async (c) => {
  const expected = Deno.env.get('NOVA_MCP_ACCESS_TOKEN')
  const authorization = c.req.header('authorization') ?? ''
  const supplied = authorization.startsWith('Bearer ') ? authorization.slice(7) : ''
  if (!expected || !supplied || !constantTimeEqual(supplied, expected)) {
    return c.json({ error: 'Unauthorized' }, 401, { 'WWW-Authenticate': 'Bearer' })
  }

  const transport = new WebStandardStreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true,
  })
  await server.connect(transport)
  return transport.handleRequest(c.req.raw)
})

Deno.serve(app.fetch)
