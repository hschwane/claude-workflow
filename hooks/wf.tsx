import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { WfBoard, WfSpec, WfStatus } from '../types'

const PANE = 'specs'
const USAGE_TOOL = 'mcp__wf__wf_usage'
const SPECS_DIR = 'docs/specs'
const ORDER: WfStatus[] = ['in-progress', 'ready', 'draft', 'done']
const STATUSES = new Set<string>(ORDER)
const NO_SPECS = 'This project keeps no spec files (spec-mode: none). Specs live in the conversation.'

const board = atom(
  { plugin: 'wf', key: 'board' } as const,
  { specs: [], unreadable: [], isLoaded: false } as WfBoard,
)
const selected = atom({ plugin: 'wf', key: 'selected' } as const, [] as string[])
const showDone = atom({ plugin: 'wf', key: 'showDone' } as const, false)

type Loaded = Pick<WfBoard, 'specs' | 'unreadable' | 'message'>

const errorText = (err: unknown) => (err instanceof Error ? err.message : String(err)).split('\n')[0] ?? 'unknown error'

/** Minimal YAML frontmatter: flat `key: value` lines, quotes and trailing comments stripped. */
export function parseFrontmatter(text: string): Record<string, string> | undefined {
  const lines = text.replace(/^﻿/, '').split(/\r?\n/)
  if (lines[0]?.trim() !== '---') return undefined
  const end = lines.indexOf('---', 1)
  if (end === -1) return undefined
  const out: Record<string, string> = {}
  for (const line of lines.slice(1, end)) {
    if (line.trim() === '' || line.trim().startsWith('#')) continue
    const m = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line)
    if (!m) return undefined
    let value = (m[2] ?? '').trim()
    const quoted = /^(["'])(.*?)\1/.exec(value)
    value = quoted ? (quoted[2] ?? '') : value.replace(/\s+#.*$/, '')
    out[m[1] as string] = value
  }
  return out
}

export function specModeOf(claudeMd: string): string | undefined {
  const block = /<!--\s*wf:settings\s*-->([\s\S]*?)<!--\s*\/wf:settings\s*-->/.exec(claudeMd)
  if (!block) return undefined
  const mode = /^\s*-\s*spec-mode:\s*([A-Za-z-]+)/m.exec(block[1] ?? '')
  return mode?.[1]
}

async function loadFiles($: EngineInterface): Promise<Loaded> {
  let top
  try {
    top = await $.fs.list(SPECS_DIR)
  } catch (err) {
    return { specs: [], unreadable: [], message: `Cannot read ${SPECS_DIR}: ${errorText(err)}` }
  }
  const files: string[] = []
  for (const entry of top) {
    if (entry.kind === 'file' && entry.name.endsWith('.md')) files.push(`${SPECS_DIR}/${entry.name}`)
    if (entry.kind !== 'dir') continue
    try {
      for (const sub of await $.fs.list(`${SPECS_DIR}/${entry.name}`)) {
        if (sub.kind === 'file' && sub.name.endsWith('.md')) files.push(`${SPECS_DIR}/${entry.name}/${sub.name}`)
      }
    } catch (err) {
      return { specs: [], unreadable: [], message: `Cannot read ${SPECS_DIR}/${entry.name}: ${errorText(err)}` }
    }
  }
  files.sort()
  const specs: WfSpec[] = []
  const unreadable: Loaded['unreadable'] = []
  for (const file of files) {
    try {
      const text = await $.fs.read(file)
      const fm = typeof text === 'string' ? parseFrontmatter(text) : undefined
      if (!fm) {
        unreadable.push({ file, reason: 'no valid frontmatter' })
      } else if (!fm.id || !fm.title || !STATUSES.has(fm.status ?? '')) {
        unreadable.push({ file, reason: 'frontmatter needs id, title and a status of draft|ready|in-progress|done' })
      } else {
        specs.push({ id: fm.id, title: fm.title, status: fm.status as WfStatus })
      }
    } catch (err) {
      unreadable.push({ file, reason: errorText(err) })
    }
  }
  return { specs, unreadable }
}

type GhIssue = { number: number; title: string; state: string; labels: { name: string }[] }

async function loadIssues($: EngineInterface): Promise<Loaded> {
  const argv = ['gh', 'issue', 'list', '--label', 'wf-spec', '--state', 'all', '--json', 'number,title,labels,state', '--limit', '200']
  let run
  try {
    run = await $.process.run(argv)
  } catch (err) {
    return { specs: [], unreadable: [], message: `gh is not available: ${errorText(err)}` }
  }
  if (run.exitCode !== 0) {
    const why = run.stderr.trim().split('\n')[0] || `exit code ${run.exitCode}`
    return { specs: [], unreadable: [], message: `gh issue list failed: ${why}` }
  }
  let issues: GhIssue[]
  try {
    issues = JSON.parse(run.stdout) as GhIssue[]
    if (!Array.isArray(issues)) throw new Error('not a list')
  } catch (err) {
    return { specs: [], unreadable: [], message: `gh answered something unreadable: ${errorText(err)}` }
  }
  const specs = issues.map((issue): WfSpec => {
    const labels = (issue.labels ?? []).map(l => l.name)
    const status: WfStatus =
      String(issue.state).toLowerCase() === 'closed' ? 'done'
      : labels.includes('wf:in-progress') ? 'in-progress'
      : labels.includes('wf:ready') ? 'ready'
      : 'draft'
    return { id: `#${issue.number}`, title: issue.title, status }
  })
  return { specs, unreadable: [] }
}

async function loadBoard($: EngineInterface): Promise<Loaded> {
  let claudeMd: unknown
  try {
    claudeMd = await $.fs.read('CLAUDE.md')
  } catch {
    return { specs: [], unreadable: [], message: NO_SPECS }
  }
  const mode = typeof claudeMd === 'string' ? specModeOf(claudeMd) : undefined
  if (mode === 'files') return loadFiles($)
  if (mode === 'issues') return loadIssues($)
  if (mode === undefined || mode === 'none') return { specs: [], unreadable: [], message: NO_SPECS }
  return { specs: [], unreadable: [], message: `Unknown spec-mode "${mode}" in CLAUDE.md (expected none, files or issues).` }
}

async function refresh($: EngineInterface) {
  let loaded: Loaded
  try {
    loaded = await loadBoard($)
  } catch (err) {
    loaded = { specs: [], unreadable: [], message: `Could not load specs: ${errorText(err)}` }
  }
  const ids = new Set(loaded.specs.map(s => s.id))
  await update($, board, () => ({ ...loaded, isLoaded: true }))
  await update($, selected, list => list.filter(id => ids.has(id)))
}

/** The board as plain text, for where no surface draws the pane. */
export function boardText(data: WfBoard): string {
  if (data.message !== undefined) return data.message
  if (data.specs.length === 0 && data.unreadable.length === 0) return 'No specs yet.'
  const lines: string[] = []
  for (const status of ORDER) {
    const specs = data.specs.filter(s => s.status === status)
    if (specs.length === 0) continue
    lines.push(`${status} (${specs.length})`)
    for (const spec of specs) lines.push(`  ${spec.id}  ${spec.title}`)
  }
  for (const u of data.unreadable) lines.push(`unreadable: ${u.file}: ${u.reason}`)
  lines.push('', 'Deliver with /wf:deliver <id> [<id> …]')
  return lines.join('\n')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'wf_usage',
      description:
        'Current subscription rate-limit usage (5-hour and 7-day windows, percent used, reset time). Used by /wf:gauntlet to stay within a weekly budget.',
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })
    await $.command.register({ name: 'board', description: 'Open the spec board: pick specs and deliver them' })
    return next(e)
  })

  on('tool.call', { tool: USAGE_TOOL }, async $ => {
    const { rateLimits } = await $.session.usage()
    return {
      result: JSON.stringify({
        rateLimits,
        note: 'empty when not on a subscription or before the first response',
      }),
    }
  }).catch(() => ({ deny: 'wf_usage: could not read the usage windows' }))

  on('command.run', { command: 'board' }, async $ => {
    const opened = await $.ui.open({ id: PANE, title: 'Specs' })
    await refresh($)
    if (opened.isPlaced) return { text: 'Spec board opened.' }
    // No surface draws the pane (a cloud session followed in the app attaches none): say so,
    // and give the board as text so the command is still useful there.
    return { text: `Spec board not shown: ${opened.reason}\n\n${boardText(await read($, board))}` }
  })

  on('tool.call', async ($, e, next) => {
    const ran = await next(e)
    if (e.tool !== 'Write' && e.tool !== 'Edit') return ran
    const path = (e as { file_path?: unknown }).file_path
    if (typeof path === 'string' && /(^|\/)docs\/specs\//.test(path)) await refresh($)
    return ran
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const data = await read($, board)
    const chosen = await read($, selected)
    const isDoneShown = await read($, showDone)

    const submit = async () => {
      const ids = await read($, selected)
      if (ids.length === 0) return
      const line = `/wf:deliver ${ids.join(' ')}`
      // $.prompt.submit refuses text that starts with "/", so the skill is run as a command.
      $.command.run({ command: 'wf:deliver', args: ids.join(' ') }).catch(err => $.ui.toast(`${line} failed: ${errorText(err)}`))
      await update($, selected, () => [])
      $.ui.toast(`Sent ${line}`)
    }
    const toggle = (id: string) => update($, selected, list => (list.includes(id) ? list.filter(x => x !== id) : [...list, id]))

    const actions = (
      <Box flexDirection="row" gap={1}>
        {chosen.length > 0 ? (
          <Button key="deliver" variant="primary" onPress={() => void submit()}>
            {`Deliver selected (${chosen.length})`}
          </Button>
        ) : (
          <Text dimColor>Deliver selected</Text>
        )}
        <Button key="refresh" onPress={() => void refresh($)}>
          Refresh
        </Button>
      </Box>
    )

    if (!data.isLoaded) {
      return (
        <Box flexDirection="column">
          <Text dimColor>Loading specs...</Text>
          {actions}
        </Box>
      )
    }
    if (data.message !== undefined) {
      return (
        <Box flexDirection="column">
          <Text>{data.message}</Text>
          {actions}
        </Box>
      )
    }

    const row = (spec: WfSpec) => (
      <Button key={`spec-${spec.id}`} plain onPress={() => void toggle(spec.id)}>
        {`${chosen.includes(spec.id) ? '[x]' : '[ ]'} ${spec.id} ${spec.title}`}
      </Button>
    )
    const group = (status: WfStatus) => data.specs.filter(s => s.status === status)

    return (
      <Box flexDirection="column">
        {actions}
        {data.specs.length === 0 && data.unreadable.length === 0 && <Text dimColor>No specs yet.</Text>}
        {ORDER.filter(s => s !== 'done').map(status => {
          const specs = group(status)
          if (specs.length === 0) return null
          return (
            <Box key={`group-${status}`} flexDirection="column">
              <Text bold>{`${status} (${specs.length})`}</Text>
              {specs.map(row)}
            </Box>
          )
        })}
        {group('done').length > 0 && (
          <Box key="group-done" flexDirection="column">
            <Text bold>{`done (${group('done').length})`}</Text>
            <Button key="toggle-done" onPress={() => void update($, showDone, v => !v)}>
              {isDoneShown ? 'Hide done' : 'Show done'}
            </Button>
            {isDoneShown && group('done').map(row)}
          </Box>
        )}
        {data.unreadable.length > 0 && (
          <Box key="group-unreadable" flexDirection="column">
            <Text bold>{`unreadable (${data.unreadable.length})`}</Text>
            {data.unreadable.map(u => (
              <Text key={`unreadable-${u.file}`} dimColor>{`${u.file}: ${u.reason}`}</Text>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}
