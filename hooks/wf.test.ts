import { describe, expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

const SURFACES = ['terminal', 'desktop'] as const
const PANE = { plugin: 'wf', component: 'Pane', requestId: 'specs' } as const
const PANE_PROPS = { title: 'Specs', bodyColumns: 80, dock: true } as never

const spec = (id: string, title: string, status: string) => `---\nid: ${id}\ntitle: "${title}"\nstatus: ${status}  # comment\n---\nbody\n`

const SPECS: Record<string, string> = {
  'docs/specs/a.md': spec('S-001', 'First', 'ready'),
  'docs/specs/b.md': spec('S-002', 'Second', 'in-progress'),
  'docs/specs/c.md': spec('S-003', 'Third', 'draft'),
  'docs/specs/old/d.md': spec('S-004', 'Fourth', 'done'),
  'docs/specs/broken.md': 'no frontmatter here\n',
  'docs/specs/badstatus.md': spec('S-005', 'Bad', 'wip'),
}

const settings = (mode: string) => `# Proj\n\n<!-- wf:settings -->\n- spec-mode: ${mode}        # none | files | issues\n<!-- /wf:settings -->\n`

// Everything beneath the plugin is the engine's: answer the nouns the module reaches.
// Relative paths reach the engine resolved against the working directory; the table is keyed by the project-relative form.
const rel = (path: string) => path.replace(/^.*?(?=CLAUDE\.md$|docs\/specs)/, '')

function world(on: On, files: Record<string, string>, dirs: Record<string, { name: string; kind: 'file' | 'dir' }[]>) {
  const submitted: string[] = []
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('fs.read', (_$, e) => {
    const text = files[rel(e.path)]
    return text === undefined ? { deny: `ENOENT ${rel(e.path)}` } : { value: text }
  })
  on('fs.list', (_$, e) => {
    const entries = dirs[rel(e.path)]
    if (entries === undefined) return { deny: `ENOENT ${rel(e.path)}` }
    return { value: entries.map(x => ({ ...x, size: 0, mtimeMs: 0, isLink: false })) }
  })
  on('tool.register', (_$, e) => ({ value: { tool: `mcp__wf__${e.name}` } }))
  on('command.register', (_$, e) => ({ value: { command: e.name } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('command.run', (_$, e) => {
    submitted.push(`/${e.command} ${e.args}`)
    return {}
  })
  return submitted
}

const TREE: Record<string, { name: string; kind: 'file' | 'dir' }[]> = {
  'docs/specs': [
    { name: 'a.md', kind: 'file' },
    { name: 'b.md', kind: 'file' },
    { name: 'c.md', kind: 'file' },
    { name: 'broken.md', kind: 'file' },
    { name: 'badstatus.md', kind: 'file' },
    { name: 'old', kind: 'dir' },
  ],
  'docs/specs/old': [{ name: 'd.md', kind: 'file' }],
}

async function openBoard($: Engine, surface: (typeof SURFACES)[number]) {
  await $.command.run({ command: 'board', args: '' } as never)
  return $.ui.mount({ ...PANE, surface, props: PANE_PROPS })
}

describe('spec board', () => {
  test('files mode lists specs by status, done collapsed, unreadable by filename', async ($, on) => {
    world(on, { 'CLAUDE.md': settings('files'), ...SPECS }, TREE)
    await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true } as never)
    for (const surface of SURFACES) {
      const ui = await openBoard($, surface)
      const texts = (await ui.findAll({ type: 'Text' })).map(t => t.text)
      expect(texts).toContain('in-progress (1)')
      expect(texts).toContain('ready (1)')
      expect(texts).toContain('draft (1)')
      expect(texts).toContain('done (1)')
      expect(texts).toContain('unreadable (2)')
      expect(texts.some(t => t.startsWith('docs/specs/broken.md'))).toBe(true)
      expect(texts.some(t => t.startsWith('docs/specs/badstatus.md'))).toBe(true)
      expect(await ui.find({ key: 'spec-S-004' })).toBeUndefined()
      await ui.press({ key: 'toggle-done' })
      expect(await ui.find({ key: 'spec-S-004' })).toBeDefined()
      await ui.press({ key: 'toggle-done' })
      expect(await ui.find({ key: 'spec-S-001' })).toMatchObject({ text: '[ ] S-001 First' })
      await ui.unmount()
    }
  })

  test('none mode and a missing CLAUDE.md say so in one line', async ($, on) => {
    const files: Record<string, string> = { 'CLAUDE.md': settings('none') }
    world(on, files, {})
    await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true } as never)
    for (const surface of SURFACES) {
      const ui = await openBoard($, surface)
      expect(await ui.find({ type: 'Text', text: 'This project keeps no spec files (spec-mode: none). Specs live in the conversation.' })).toBeDefined()
      await ui.unmount()
    }
    delete files['CLAUDE.md']
    const ui = await openBoard($, 'terminal')
    expect(await ui.find({ type: 'Text', text: 'spec-mode: none' })).toBeDefined()
    await ui.unmount()
  })

  test('a missing docs/specs shows one line instead of throwing', async ($, on) => {
    world(on, { 'CLAUDE.md': settings('files') }, {})
    await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true } as never)
    const ui = await openBoard($, 'terminal')
    expect(await ui.find({ type: 'Text', text: 'Cannot read docs/specs' })).toBeDefined()
    await ui.unmount()
  })

  test('issues mode maps labels and state; gh failure is one line', async ($, on) => {
    const gh = { exitCode: 0, stdout: '', stderr: '' }
    gh.stdout = JSON.stringify([
      { number: 7, title: 'Open', state: 'OPEN', labels: [{ name: 'wf-spec' }, { name: 'wf:ready' }] },
      { number: 8, title: 'Busy', state: 'OPEN', labels: [{ name: 'wf-spec' }, { name: 'wf:in-progress' }] },
      { number: 9, title: 'Raw', state: 'OPEN', labels: [{ name: 'wf-spec' }] },
      { number: 10, title: 'Shipped', state: 'CLOSED', labels: [{ name: 'wf-spec' }, { name: 'wf:ready' }] },
    ])
    const argvs: (readonly string[])[] = []
    world(on, { 'CLAUDE.md': settings('issues') }, {})
    on('process.run', (_$, e) => {
      argvs.push(e.argv)
      return { value: { ...gh, isStdoutTruncated: false, isStderrTruncated: false } }
    })
    await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true } as never)
    let ui = await openBoard($, 'terminal')
    expect(argvs[0]).toEqual(['gh', 'issue', 'list', '--label', 'wf-spec', '--state', 'all', '--json', 'number,title,labels,state', '--limit', '200'])
    expect(await ui.find({ key: 'spec-#7' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'in-progress (1)' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'done (1)' })).toBeDefined()
    expect(await ui.find({ key: 'spec-#10' })).toBeUndefined()
    gh.exitCode = 1
    gh.stderr = 'gh: To get started with GitHub CLI, please run:  gh auth login\nmore'
    await ui.press({ key: 'refresh' })
    expect(await ui.find({ type: 'Text', text: 'gh issue list failed: gh: To get started' })).toBeDefined()
    await ui.unmount()
  })

  for (const surface of SURFACES) {
    test(`selecting two specs and pressing Deliver submits one command and clears the selection (${surface})`, async ($, on) => {
      const submitted = world(on, { 'CLAUDE.md': settings('files'), ...SPECS }, TREE)
      await $.session.start({ cwd: '/p', surface, isInteractive: true } as never)
      const ui = await openBoard($, surface)
      expect(await ui.find({ key: 'deliver' })).toBeUndefined()
      await ui.press({ key: 'spec-S-001' })
      await ui.press({ key: 'spec-S-002' })
      expect(await ui.find({ key: 'spec-S-002' })).toMatchObject({ text: '[x] S-002 Second' })
      await ui.press({ key: 'deliver' })
      expect(submitted).toEqual(['/wf:deliver S-001 S-002'])
      expect(await ui.find({ key: 'deliver' })).toBeUndefined()
      expect(await ui.find({ key: 'spec-S-001' })).toMatchObject({ text: '[ ] S-001 First' })
      await ui.press({ key: 'spec-S-003' })
      await ui.press({ key: 'gauntlet' })
      expect(submitted[1]).toBe('/wf:gauntlet S-003')
      await ui.unmount()
    })
  }

  test('a Write under docs/specs refreshes the board; other writes and the call itself are untouched', async ($, on) => {
    const files: Record<string, string> = { 'CLAUDE.md': settings('files'), ...SPECS }
    world(on, files, TREE)
    on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)
    await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true } as never)
    const ui = await openBoard($, 'terminal')
    files['docs/specs/c.md'] = spec('S-003', 'Third', 'ready')
    const ran = await $.tool.call({ tool: 'Write', file_path: '/p/docs/specs/c.md', content: 'x' } as never)
    expect(ran).toMatchObject({ text: 'ok' })
    expect(await ui.find({ type: 'Text', text: 'ready (2)' })).toBeDefined()
    await ui.unmount()
  })
})

