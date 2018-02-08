_flatten = require 'lodash/flatten'
_mapValues = require 'lodash/mapValues'
_isFunction = require 'lodash/isFunction'
_isPlainObject = require 'lodash/isPlainObject'
_map = require 'lodash/map'
_bind = require 'lodash/bind'
_defaults = require 'lodash/defaults'
RxBehaviorSubject = require('rxjs/BehaviorSubject').BehaviorSubject
RxObservable = require('rxjs/Observable').Observable
require 'rxjs/observable/of'
require 'rxjs/observable/combineLatest'
# doesn't seem to work properly. https://github.com/ReactiveX/rxjs/issues/2554
# require 'rxjs/operator/concat'
concat = require('rxjs/operator/concat').concat
RxObservable.prototype.concat = concat

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
  RxObservable.combineLatest _flatten(observables), (results...) -> results

subjectFromInitialState = (initialState) ->
  new RxBehaviorSubject _mapValues initialState, (val) ->
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

      RxObservable.of(null).concat val.do (update) ->
        unless hasSettled
          pendingSettlement -= 1
          hasSettled = true

        currentState = stateSubject.getValue()
        if currentState[key] isnt update
          stateSubject.next _defaults {
            "#{key}": update
          }, currentState
    else
      RxObservable.of null
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
  state._onStable = (timeout) ->
    if stablePromise?
      return stablePromise
    stablePromise = new Promise (resolve) ->
      hasSettled = false
      state._disposeOnStable = state.subscribe ->
        if pendingSettlement is 0 and not hasSettled
          hasSettled = true
          resolve()
      if timeout
        setTimeout (-> state._disposeOnStable?.unsubscribe()), timeout
    .catch (err) ->
      # disposing here server-side breaks cache?
      # not disposing creates server-side memory leak
      # if window?
      state._disposeOnStable?.unsubscribe()
      delete state._disposeOnStable
      throw err
    .then ->
      # disposing here server-side breaks cache?
      # not disposing is server-side memory leak
      # if window?
      state._disposeOnStable.unsubscribe()
      delete state._disposeOnStable
      return null

  return state
