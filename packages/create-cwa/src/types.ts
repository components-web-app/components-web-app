export interface ManifestChoice {
  value: string
  label: string
  hint?: string
  requires?: string[]
  // Pre-selected in a multiselect, and what --yes picks.
  selected?: boolean
}

export interface ManifestQuestion {
  id: string
  type: 'text' | 'select' | 'multiselect' | 'confirm'
  message: string
  placeholder?: string
  hint?: string
  default?: boolean | string
  choices?: ManifestChoice[]
}

export interface ManifestFeature {
  requires?: string[]
  exclude: string[]
}

export interface ManifestCi {
  exclude: string[]
}

export interface Manifest {
  version: string
  repo: string
  // Read only by create-cwa 0.x, which downloads this branch. Newer versions download
  // the tag matching their own version, or --ref.
  branch: string
  alwaysExclude: string[]
  questions: ManifestQuestion[]
  features: Record<string, ManifestFeature>
  ci: Record<string, ManifestCi>
  // Starting content (demo, home, empty): the files each level removes. Missing in templates before 2.0.0-alpha.55.
  content?: Record<string, ManifestCi>
}

export interface Answers {
  projectName: string
  ci: string
  // kubernetes or server; none when there's no pipeline.
  deploy: string
  features: string[]
  content: string
}
