b = require 'b-assert'
Rx = require 'rxjs'

z = require '../src/zorium'

describe 'server side rendering', ->
  if window?
    return

  it 'supports basic render to string', ->
    z.renderToString z 'div', 'test'
    .then (html) ->
      b html, '<div>test</div>'

  it 'supports basic render of component to string', ->
    class Root
      render: ->
        z 'div', 'test'

    z.renderToString new Root()
    .then (html) ->
      b html, '<div>test</div>'

  it 'supports render of component with props to string', ->
    class Root
      render: ({name}) ->
        z 'div', 'test ' + name

    z.renderToString z new Root(), {name: 'abc'}
    .then (html) ->
      b html, '<div>test abc</div>'

  it 'propogates errors', ->
    class MoveAlong
      render: ->
        throw new Error 'test'

    $move = new MoveAlong()
    z.renderToString $move
    .then ->
      throw new Error 'Expected error'
    , (err) ->
      b err.message, 'test'

  it 'supports async rendering to string', ->
    class Async
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: =>
        {abc} = @state.getValue()

        unless abc?
          @pending.next 'abc'

        z 'div', abc

    $async = new Async()
    z.renderToString $async
    .then (html) ->
      b html, '<div>abc</div>'

  it 'supports async rendering to string after sync change', ->
    componentSubject = new Rx.ReplaySubject(1)

    class AsyncChild
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: =>
        {abc} = @state.getValue()

        z 'div', abc

    class Root
      constructor: ->
        @state = z.state
          $component: componentSubject
      render: =>
        {$component} = @state.getValue()

        z 'div',
          $component

    $root = new Root()
    child = new AsyncChild()
    componentSubject.next child
    setTimeout ->
      child.pending.next 'abc'
    z.renderToString $root
    .then (html) ->
      b html, '<div><div>abc</div></div>'

  it 'supports async rendering with props to string', ->
    class Async
      constructor: ->
        @pending = new Rx.ReplaySubject(1)
        @state = z.state
          abc: @pending
      render: ({name}) =>
        {abc} = @state.getValue()

        unless abc?
          @pending.next 'abc'

        z 'div', abc + ' ' + name

    class Parent
      constructor: ->
        @state = z.state
          $async: new Async()

      render: (params) =>
        {$async} = @state.getValue()

        z 'div',
          z $async, params

    z.renderToString z new Parent(), {name: 'xxx'}
    .then (html) ->
      b html, '<div><div>abc xxx</div></div>'

  it 'handles state errors', ->
    pending = new Rx.BehaviorSubject(null)
    pending.error new Error 'test'

    class Root
      constructor: ->
        @state = z.state
          pending: pending

      render: ->
        z 'div', 'abc'

    $root = new Root()

    z.renderToString $root
    .then ->
      throw new Error 'expected error'
    , (err) ->
      b err.message, 'test'
      b err.html?
      b err.html, '<div>abc</div>'

  it 'handles runtime errors', ->
    class Root
      render: ->
        throw new Error 'test'
        z 'div', 'abc'

    $root = new Root()

    z.renderToString $root
    .then ->
      throw new Error 'expected error'
    , (err) ->
      b err.message, 'test'
      b err.html?, false

  it 'handles async runtime errors, returning last render (not guaranteed)', ->
    pending = new Rx.ReplaySubject(1)

    class Root
      constructor: ->
        @state = z.state
          err: pending

      render: =>
        {err} = @state.getValue()
        if err is 'invalid'
          throw new Error 'test'
        z 'div', 'abc'

    $root = new Root()

    setTimeout ->
      pending.next 'invalid'

    z.renderToString $root
    .then ->
      throw new Error 'expected error'
    , (err) ->
      b err.message, 'test'
      b err.html, '<div>abc</div>'

  it 'supports concurrent requests', (done) ->
    fastCallCnt = 0

    class Slow
      constructor: ->
        @state = z.state
          slow: Rx.Observable.fromPromise(
            new Promise (resolve) ->
              setTimeout ->
                resolve 'slow'
              , 20
          )
      render: ->
        z 'div', 'slow'

    class Fast
      render: ->
        z 'div', 'fast'


    $slow = new Slow()
    $fast = new Fast()
    z.renderToString $slow
    .then (html) ->
      b fastCallCnt, 4
      b html, '<div>slow</div>'
      done()
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<div>fast</div>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<div>fast</div>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<div>fast</div>'
      fastCallCnt += 1
    .catch done

    z.renderToString $fast
    .then (html) ->
      b html, '<div>fast</div>'
      fastCallCnt += 1
    .catch done

  it 'defaults to 250ms timeout', ->
    class Timeout
      constructor: ->
        @state = z.state
          never: Rx.Observable.empty()
      render: ->
        z 'div', 'test'

    $timeout = new Timeout()
    startTime = Date.now()

    z.renderToString $timeout
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      b (Date.now() - startTime) > 248
      b err.message, 'Timeout, request took longer than 250ms'
      b err.html, '<div>test</div>'

  it 'allows custom timeouts', ->
    class Timeout
      constructor: ->
        @state = z.state
          never: Rx.Observable.empty()
      render: ->
        z 'div', 'test'

    startTime = Date.now()
    $timeout = new Timeout()

    z.renderToString $timeout, {timeout: 300}
    .then ->
      throw new Error 'expected timeout error'
    , (err) ->
      b (Date.now() - startTime) > 299
      b err.message, 'Timeout, request took longer than 300ms'
      b err.html, '<div>test</div>'
