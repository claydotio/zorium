_map = require 'lodash/map'
isThunk = require 'virtual-dom/vnode/is-thunk'

# TODO: use native promises, upgrade node
if window?
  Promise = window.Promise
else
  # Avoid webpack include
  _promiz = 'promiz'
  Promise = global.Promise or require _promiz

z = require './z'
isComponent = require './is_component'
getZThunks = require './get_z_thunks'

untilStable = (zthunk, timeout) ->
  state = zthunk.component.state

  # Begin resolving children before current node is stable for performance
  # TODO: test performance assumption
  try
    children = getZThunks zthunk.render()
    Promise.all _map children, (zthunk) ->
      untilStable zthunk, timeout
  catch err
    return Promise.reject err

  onStable = if state? then state._onStable else (-> Promise.resolve null)
  onStable(timeout).then ->
    children = getZThunks zthunk.render()
    Promise.all _map children, (zthunk) ->
      untilStable zthunk, timeout
  .then -> zthunk

module.exports = (tree, {timeout} = {}) ->
  if isComponent tree
    tree = z tree

  return new Promise (resolve, reject) ->
    zthunks = getZThunks(tree)
    if timeout?
      setTimeout ->
        reject new Error "Timeout, request took longer than #{timeout}ms"
      , timeout

    Promise.all _map zthunks, (zthunk) ->
      untilStable zthunk, timeout
    .then resolve
    .catch reject
