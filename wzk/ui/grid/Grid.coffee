goog.provide 'wzk.ui.grid.Grid'

goog.require 'goog.dom.DomHelper'
goog.require 'goog.object'
goog.require 'goog.ui.Dialog'
goog.require 'goog.ui.Button'
goog.require 'goog.ui.Component.EventType'
goog.require 'goog.ui.Dialog'
goog.require 'goog.ui.Dialog.EventType'
goog.require 'goog.ui.Dialog.DefaultButtonKeys'
goog.require 'goog.events'
goog.require 'goog.events.Event'
goog.require 'goog.string.format'
goog.require 'wzk.ui.grid.Paginator'
goog.require 'wzk.ui.grid.Sorter'
goog.require 'wzk.ui.ButtonRenderer'
goog.require 'wzk.ui.Link'

class wzk.ui.grid.Grid extends wzk.ui.Component

  ###*
    @enum {string}
  ###
  @EventType:
    DELETE_ITEM: 'delete-item'

  ###*
    @param {wzk.dom.Dom} dom
    @param {wzk.ui.grid.Repository} repo
    @param {Array.<string>} cols
    @param {Object} actions
    @param {wzk.ui.ConfirmDialog} dialog
  ###
  constructor: (@dom, @repo, @cols, @actions, @dialog) ->
    super()
    @table = null
    @paginator = null
    @base = 10
    @tbody = null
    @sorter = null
    @lastQuery = {}

  ###*
    @param {Element} table
  ###
  decorate: (@table) ->
    @tbody = @table.querySelector 'tbody'
    paginatorEl = @dom.getParentElement(@table)?.querySelector '.paginator'
    @buildBody @buildQuery({offset: 0}), (result) =>
      @decorateWithSorting()
      @buildPaginator paginatorEl, result.total, result.count
      @listen wzk.ui.grid.Grid.EventType.DELETE_ITEM, (e) =>
        @deleteItem e.target

  ###*
    @protected
    @param {number|string} id
  ###
  deleteItem: (id) ->
    @repo.delete id, =>
      @buildBody @buildQuery(), (result) =>
        @paginator.refresh result

  ###*
    @protected
    @param {Object|null=} opts
    @return {Object}
  ###
  buildQuery: (opts = {}) ->
    @lastQuery.order = opts.column if opts.column?
    @lastQuery.direction = opts.direction if opts.direction?
    @lastQuery.base = opts.base if opts.base?

    @lastQuery.offset = if opts.offset? then opts.offset else @paginator.offset

    @lastQuery

  ###*
    @protected
    @param {Element|undefined} el
    @param {number} total
    @param {number} count
  ###
  buildPaginator: (el, total, count) ->
    @paginator = new wzk.ui.grid.Paginator total: total, base: @base, count: count

    if el?
      @paginator.decorate el
    else
      @paginator.renderBefore @table

    @paginator.listen wzk.ui.grid.Paginator.EventType.GO_TO, (e) =>
      @buildBody @buildQuery(e.target), (result) =>
        @paginator.refresh result

    @renderBottomPaginator()

  ###*
    @protected
  ###
  renderBottomPaginator: ->
    clone = @paginator.createClone()
    @dom.insertSiblingAfter clone, @table

  ###*
    @protected
    @return {DocumentFragment}
  ###
  createFrag: ->
    @dom.getDocument().createDocumentFragment()

  ###*
    @protected
    @param {Object} query
    @param {function(Object)|null=} doAfter
  ###
  buildBody: (query, doAfter = null) ->
    frag = @createFrag()
    @repo.load query, (data, result) =>
      for model in data
        @buildRow(model, frag)

      @tbody.innerHTML = ''
      @tbody.appendChild(frag)
      result.count = data.length
      doAfter result if doAfter?

  ###*
    @protected
    @param {Object} model
    @param {DocumentFragment} frag
  ###
  buildRow: (model, frag) ->
    row = @dom.createDom('tr')
    frag.appendChild(row)
    for col in @cols
      @buildCell(model[col], row)

    @buildActionsCell(row, model)

  ###*
    @protected
    @param {string} text
    @param {Element} row
  ###
  buildCell: (text, row) ->
    cell = @dom.createDom('td')
    @dom.setTextContent(cell, text)
    row.appendChild(cell)

  ###*
    @protected
    @param {Element} row
    @param {Object} model
  ###
  buildActionsCell: (row, model) ->
    cell = @dom.createDom('td', 'class': 'actions')
    @buildAction action, model, cell, row for action in @actions
    row.appendChild(cell)

  ###*
    @protected
    @param {Object} action
    @param {Object} model
    @param {Element} cell
    @param {Element} row
  ###
  buildAction: (action, model, cell, row) ->
    if action['type'] is 'rest'
      @buildRestAction action, model, cell, row
    else if action['type'] is 'web'
      @buildWebAction action, model, cell
    else
      # TODO: use google closure logger
      @dom.getWindow().console.warn('Non-existent action type: ' + action['type'])

  ###*
    @protected
    @param {Object} action
    @param {Object} model
    @param {Element} cell
    @param {Element} row
  ###
  buildRestAction: (action, model, cell, row) ->
    if action['name'] is 'delete'
      btn = @buildButton action['verbose_name'], action['name'], model, cell, row
      @hangListener btn

  ###*
    @protected
    @param {Object} action
    @param {Object} model
    @param {Element} cell
  ###
  buildWebAction: (action, model, cell) ->
    link = new wzk.ui.Link dom: @dom, href: model['_web_links'][action['name']], caption: action['verbose_name']
    link.addClass(action['class_name'] or action['name'])
    link.render cell

  ###*
    @protected
    @param {string} caption
    @param {string} className
    @param {Object} model
    @param {Element} cell
    @param {Element} row
    @return {goog.ui.Button}
  ###
  buildButton: (caption, className, model, cell, row) ->
    btn = new goog.ui.Button caption, wzk.ui.ButtonRenderer.getInstance(), @dom
    btn.addClassName 'btn-danger'
    @setupButton model, caption, className, btn
    btn.render(cell)
    @buildButtonModel(btn, row, model)
    btn

  ###*
    @protected
    @param {Object} model
    @param {string} caption
    @param {string} className
    @param {goog.ui.Button} btn
  ###
  setupButton: (model, caption, className, btn) ->
    btn.addClassName className
    btn.setModel model
    btn.setTooltip caption

  ###*
    @protected
    @param {string} txt
  ###
  setDialogText: (txt) ->
    @dialog.formatContent txt

  ###*
    @protected
    @param {goog.ui.Button} btn
  ###
  showDialog: (btn) ->
    @dialog.setVisible(true)
    goog.events.listenOnce @dialog, goog.ui.Dialog.EventType.SELECT, (e) =>
      if e.key is goog.ui.Dialog.DefaultButtonKeys.YES
        @dispatchDeleteItem(btn)
        @silentlyRemoveRow(btn)

  ###*
    @protected
  ###
  decorateWithSorting: ->
    @sorter = new wzk.ui.grid.Sorter @dom
    @sorter.decorate @table

    @sorter.listen wzk.ui.grid.Sorter.EventType.SORT, (e) =>
      @buildBody @buildQuery(e.target), (result) =>
        @paginator.refresh result

  ###*
    @protected
    @param {goog.ui.Button} btn
  ###
  dispatchDeleteItem: (btn) ->
    @dispatchEvent(new goog.events.Event(wzk.ui.grid.Grid.EventType.DELETE_ITEM, btn.getModel().model))

  ###*
    @protected
    @param {goog.ui.Button} btn
  ###
  hangListener: (btn) ->
    goog.events.listen btn, goog.ui.Component.EventType.ACTION, =>
      @setDialogText(btn.getModel().model['_obj_name'])
      @showDialog(btn)

  ###*
    A little bit dirty, but enough for now.

    @private
    @param {goog.ui.Button} btn
  ###
  silentlyRemoveRow: (btn) ->
    @dom.removeNode btn.getModel().row

  ###*
    Temporary a model wrapper, connects a table row and its data

    @private
    @param {goog.ui.Button} btn
    @param {Element} row
    @param {Object} model
  ###
  buildButtonModel: (btn, row, model) ->
    btn.setModel row: row, model: model
