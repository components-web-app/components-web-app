export interface ManifestChoice {
  value: string
  label: string
  requires?: string[]
}

export interface ManifestQuestion {
  id: string
  type: 'text' | 'select' | 'multiselect' | 'confirm'
  message: string
  placeholder?: string
  hint?: string
  default?: boolean
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
}

export interface Answers {
  projectName: string
  ci: string
  features: string[]
  fixtures: boolean
}
