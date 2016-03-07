_ = require 'lodash'
h = require 'virtual-dom/h'
isVNode = require 'virtual-dom/vnode/is-vnode'
isVText = require 'virtual-dom/vnode/is-vtext'
isWidget = require 'virtual-dom/vnode/is-widget'
isThunk = require 'virtual-dom/vnode/is-thunk'

isComponent = require './is_component'
ZThunk = require './z_thunk'

isChild = (x) ->
  isVNode(x) or
  _.isString(x) or
  isComponent(x) or
  _.isNumber(x) or
  _.isBoolean(x) or
  isVText(x) or
  isWidget(x) or
  isThunk(x)

isChildren = (x) ->
  _.isArray(x) or isChild(x)

parseZfuncArgs = (tagName, children...) ->
  props = {}

  # children[0] is props
  if children[0] and not isChildren children[0]
    props = children[0]
    children.shift()

  if children[0] and _.isArray children[0]
    children = children[0]

  if _.isArray tagName
    return {tagName: null, props, children: tagName}

  if _.isObject tagName
    return {child: tagName, props}

  return {tagName, props, children}

renderChild = (child, props = {}) ->
  if isComponent child
    return new ZThunk {component: child, props}

  if isThunk(child) and child.component?
    return renderChild child.component, child.props

  if _.isNumber(child)
    return '' + child

  if _.isBoolean(child)
    return ''

  return child

module.exports = z = ->
  {child, tagName, props, children} = parseZfuncArgs.apply null, arguments

  if child?
    return renderChild child, props

  return h tagName, props, _.map children, renderChild
