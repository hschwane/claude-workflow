export type WfStatus = 'draft' | 'ready' | 'in-progress' | 'done'

export type WfSpec = {
  id: string
  title: string
  status: WfStatus
}

export type WfBoard = {
  specs: WfSpec[]
  /** Spec files whose frontmatter could not be read: `{ file, reason }`. */
  unreadable: { file: string; reason: string }[]
  /** One line shown instead of the list when specs could not be loaded at all. */
  message?: string
  isLoaded: boolean
}

declare module 'claude-code' {
  interface PluginState {
    wf: {
      board: WfBoard
      selected: string[]
      showDone: boolean
    }
  }
}
