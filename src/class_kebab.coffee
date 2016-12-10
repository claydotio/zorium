_map = require 'lodash/map'
_keys = require 'lodash/keys'
_pick = require 'lodash/pick'
_identity = require 'lodash/identity'
_kebabCase = require 'lodash/kebabCase'

module.exports = (classes) ->
  _map _keys(_pick classes, _identity), _kebabCase
  .join ' '