describe('wf_usage', () => {
  test('answers the rate limits as JSON text', async ($, on) => {
    const registered: { name: string; description: string }[] = []
    on('tool.register', (_$, e) => {
      registered.push(e)
      return { value: { tool: `mcp__wf__${e.name}` } }
    })
    on('command.register', (_$, e) => ({ value: { command: e.name } }))
    on('session.start', (_$, e) => ({ cwd: e.cwd }))
    on('session.usage', () => ({ value: { startedAt: 0, context: {}, rateLimits: [{ kind: 'seven_day', percentUsed: 23.5, resetsAt: '2026-10-20T00:00:00Z' }] } }) as never)
    await $.session.start({ cwd: '/p', surface: 'terminal', isInteractive: true } as never)
    expect(registered[0]?.name).toBe('wf_usage')
    expect(registered[0]?.description).toContain('Used by /wf:gauntlet')
    const out = await $.tool.call({ tool: 'mcp__wf__wf_usage' } as never)
    expect(out.deny).toBeUndefined()
    const parsed = JSON.parse((out as { result: string }).result)
    expect(parsed).toEqual({
      rateLimits: [{ kind: 'seven_day', percentUsed: 23.5, resetsAt: '2026-10-20T00:00:00Z' }],
      note: 'empty when not on a subscription or before the first response',
    })
  })
})
