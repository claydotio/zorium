_isObject = require 'lodash/isObject'
_isFunction = require 'lodash/isFunction'
isThunk = require 'virtual-dom/vnode/is-thunk'

module.exports = (x) ->
  _isObject(x) and _isFunction(x.render) and not isThunk x
