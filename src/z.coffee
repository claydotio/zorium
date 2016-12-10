_isString = require 'lodash/isString'
_isNumber = require 'lodash/isNumber'
_isArray = require 'lodash/isArray'
_isBoolean = require 'lodash/isBoolean'
_isObject = require 'lodash/isObject'
_filter = require 'lodash/filter'
_map = require 'lodash/map'
h = require 'virtual-dom/h'
isVNode = require 'virtual-dom/vnode/is-vnode'
isVText = require 'virtual-dom/vnode/is-vtext'
isWidget = require 'virtual-dom/vnode/is-widget'
isThunk = require 'virtual-dom/vnode/is-thunk'

isComponent = require './is_component'
ZThunk = require './z_thunk'

isChild = (x) ->
  isVNode(x) or
  _isString(x) or
  isComponent(x) or
  _isNumber(x) or
  _isBoolean(x) or
  isVText(x) or
  isWidget(x) or
  isThunk(x)

isChildren = (x) ->
  _isArray(x) or isChild(x)

parseZfuncArgs = (tagName, children...) ->
  props = {}

  # children[0] is props
  if children[0] and not isChildren children[0]
    props = children[0]
    children.shift()

  if children[0] and _isArray children[0]
    children = children[0]

  if _isArray tagName
    return {tagName: null, props, children: tagName}

  if _isObject tagName
    return {child: tagName, props}

  return {tagName, props, children}

renderChild = (child, props = {}) ->
  if isComponent child
    return new ZThunk {component: child, props}

  if isThunk(child) and child.component?
    return renderChild child.component, child.props

  if _isNumber(child)
    return '' + child

  if _isBoolean(child)
    return null

  if _isArray(child)
    return _filter child, (subChild) ->
      not _isBoolean subChild

  return child

module.exports = z = ->
  {child, tagName, props, children} = parseZfuncArgs.apply null, arguments

  if child?
    return renderChild child, props

  return h tagName, props, _map children, renderChild
