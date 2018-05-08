# parseFromString polyfill for Android 4.1 and 4.3
# required for vdom-parser
# source: https://gist.github.com/eligrey/1129031
if window?
  do (DOMParser = window.DOMParser) ->
    DOMParser_proto = DOMParser.prototype
    real_parseFromString = DOMParser_proto.parseFromString
    # Firefox/Opera/IE throw errors on unsupported types
    try
      # WebKit returns null on unsupported types
      if (new DOMParser()).parseFromString('', 'text/html')
        # text/html parsing is natively supported
        return
    catch ex

    # coffeelint: disable=missing_fat_arrows
    DOMParser_proto.parseFromString = (markup, type) ->
      if /^\s*text\/html\s*(?:;|$)/i.test(type)
        doc = document.implementation.createHTMLDocument('')
        if markup.toLowerCase().indexOf('<!doctype') > -1
          doc.documentElement.innerHTML = markup
        else
          doc.body.innerHTML = markup
        doc
      else
        real_parseFromString.apply this, arguments
    # coffeelint: enable=missing_fat_arrows
    return

_filter = require 'lodash/filter'
_findIndex = require 'lodash/findIndex'
_isEmpty = require 'lodash/isEmpty'
_map = require 'lodash/map'
_debounce = require 'lodash/debounce'
diff = require 'virtual-dom/diff'
patch = require 'virtual-dom/patch'
isThunk = require 'virtual-dom/vnode/is-thunk'

if window?
  parser = require 'vdom-parser'

z = require './z'
isComponent = require './is_component'

flatten = (node) ->
  if isThunk node
    node.render()
  else
    node

parseFullTree = (tree) ->
  unless tree?.tagName is 'HTML' and tree.children.length is 2
    throw new Error 'Invalid HTML base element'

  $head = tree.children[0]
  body = flatten tree.children[1]
  root = flatten body.children[0]

  unless body?.tagName is 'BODY' and root?.properties.id is 'zorium-root'
    throw new Error 'Invalid BODY base element'

  return {
    $root: root
    $head: $head
  }

assert = (isTrue, message) ->
  unless isTrue?
    throw new Error message

renderHead = ($head) ->
  head = flatten $head

  assert head?.tagName is 'HEAD', 'Invalid HEAD base element, not type <head>'

  title = head.children?[0]?.children?[0]?.text

  assert title?, 'Invalid HEAD base element, missing title'

  if document.title isnt title
    document.title = title

  current = _filter document.head.__lastTree.children, (node) ->
    node?.tagName in ['META', 'LINK', 'STYLE', 'SCRIPT']

  $current = document.head.querySelectorAll 'meta,link,style,script'

  next = _filter head.children, (node) ->
    node?.tagName in ['META', 'LINK', 'STYLE', 'SCRIPT']

  if _isEmpty next
    return null

  usedNodes = []

  _map next, (nextNode) ->
    nodeIndex = _findIndex current, ({properties}) ->
      properties.id is nextNode.properties.id
    if nodeIndex is -1 or usedNodes.indexOf(nodeIndex) isnt -1
      nodeIndex = _findIndex current, ({properties}) ->
        properties.property is nextNode.properties.property
    if nodeIndex is -1 or usedNodes.indexOf(nodeIndex) isnt -1
      nodeIndex = _findIndex current, ({properties}) ->
        properties.name is nextNode.properties.name
    if nodeIndex is -1 or usedNodes.indexOf(nodeIndex) isnt -1
      nodeIndex = _findIndex current, ({tagName}, i) ->
        tagName is nextNode.tagName and usedNodes.indexOf(i) is -1

    usedNodes.push nodeIndex

    $currentNode = $current[nodeIndex]
    currentNode = current[nodeIndex]

    unless nextNode and currentNode
      return

    _map nextNode.properties, (val, key) ->
      hasChanged = if key is 'innerHTML' \
                   then $currentNode[key] isnt val
                   else currentNode.properties[key] isnt val
      if hasChanged
        $currentNode[key] = val

  document.head.__lastTree = head

module.exports = render = ($$root, tree) ->
  if isComponent tree
    tree = z tree

  if isThunk tree
    rendered = tree.render()
    if rendered?.tagName is 'HTML'
      {$root, $head} = parseFullTree(rendered)

      document.head.__lastTree = parser document.head

      hasState = $head.component?.state?
      onchange = _debounce (val) ->
        renderHead $head

      if hasState and not $head.component.__disposable
        $head.component.__disposable = $head.component.state.subscribe onchange

      tree = $root

  unless $$root._zorium_tree?
    seedTree = parser $$root
    $$root._zorium_tree = seedTree

  previousTree = $$root._zorium_tree

  patches = diff previousTree, tree
  patch $$root, patches
  $$root._zorium_tree = tree

  return $$root
