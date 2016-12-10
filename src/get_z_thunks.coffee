_flatten = require 'lodash/flatten'
_map = require 'lodash/map'
isZThunk = require './is_z_thunk'

module.exports = getZThunks = (tree) ->
  if isZThunk tree
    [tree]
  else
    _flatten _map tree.children, getZThunks
