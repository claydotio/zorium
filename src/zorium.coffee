_assign = require 'lodash/assign'

# Bind polyfill (phantomjs doesn't support bind)
# coffeelint: disable=missing_fat_arrows
unless Function::bind
  Function::bind = (oThis) ->

    # closest thing possible to the ECMAScript 5
    # internal IsCallable function
    throw new TypeError(
      'Function.prototype.bind - what is trying to be bound is not callable'
    ) if typeof this isnt 'function'
    aArgs = Array::slice.call(arguments, 1)
    fToBind = this
    fNOP = -> null

    fBound = ->
      fToBind.apply(
        (if this instanceof fNOP and oThis then this else oThis),
        aArgs.concat(Array::slice.call(arguments))
      )

    fNOP:: = @prototype
    fBound:: = new fNOP()
    fBound
# coffeelint: enable=missing_fat_arrows

# requestAnimationFrame polyfill
# https://gist.github.com/paulirish/1579671
# MIT license
if window?
  do ->
    lastTime = 0
    vendors = [
      'ms'
      'moz'
      'webkit'
      'o'
    ]
    x = 0
    while x < vendors.length and not window.requestAnimationFrame
      window.requestAnimationFrame =
        window[vendors[x] + 'RequestAnimationFrame']
      window.cancelAnimationFrame =
        window[vendors[x] + 'CancelAnimationFrame'] or
        window[vendors[x] + 'CancelRequestAnimationFrame']
      x += 1
    if not window.requestAnimationFrame

      window.requestAnimationFrame = (callback, element) ->
        currTime = (new Date()).getTime()
        timeToCall = Math.max(0, 16 - (currTime - lastTime))
        id = window.setTimeout((->
          callback currTime + timeToCall
          return
        ), timeToCall)
        lastTime = currTime + timeToCall
        id

    if not window.cancelAnimationFrame

      window.cancelAnimationFrame = (id) ->
        clearTimeout id
        return

    return
  # end polyfill

z = require './z'
render = require './render'
renderToString = require './render_to_string'
router = require './router'
state = require './state'
ev = require './ev'
classKebab = require './class_kebab'
isSimpleClick = require './is_simple_click'
bind = require './bind'
untilStable = require './until_stable'

_assign z, {
  render
  renderToString
  router
  state
  ev
  classKebab
  isSimpleClick
  bind
  untilStable
}

module.exports = z
