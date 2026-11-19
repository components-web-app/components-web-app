import type { CwaApiDocumentationDataInterface } from '#cwa/storage/stores/api-documentation/state'

export function collectionSourceOptions(docs: CwaApiDocumentationDataInterface | undefined, pageDataConfig: Record<string, { name?: string }> | undefined) {
  const options: { label: string, value: string }[] = []
  for (const { resourceClass } of docs?.pageDataMetadata?.member ?? []) {
    const shortName = resourceClass.split('\\').pop() ?? resourceClass
    const endpoint = (docs?.entrypoint as Record<string, string> | undefined)?.[shortName.charAt(0).toLowerCase() + shortName.slice(1)]
    if (endpoint) {
      options.push({ label: pageDataConfig?.[shortName]?.name ?? shortName, value: endpoint })
    }
  }
  return options
}
