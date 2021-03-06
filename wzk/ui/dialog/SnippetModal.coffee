goog.require 'goog.dom.classes'
goog.require 'goog.events'

goog.require 'wzk.events.lst'
goog.require 'wzk.ui.dialog.Dialog'


class wzk.ui.dialog.SnippetModal extends goog.events.EventTarget

  ###*
    @enum {string}
  ###
  @EVENTS =
    OPEN: 'open'

  ###*
    @param {wzk.dom.Dom} dom
    @param {wzk.resource.Client} client
    @param {string} url
    @param {string} snippet a snippet name
    @param {wzk.app.Register} register
  ###
  constructor: (@dom, @client, @url, @snippet, @register) ->
    super()
    @dialog = new wzk.ui.dialog.Dialog undefined, undefined, @dom
    @dialog.setButtonSet null
    wzk.events.lst.onClickOrEnter(@dialog.getDialogElement(), (e) =>
      @dispatchEvent(new goog.events.Event(goog.ui.Component.EventType.ACTION, e))
    )

  ###*
    @suppress {checkTypes}
  ###
  open: ->
    @client.sniff @url, @handleResponse

  ###*
    @protected
    @param {Object} response
  ###
  handleResponse: (response) =>
    if response['snippets'][@snippet]
      @dialog.setContent response['snippets'][@snippet]
      @processResponse response

  ###*
    @protected
    @param {Object} response
  ###
  processResponse: (response) ->
    el = @dialog.getContentElement()
    @register.process el
    @dialog.setVisible true
    goog.dom.classes.add @dialog.getElement(), @snippet
    @dispatchEvent(new goog.events.Event(wzk.ui.dialog.SnippetModal.EVENTS.OPEN, @dialog))

  ###*
    @param {string} title
  ###
  setTitle: (title) ->
    @dialog.setTitle title
