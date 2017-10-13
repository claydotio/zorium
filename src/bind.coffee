_debounce = require 'lodash/debounce'
isThunk = require 'virtual-dom/vnode/is-thunk'

z = require './z'
render = require './render'
isComponent = require './is_component'
ZThunk = require './z_thunk'
isZThunk = require './is_z_thunk'

module.exports = ($$root, tree) ->
  if isComponent tree
    tree = z tree

  # TODO: support trees, not just components
  unless isZThunk tree
    throw new Error 'Passed a tree, not a component'

  onchange = _debounce ->
    render $$root, new ZThunk {
      component: tree.component
      props: tree.props
    }

  tree.component.__onDirty = onchange

  # for full-page rendering, root node is never mounted
  $$root.__disposable?.dispose()
  $$root.__disposable = tree.component.state?.subscribe onchange

  render $$root, new ZThunk {
    component: tree.component
    props: tree.props
  }
