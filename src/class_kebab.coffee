_map = require 'lodash/map'
_keys = require 'lodash/keys'
_pickBy = require 'lodash/pickBy'
_identity = require 'lodash/identity'
_kebabCase = require 'lodash/kebabCase'

module.exports = (classes) ->
  _map _keys(_pickBy classes, _identity), _kebabCase
  .join ' '
