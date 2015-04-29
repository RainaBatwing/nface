class Events
  on:(name, listener)->
    @__events ||= {}
    @__events[name] ||= []
    @__events[name].push listener
  off:(name, listener)->
    return unless @__events and @__events[name]
    @__events[name] = @__events.filter((x)-> x isnt listener)
  once:(name, listener)->
    wrapper = (args...)=>
      listener(args...)
      @off(name, wrapper)
    @on(name, wrapper)
  emit:(name, args...)->
    return false unless @__events and @__events[name]
    listener(args...) for listener in @__events[name]
    return @__events[name].length > 0

Color =
  toRGB:(cssColor)->
    s = document.createElement('span')
    document.body.appendChild(s)
    s.style.backgroundColor = cssColor
    rgb = getComputedStyle(s).backgroundColor
    document.body.removeChild(s)
    m = /^rgb\((\d+), (\d+), (\d+)\)$/.exec(rgb)
    if !m
      m = /^rgba\((\d+), (\d+), (\d+), ([\d.]+)\)$/.exec(rgb)
    return [m[0], m[1], m[2], m[3] || 1.0]
  equal:(left, right)->
    Color.toRGB(left).toString() is Color.toRGB(right).toString()




# generate a UI for toggling preview properties
class TwofacePanels extends Events
  constructor:(@render)->
    @tabGroupID = "tabs-#{Math.random()}"
    @color = "#ff0000"

  # set an option on or off
  set:(address, value)->
    if @checks and @checks[address] #and @checks[address].prop('checked') isnt !!value
      @checks[address].prop('checked', !!value)
  # convert panel data to string avatar description
  serialize:->
    enabledList = []
    for address, check of @checks
      enabledList.push address if check.prop('checked')
    enabledList.unshift(@color)
    enabledList.join('|')
  # load from a string avatar description
  load:(description)->
    enabledList = description.split('|')
    @color = "#" + enabledList.shift(@color).replace(/[^a-f0-9]/gi, '')
    for address, check of @checks
      check.prop('checked', enabledList.indexOf(address) != -1)
    @emit "change"

  # set a specific tab as active foreground
  activateTab:(section)->
    @_panel.find('.TF-tabs-group > .TF-tab').each (idx, tab)=>
      tab = jQuery(tab)
      tab.toggleClass 'active', tab.attr('data-section') is section

  # generate list of configuration form tabs
  tabs:-> (section.name for section in @render.structure)
  # generate forms
  forms:->
    return @_forms if @_forms
    @checks = {}
    @_forms = for section in @render.structure
      form = jQuery('<div class="TF-tab">').attr("data-section": section.name)
      for option in section.options
        uuid = "uuid-#{Math.random()}"
        form.append(
          jQuery('<div class="TF-option">').append(
            @checks[option.address] = jQuery('<input>')
              .attr('type': {choose: 'radio', toggle: 'checkbox'}[section.mode])
              .attr('id': uuid)
              .attr('data-address': option.address)
              .attr('name': section.name)
              .change((evt)=> @emit("change")),
            jQuery('<label>').attr('for': uuid)
              .append(
                jQuery('<img>')
                  .attr('alt', option.name)
                  .attr('src', @render.renderToURI("lightblue|#{option.address}"))
                  .attr(width: 64, height: 64)
              )
          )
        )
      form
  # generate html combining tabs and forms
  html:->
    return @_panel if @_panel
    @_panel = jQuery "<section class='TF-tabs'>"
    # generate tab buttons
    for tabTitle, idx in @tabs()
      uuid = "uuid-#{Math.random()}"
      @_panel.append(
        jQuery('<input type=radio>')
          .attr(id: uuid, name: @tabGroupID, "data-section": tabTitle)
          .change((evt)=>
            @activateTab(evt.target.getAttribute('data-section')) if evt.target.checked
          ).prop('checked', idx is 0),
        jQuery('<label class="TF-tab">').text(tabTitle).attr(for: uuid)
      )

    # append forms
    @_panel.append(tabs = jQuery('<div class="TF-tabs-group">'))
    tabs.append form for form in @forms()

    @activateTab(@tabs()[0])
    return @_panel

# user interface for creating and editing avatar descriptions
class TwofaceChooser extends Events
  constructor:(svgdom)->
    @root =
      jQuery('<div class="TF-chooser">')
        .append(@previewImage = jQuery('<img class="preview">'))
    @render = new TwofaceRender(svgdom)
    @panels = new TwofacePanels(@render)
    @panels.on "change", (args...)=>
      @previewImage.attr src: @render.renderToURI(@panels.serialize())
      @emit("change", args...)
    @root.append @panels.html()

  load:(string)-> @panels.load(string)
  serialize:-> @panels.serialize()
  html:-> @root


# take template svg xmldom as input, renders out instances as static xmldoms or strings
class TwofaceRender
  constructor:(template)->
    @svgdom = template.cloneNode(true)
    @serializer = new XMLSerializer
    @structure = for section in @svgdom.querySelectorAll('svg > g[id*="~"]')
      [name, mode] = section.id.split('~')
      {
        name: name
        mode: mode
        options: (
          for node in section.childNodes when node.id
            { name: node.id, address: "#{name}>#{node.id}" }
        )
      }


  # return a static mutated SVG document
  render:(configString)->
    enabledList = configString.split('|')
    color = enabledList.shift()
    # clone svg document and remove unwanted elements
    instance = @svgdom.cloneNode(true)
    for element in instance.querySelectorAll('svg > g[id*="~"] > *')
      address = "#{element.parentNode.id.split('~')[0]}>#{element.id}"
      element.parentNode.removeChild(element) unless enabledList.indexOf(address) isnt -1


    for node in instance.querySelectorAll('svg *')
      continue unless node and node.style
      node.style.fill = color if Color.equal(node.style.fill, "#000000")
      node.style.stroke = color if Color.equal(node.style.stroke, "#000000")

    return instance
  renderToString:(configString)->
    @serializer.serializeToString(@render(configString))
  renderToURI:(configString)->
    string = @renderToString(configString)
    "data:image/svg+xml;base64,#{btoa(string)}"
  # replace an existing <object> svg document with this one
  updateObjectTag:(object, configString)->
    object.contentDocument.replaceChild(@render(configString).lastChild, object.contentDocument.lastChild)



jQuery ->
  # load template from server
  jQuery.ajax "future-punk/future-punk.svg", dataType: 'xml', success: (xmldoc)->
    console.log window.x = xmldoc
    # instanciate a twoface chooser ui with Future Punk avatar template xmldom
    window.chooser = new TwofaceChooser(xmldoc)
    chooser.load "#abcdef|Outfit>Seifuku|Styles>Odango|Styles>Pony Right|Styles>Pony Left|Hair>Part Center"
    jQuery(document.body).prepend chooser.html()

    chooser.on "change", ->
      code = chooser.serialize()
      jQuery('#code').val code
      jQuery('#imgTest').prop('src', chooser.render.renderToURI(code))
