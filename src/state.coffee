_flatten = require 'lodash/flatten'
_mapValues = require 'lodash/mapValues'
_isFunction = require 'lodash/isFunction'
_isPlainObject = require 'lodash/isPlainObject'
_map = require 'lodash/map'
_bind = require 'lodash/bind'
_defaults = require 'lodash/defaults'
Rx = require 'rxjs'

# TODO: use native promises, upgrade node
if window?
  Promise = window.Promise
else
  # Avoid webpack include
  _promiz = 'promiz'
  Promise = global.Promise or require _promiz

assert = require './assert'

# TODO: move to util?
forkJoin = (observables...) ->
  Rx.Observable.combineLatest _flatten(observables), (results...) -> results

subjectFromInitialState = (initialState) ->
  new Rx.BehaviorSubject _mapValues initialState, (val) ->
    if val?.subscribe?
      # BehaviorSubject
      if _isFunction val.getValue
        try
          val.getValue()
        catch
          null
      else
        null
    else
      val

# TODO: fix cyclomatic complexity
module.exports = (initialState) ->
  assert _isPlainObject(initialState), 'initialState must be a plain object'

  pendingSettlement = 0
  stateSubject = subjectFromInitialState initialState

  state = forkJoin _map initialState, (val, key) ->
    if val?.subscribe?
      pendingSettlement += 1
      hasSettled = false

      Rx.Observable.of(null).concat val.do (update) ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true

        currentState = stateSubject.getValue()
        if currentState[key] isnt update
          stateSubject.next _defaults {
            "#{key}": update
          }, currentState
    else
      Rx.Observable.of null
  .switchMap -> stateSubject

  state.getValue = _bind stateSubject.getValue, stateSubject
  state.set = (diff) ->
    assert _isPlainObject(diff), 'diff must be a plain object'

    currentState = stateSubject.getValue()

    _map diff, (val, key) ->
      if initialState[key]?.subscribe?
        throw new Error 'Attempted to set observable value'
      else
        if currentState[key] isnt val
          currentState[key] = val

    stateSubject.next currentState

  stablePromise = null
  state._onStable = ->
    if stablePromise?
      return stablePromise
    disposable = null
    stablePromise = new Promise (resolve) ->
      hasSettled = false
      # TODO: make sure this doesn't leak server-side
      disposable = state.subscribe ->
        if pendingSettlement is 0 and not hasSettled
          hasSettled = true
          resolve()
    .catch (err) ->
      # disposing here server-side breaks cache
      if window?
        disposable?.unsubscribe()
      throw err
    .then ->
      # disposing here server-side breaks cache
      if window?
        disposable.unsubscribe()
      return null

  return state
