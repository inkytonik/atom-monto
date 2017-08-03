fs = require 'fs-plus'
path = require 'path'

{allowUnsafeEval} = require 'loophole'
{Disposable} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
class HTMLView extends ScrollView
  @savedHTML: null

  @content: ->
    @div class: 'monto-html-view native-key-bindings', tabindex: -1

  constructor: ({@product}) ->
    super

  destroy: ->
    @destroyCallback?()

  getTitle: ->
    "Monto HTML: #{@product}"

  onDidDestroy: (callback) ->
    @destroyCallBack = callback
    new Disposable =>
      @destroyCallback = null

  serialize: ->
    deserializer: 'HTMLView'
    product: @product
    savedHTML: @savedHTML

  showHTML: (html) ->
    allowUnsafeEval =>
      @savedHTML = html
      @html(html)
