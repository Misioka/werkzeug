goog.require 'goog.events.EventTarget'
goog.require 'goog.style'

goog.require 'wzk.ui.ac.InputHandler'
goog.require 'wzk.ui.ac.PictureCustomRenderer'
goog.require 'wzk.ui.ac.ArrayMatcher'
goog.require 'wzk.ui.ac.AutoComplete'
goog.require 'wzk.ui.ac.SelectOneStorage'
goog.require 'wzk.dom.Dom'
goog.require 'wzk.net.XhrConfig'


class wzk.ui.ac.SelectAutoComplete extends goog.events.EventTarget

  @DATA =
    CHOOSE_VALUE: 'chooseValue'
    CHOOSE_LABEL: 'chooseLabel'
    DEP_CHILD: 'child'

  ###*
    @enum {string}
  ###
  @EVENTS =
    LOADED: 'loaded'

  ###*
    Select is assumed to be prepopulated with options in templated

    @param {wzk.dom.Dom} dom
    @param {wzk.ui.ac.Renderer} renderer
  ###
  constructor: (@dom, @renderer, @xhrFac = null) ->
    super()
    @select = null
    @handler = null
    @stor = null
    @input = null

  ###*
    @protected
    @param {Array.<wzk.resource.Model>} data
  ###
  findDefaultValue: (data) ->
    model = @stor.load data
    if model?
      @setDefaultValue model

  ###*
    @protected
    @param {wzk.resource.Model} model
  ###
  setDefaultValue: (model) ->
    @handler.detachInput @input.getElement()
    @input.setValue model.toString()
    @handler.attachInput @input.getElement()
    @input.showClearButton() if @input.getValue()
    @dom.select @select, model['pk']
    @afterSelect model

  ###*
    @param {Element} select
  ###
  decorate: (@select) ->
    if select.hasAttribute 'multiple'
      throw new Error 'For select-multiple use wzk.ui.ac.ExtSelectbox'
    @renderer.decorate @select
    @stor = new wzk.ui.ac.SelectOneStorage @dom, @select
    @renderer.listen wzk.ui.ac.Renderer.EventType.CLEAN, @handleClean
    @renderer.listen wzk.ui.ac.Renderer.EventType.OPEN, @handleOpen
    @input = @renderer.getInput()
    @input.setPlaceholder(@select.getAttribute('placeholder')) if @select.hasAttribute('placeholder')

    # allows to create a button to select it's value by defining via data attributes on `select`
    chooseLabel = goog.dom.dataset.get(@select, wzk.ui.ac.SelectAutoComplete.DATA.CHOOSE_LABEL)
    @chooseValue = goog.dom.dataset.get(@select, wzk.ui.ac.SelectAutoComplete.DATA.CHOOSE_VALUE)

    if chooseLabel
      chooseEl = @dom.el('span', 'ac-choose-value', chooseLabel)
      @dom.insertSiblingAfter(chooseEl, @input.getElement())
      goog.events.listen(chooseEl, goog.events.EventType.CLICK, @handleChooseValue)

  ###*
    Selects the `chooseValue` in autocomplete.
    @protected
    @param {goog.events.Event} e
  ###
  handleChooseValue: (e) =>
    @tryToSelectValue(@chooseValue)

  ###*
    @param {string} value
  ###
  tryToSelectValue: (value) ->
    @dom.select(@select, value)
    @findDefaultValue(@data)


  ###*
    @protected
  ###
  handleClean: =>
    childrenId = goog.dom.dataset.get @select, wzk.ui.ac.SelectAutoComplete.DATA.DEP_CHILD
    childSelect =  @dom.all '#' + childrenId + ' option'
    for el in childSelect
      goog.style.setElementShown(el, true)
    @stor.clean()
    goog.events.fireListeners(@select, goog.events.EventType.CHANGE, false, {type: goog.events.EventType.CHANGE, target: @select})

  ###*
     @protected
   ###
  handleOpen: =>
    @renderer.getInput().getElement().focus()
    loadData = goog.dom.dataset.get @select, 'filter'
    if loadData? && @xhrFac
      xhr = @xhrFac.build new wzk.net.XhrConfig()

      goog.events.listenOnce xhr, goog.net.EventType.SUCCESS, =>
        responseIds = xhr.getResponseJson()
        for row in @data
          if responseIds.indexOf(parseInt(row.id, 10)) == -1
            row.style.display = 'none'
          else
            row.style.display = 'block'
        @ac.renderRows(@data)
      formData = wzk.ui.form.form2Json(@dom.one 'form')
      formData['passengers'] = @dom.all('.field-value.passengers .tag').length
      pickup = @dom.all('[id$="job_pickup"]')[0]
      dropoff = @dom.all('[id$="job_dropoff"]')[0]
      for key in Object.keys(formData)
        k = key.split('-')
        formData[k[k.length - 1]] = formData[key]
      if pickup?
        formData['pickup'] = goog.dom.dataset.get pickup, 'position'
        formData['dropoff'] = goog.dom.dataset.get dropoff, 'position'
      console.log formData
      xhr.send loadData, 'POST', [JSON.stringify formData ], {'Content-Type': 'application/json'}
    else
      @ac.renderRows(@data)

  ###*
    @param {Array} data
  ###
  load: (@data) ->
    @matcher = new wzk.ui.ac.ArrayMatcher @data, false
    @handler = new wzk.ui.ac.InputHandler null, null, false
    @ac = new wzk.ui.ac.AutoComplete @matcher, @renderer, @handler
    @ac.setTarget(@renderer.getInput().getElement())  # sets target element where to attach suggest box

    @handler.attachAutoComplete @ac
    @handler.attachInput @renderer.getInput().getElement()

    @ac.listen goog.ui.ac.AutoComplete.EventType.UPDATE, @handleUpdate

    @findDefaultValue @data

    @dispatchEvent(new goog.events.Event(wzk.ui.ac.SelectAutoComplete.EVENTS.LOADED))

  ###*
    @protected
    @param {goog.events.Event} e
  ###
  handleUpdate: (e) =>
    childrenId = goog.dom.dataset.get(@select, wzk.ui.ac.SelectAutoComplete.DATA.DEP_CHILD)
    childSelect =  @dom.all '#' + childrenId + ' option'
    for el in childSelect
      parentId = goog.dom.dataset.get(el, 'parent')
      if parentId != e.row.id
        goog.style.setElementShown(el, false)
      else
        goog.style.setElementShown(el, true)
    @stor.store e.row
    @afterSelect e.row

    @renderer.getInput().handleInputChange()
    goog.events.fireListeners(@select, goog.events.EventType.CHANGE, false, {type: goog.events.EventType.CHANGE, target: @select})

  ###*
    @protected
    @param {Object} row
  ###
  afterSelect: (row) ->
    @renderer.updateImage row

  ###*
    @param {wzk.resource.Model} model
  ###
  addModel: (model) ->
    opt = @dom.el 'option', value: model['pk']
    @dom.setTextContent opt, model.toString()
    @select.appendChild opt
    @data.push model
    @matcher.setRows @data

  ###*
    Exits the DOM and remove the element from DOM
  ###
  destroy: ->
    @input.destroy()
