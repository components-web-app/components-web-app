import Quill from 'quill'

const Parchment = Quill.import('parchment')

const SizeClass = new Parchment.Attributor.Class('size', 'is-size', {
  scope: Parchment.Scope.INLINE,
  whitelist: ['1', '2', '3', '4', '5', '6', '7']
})
Quill.register(SizeClass, true)

const ThemeColorClass = new Parchment.Attributor.Class(
  'theme-color',
  'has-text',
  {
    scope: Parchment.Scope.INLINE,
    whitelist: ['primary', 'success']
  }
)
Quill.register(ThemeColorClass, true)

// class conflict with hast-text above
// const AlignClass = new Parchment.Attributor.Class('align', 'has-text', {
//   scope: Parchment.Scope.BLOCK,
//   whitelist: ['right', 'center', 'justify']
// })
// Quill.register(AlignClass)
