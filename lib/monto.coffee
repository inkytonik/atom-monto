# atom-monto Atom package for Monto Disintegrated Development Environment
# Copyright (C) 2016-7 Anthony M. Sloane
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

{CompositeDisposable, Range, TextEditor} = require 'atom'
path = require 'path'
url = require 'url'
zmq = require 'zmq'

HTMLView = require './html-view'
ProductDialog = require './product-dialog'

module.exports =
  Monto =
    linter: null
    registerIndie: null
    sourceHandlers: []
    targetHandlers: []
    targetMessages: []
    targetPositions: []

    activate: (state) ->
      apd = require 'atom-package-deps'
      apd.install('monto').then =>
        @activateProperly()

    activateProperly: ->
      @setupZMQ()
      @subscriptions = new CompositeDisposable
      @linterpkg = @activatePackage('linter')
      @linter = @registerIndie({name: "Monto"})
      @subscriptions.add(@linter)
      @subscriptions.add atom.commands.add 'atom-workspace',
        'monto:focus-views': => @focusViews()
      @subscriptions.add atom.commands.add 'atom-workspace',
        'monto:open-html-view': => @openView(true)
      @subscriptions.add atom.commands.add 'atom-workspace',
        'monto:open-text-view': => @openView(false)
      @setupHandlers()

    consumeIndie: (registerIndie) ->
      @registerIndie = registerIndie

    setupHandlers: ->
      atom.workspace.addOpener (uri) =>
        obj = url.parse(uri)
        if obj.protocol == 'monto:'
          if obj.host == 'html'
            @createHTMLView(product: obj.hash.slice(1))
      atom.workspace.observeActivePaneItem (item) =>
        if @isTextEditor(item) && not @isMontoView(item)
          @publishVersion(item)
      atom.workspace.observePaneItems (item) =>
        if @isMontoView(item)
          @initializeView(item)
          item.onDidDestroy =>
            @destroyView(item)
      atom.workspace.observeTextEditors (editor) =>
        if not @isMontoView(editor)
          editor.onDidChangePath =>
            @publishVersion(editor)
          editor.onDidStopChanging =>
            @publishVersion(editor)

    activatePackage: (name) ->
      if not atom.packages.isPackageActive(name)
        atom.packages.activatePackage(name)
      pack = atom.packages.getLoadedPackage(name)
      if (pack && pack.mainModulePath)
        require(pack.mainModulePath)
      else
        console.log('Monto activatePackage: cannot find Atom package ' + pack)

    createHTMLView: (state) ->
      if state.product
        new HTMLView(state)

    deactivate: ->
      @subscriptions?.dispose()
      @subscriptions = @null
      @teardownZMQ()

    # ZeroMQ

    setupZMQ: ->
      @sinkSock = zmq.socket('sub')
      @sinkSock.connect('tcp://127.0.0.1:5003')
      @sinkSock.subscribe('')
      @sourceSock = zmq.socket('req')
      @sourceSock.connect('tcp://127.0.0.1:5000')

    teardownZMQ: ->
      @sinkSock.close()
      @sourceSock.close()

    # Views

    openView: (isHTML) ->
      dialog = new ProductDialog(this, isHTML)
      @productDialogPanel = atom.workspace.addModalPanel {item: dialog.element}
      dialog.selectListView.focus()

    openViewOnProduct: (product, isHTML) ->
      if product.trim() != ''
        if isHTML
          uri = "monto://html/\##{product}"
        else
          uri = "Monto: #{product}"
        atom.workspace.open(uri,
          activatePane: false
          split: 'right'
        ).then(
          (view) =>
            @setupProductSelectionHandler(view)
          (reason) ->
            console.log("Monto openViewOnProduct: #{reason}")
        )

    setupProductSelectionHandler: (view) ->
      if @isTextEditor(view)
        key = view.getTitle()
        @targetHandlers[key] = view.onDidChangeSelectionRange (event) =>
          @selectLinkFromTarget(view, event)

    removeProductSelectionHandler: (view) ->
      if @isTextEditor(view)
        key = view.getTitle()
        @targetHandlers[key]?.dispose()

    closeProductDialog: ->
      if @productDialogPanel != null
        @productDialogPanel.destroy()
        @productDialogPanel = null

    destroyView: (view) ->
      key = view.getTitle()
      index = @sourceHandlers.indexOf(key)
      if index != -1
        @sinkSock.removeListener('message', @sourceHandlers[key])
        @sourceHandlers.splice(index, 1)

    initializeView: (view) ->
      @sinkSock.on 'message', @makeViewHandler(view)

    isMontoView: (item) ->
      item.getTitle()?.startsWith("Monto")

    isHTMLView: (item) ->
      item.getTitle()?.startsWith("Monto HTML:")

    isTextEditor: (item) ->
      # FIXME item instanceof TextEditor
      item? && item.getPath? && item.getBuffer?

    languageOf: (editor) ->
      path.extname(editor.getPath()).slice(1)

    makeViewHandler: (view) ->
      key = view.getTitle()
      if @isHTMLView(view)
        @sourceHandlers[key] = (message) =>
          msg = JSON.parse(message)
          if msg.language == 'html' && @viewHandles(view, msg.product)
            view.showHTML(msg.contents)
      else
        @sourceHandlers[key] = (message) =>
          msg = JSON.parse(message)
          if @viewHandles(view, msg.product)
            @targetMessages[key] = msg
            grammar = atom.grammars.selectGrammar("file.#{msg.language}",
                                                  msg.contents)
            view.setGrammar(grammar)
            @removeProductSelectionHandler(view)
            view.setText(msg.contents)
            @setupProductSelectionHandler(view)
            @targetPositions[key] = msg.positions
          if msg.product == "message" && msg.language = "json"
            @setMessages(msg)
      @sourceHandlers[key]

    setMessages: (msg) ->
      @linter.clearMessages()
      if msg.contents != ""
        messages = JSON.parse(msg.contents)
        @linter.setAllMessages(
          {
            severity: message.level,
            excerpt: message.description,
            location: {
              file: msg.source,
              position: [
                [message.sline - 1, message.scolumn - 1],
                [message.fline - 1, message.fcolumn - 1]
              ]
            }
          } for message in messages
        )

    # Publishing

    publishVersion: (editor) ->
      if not @isMontoView(editor)
        source = editor.getPath()
        if source
          buffer = editor.getBuffer()
          language = @languageOf(editor)
          version =
            source: source,
            language: language,
            contents: buffer.getText()
            selections: @selectionsOf(editor, buffer)
          @sourceSock.send(JSON.stringify(version))

    selectionFromSel: (buffer, sel) ->
      begin: buffer.characterIndexForPosition(sel.start)
      end: buffer.characterIndexForPosition(sel.end)

    selectionsOf: (editor, buffer) ->
      selections = editor.getSelectedBufferRanges()
      @selectionFromSel(buffer, sel) for sel in selections

    viewHandles: (view, product) ->
      view.getTitle().endsWith(' ' + product)

    # Linking

    selectLinkFromTarget: (target, event) ->
      key = target.getTitle()
      if @targetPositions[key] && event.newBufferRange
        atom.workspace.open(@targetMessages[key].source,
          activatePane: false
          searchAllPanes: true
        ).then(
          (source) =>
            @displayLinkTS(source, target, key, event)
          (reason) ->
            console.log("Monto selectLinkFromTarget: #{reason}")
        )

    focusViews: ->
      source = atom.workspace.getActiveTextEditor()
      sourcePath = source.getPath()
      cursor = source.getCursorBufferPosition()
      for editor in atom.workspace.getTextEditors()
        if @isMontoView(editor)
          key = editor.getTitle()
          if @targetMessages[key]?.source == sourcePath
            @displayLinkST(source, editor, key, cursor)

    displayLinkTS: (source, target, key, event) ->
      sel = undefined
      sbuffer = source.getBuffer()
      tbuffer = target.getBuffer()
      for p in @targetPositions[key]
        tsp = tbuffer.positionForCharacterIndex(p.tbegin)
        tep = tbuffer.positionForCharacterIndex(p.tend)
        tr = new Range(tsp, tep)
        if tr.intersectsWith(event.newBufferRange)
          ssp = sbuffer.positionForCharacterIndex(p.sbegin)
          sep = sbuffer.positionForCharacterIndex(p.send )
          sr = new Range(ssp, sep)
          if sel
            if sel.containsRange(sr)
              sel = sr
          else
            sel = sr
      if sel
        source.setSelectedBufferRange(sel)

    displayLinkST: (source, target, key, cursor) ->
      ssel = undefined
      sbuffer = source.getBuffer()
      tbuffer = target.getBuffer()
      # Find smallest source region containing cursor
      for p in @targetPositions[key]
        ssp = sbuffer.positionForCharacterIndex(p.sbegin)
        sep = sbuffer.positionForCharacterIndex(p.send)
        sr = new Range(ssp, sep)
        if sr.containsPoint(cursor)
          if ssel
            if ssel.containsRange(sr)
              ssel = sr
          else
            ssel = sr
      # Select all target regions corresponding to source region
      tsel = []
      for p in @targetPositions[key]
        # FIXME: avoid doing this again?
        ssp = sbuffer.positionForCharacterIndex(p.sbegin)
        sep = sbuffer.positionForCharacterIndex(p.send)
        sr = new Range(ssp, sep)
        if sr.isEqual(ssel)
          tsp = tbuffer.positionForCharacterIndex(p.tbegin)
          tep = tbuffer.positionForCharacterIndex(p.tend)
          tr = new Range(tsp, tep)
          tsel.push(tr)
      if tsel.length != 0
        target.setSelectedBufferRanges(tsel)

    # Configuration settings

    config:
      productList:
        title: 'Product List'
        type: 'array'
        description: 'The products that are given as choices when a new
          Monto view is being created.'
        default: ["length", "reflect", "reverse"]
        items:
          type: 'string'
