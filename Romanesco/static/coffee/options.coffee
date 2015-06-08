define [
	'utils', 'tinycolor', 'gui', 'colorpickersliders', 'jquery', 'paper'
], (utils, tinycolor, GUI) ->

	g = utils.g()
	window.tinycolor = tinycolor

	paper.install(window)

	# --- Options --- #

	# todo: improve reset parameter values when selection

	# this.updateFillColor = ()->
	# 	if not g.itemsToUpdate?
	# 		return
	# 	for item in g.itemsToUpdate
	# 		if item.controller?
	# 			g.updatePath(item.controller, 'fillColor')
	# 	if g.itemsToUpdate.divJ?
	# 		updateDiv(g.itemsToUpdate)
	# 	return

	# this.updateStrokeColor = ()->
	# 	if not g.itemsToUpdate?
	# 		return
	# 	for item in g.itemsToUpdate
	# 		g.updatePath(item.controller, 'strokeColor')
	# 	if g.itemsToUpdate.divJ?
	# 		updateDiv(g.itemsToUpdate)
	# 	return

	g.initializeGlobalParameters = ()->

		# g.defaultColors = ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ]
		# g.defaultColors = ['#d7dddb', '#4f8a83', '#e76278', '#fac699', '#712164']
		# g.defaultColors = ['#395A8F', '#4A79B1', '#659ADF', '#A4D2F3', '#EBEEF3']

		g.defaultColors = []

		hueRange = g.random(10, 180)
		minHue = g.random(0, 360-hueRange)
		step = hueRange/10

		for i in [0 .. 10]
			g.defaultColors.push(Color.HSL( minHue + i * step, g.random(0.3, 0.9), g.random(0.5, 0.7) ).toCSS())
			# g.defaultColors.push(Color.random().toCSS())

		g.parameters = {}
		g.parameters['General'] = {}
		g.parameters['General'].location =
			type: 'string'
			label: 'Location'
			default: '0.0, 0.0'
			permanent: true
			onFinishChange: (value)->
				g.ignoreHashChange = false
				location.hash = value
				return
		g.parameters['General'].zoom =
			type: 'slider'
			label: 'Zoom'
			min: 1
			max: 500
			default: 100
			permanent: true
			onChange: (value)->
				g.project.view.zoom = value/100.0
				g.updateGrid()
				g.rasterizer.move()
				for div in g.divs
					div.updateTransform()
				return
			onFinishChange: (value) ->
				g.load()
				return
		g.parameters['General'].displayGrid =
			type: 'checkbox'
			label: 'Display grid'
			default: false
			permanent: true
			onChange: (value)->
				g.displayGrid = !g.displayGrid
				g.updateGrid()
				return
		g.parameters['General'].ignoreSockets =
			type: 'checkbox'
			label: 'Ignore sockets'
			default: false
			onChange: (value)->
				g.ignoreSockets = value
				return
		g.parameters['General'].snap =
			type: 'slider'
			label: 'Snap'
			min: 0
			max: 100
			step: 5
			default: 0
			snap: 0
			permanent: true
			onChange: ()-> g.updateGrid()
		# g.parameters.fastMode =
		# 	type: 'checkbox'
		# 	label: 'Fast mode'
		# 	default: g.fastMode
		# 	permanent: true
		# 	onChange: (value)->
		# 		g.fastMode = value
		# 		return

		g.parameters.default = {}
		g.parameters.strokeWidth =
			type: 'slider'
			label: 'Stroke width'
			min: 1
			max: 100
			default: 1
		g.parameters.strokeColor =
			type: 'color'
			label: 'Stroke color'
			default: g.defaultColors.random()
			defaultFunction: () -> return g.defaultColors.random()
			defaultCheck: true 						# checked/activated by default or not
		g.parameters.fillColor =
			type: 'color'
			label: 'Fill color'
			default: g.defaultColors.random()
			defaultCheck: false 					# checked/activated by default or not
		g.parameters.delete =
			type: 'button'
			label: 'Delete items'
			default: ()-> item.deleteCommand() for item in g.selectedItems
		g.parameters.duplicate =
			type: 'button'
			label: 'Duplicate items'
			default: ()-> item.duplicateCommand() for item in g.selectedItems
		g.parameters.align =
			type: 'button-group'
			label: 'Align'
			value: ''
			initializeController: (controller)->
				domElement = controller.datController.domElement
				$(domElement).find('input').remove()

				align = (type)->
					items = g.selectedItems
					switch type
						when 'h-top'
							yMin = NaN
							for item in items
								top = item.getBounds().top
								if isNaN(yMin) or top < yMin
									yMin = top
							items.sort((a, b)-> return a.getBounds().top - b.getBounds().top)
							for item in items
								bounds = item.getBounds()
								item.moveTo(new Point(bounds.centerX, top+bounds.height/2))
						when 'h-center'
							avgY = 0
							for item in items
								avgY += item.getBounds().centerY
							avgY /= items.length
							items.sort((a, b)-> return a.getBounds().centerY - b.getBounds().centerY)
							for item in items
								bounds = item.getBounds()
								item.moveTo(new Point(bounds.centerX, avgY))
						when 'h-bottom'
							yMax = NaN
							for item in items
								bottom = item.getBounds().bottom
								if isNaN(yMax) or bottom > yMax
									yMax = bottom
							items.sort((a, b)-> return a.getBounds().bottom - b.getBounds().bottom)
							for item in items
								bounds = item.getBounds()
								item.moveTo(new Point(bounds.centerX, bottom-bounds.height/2))
						when 'v-left'
							xMin = NaN
							for item in items
								left = item.getBounds().left
								if isNaN(xMin) or left < xMin
									xMin = left
							items.sort((a, b)-> return a.getBounds().left - b.getBounds().left)
							for item in items
								bounds = item.getBounds()
								item.moveTo(new Point(xMin+bounds.width/2, bounds.centerY))
						when 'v-center'
							avgX = 0
							for item in items
								avgX += item.getBounds().centerX
							avgX /= items.length
							items.sort((a, b)-> return a.getBounds().centerY - b.getBounds().centerY)
							for item in items
								bounds = item.getBounds()
								item.moveTo(new Point(avgX, bounds.centerY))
						when 'v-right'
							xMax = NaN
							for item in items
								right = item.getBounds().right
								if isNaN(xMax) or right > xMax
									xMax = right
							items.sort((a, b)-> return a.getBounds().right - b.getBounds().right)
							for item in items
								bounds = item.getBounds()
								item.moveTo(new Point(xMax-bounds.width/2, bounds.centerY))
					return

				# todo: change fontStyle id to class
				g.templatesJ.find("#align").clone().appendTo(domElement)
				alignJ = $("#align:first")
				alignJ.find("button").click ()-> align($(this).attr("data-type"))
				return
		g.parameters.distribute =
			type: 'button-group'
			label: 'Distribute'
			value: ''
			initializeController: (controller)->
				domElement = controller.datController.domElement
				$(domElement).find('input').remove()

				distribute = (type)->
					items = g.selectedItems
					switch type
						when 'h-top'
							yMin = NaN
							yMax = NaN
							for item in items
								top = item.getBounds().top
								if isNaN(yMin) or top < yMin
									yMin = top
								if isNaN(yMax) or top > yMax
									yMax = top
							step = (yMax-yMin)/(items.length-1)
							items.sort((a, b)-> return a.getBounds().top - b.getBounds().top)
							for item, i in items
								bounds = item.getBounds()
								item.moveTo(new Point(bounds.centerX, yMin+i*step+bounds.height/2))
						when 'h-center'
							yMin = NaN
							yMax = NaN
							for item in items
								center = item.getBounds().centerY
								if isNaN(yMin) or center < yMin
									yMin = center
								if isNaN(yMax) or center > yMax
									yMax = center
							step = (yMax-yMin)/(items.length-1)
							items.sort((a, b)-> return a.getBounds().centerY - b.getBounds().centerY)
							for item, i in items
								bounds = item.getBounds()
								item.moveTo(new Point(bounds.centerX, yMin+i*step))
						when 'h-bottom'
							yMin = NaN
							yMax = NaN
							for item in items
								bottom = item.getBounds().bottom
								if isNaN(yMin) or bottom < yMin
									yMin = bottom
								if isNaN(yMax) or bottom > yMax
									yMax = bottom
							step = (yMax-yMin)/(items.length-1)
							items.sort((a, b)-> return a.getBounds().bottom - b.getBounds().bottom)
							for item, i in items
								bounds = item.getBounds()
								item.moveTo(new Point(bounds.centerX, yMin+i*step-bounds.height/2))
						when 'v-left'
							xMin = NaN
							xMax = NaN
							for item in items
								left = item.getBounds().left
								if isNaN(xMin) or left < xMin
									xMin = left
								if isNaN(xMax) or left > xMax
									xMax = left
							step = (xMax-xMin)/(items.length-1)
							items.sort((a, b)-> return a.getBounds().left - b.getBounds().left)
							for item, i in items
								bounds = item.getBounds()
								item.moveTo(new Point(xMin+i*step+bounds.width/2, bounds.centerY))
						when 'v-center'
							xMin = NaN
							xMax = NaN
							for item in items
								center = item.getBounds().centerX
								if isNaN(xMin) or center < xMin
									xMin = center
								if isNaN(xMax) or center > xMax
									xMax = center
							step = (xMax-xMin)/(items.length-1)
							items.sort((a, b)-> return a.getBounds().centerX - b.getBounds().centerX)
							for item, i in items
								bounds = item.getBounds()
								item.moveTo(new Point(xMin+i*step, bounds.centerY))
						when 'v-right'
							xMin = NaN
							xMax = NaN
							for item in items
								right = item.getBounds().right
								if isNaN(xMin) or right < xMin
									xMin = right
								if isNaN(xMax) or right > xMax
									xMax = right
							step = (xMax-xMin)/(items.length-1)
							items.sort((a, b)-> return a.getBounds().right - b.getBounds().right)
							for item, i in items
								bounds = item.getBounds()
								item.moveTo(new Point(xMin+i*step-bounds.width/2, bounds.centerY))
					return

				# todo: change fontStyle id to class
				g.templatesJ.find("#distribute").clone().appendTo(domElement)
				distributeJ = $("#distribute:first")
				distributeJ.find("button").click ()-> distribute($(this).attr("data-type"))
				return

		colorName = g.defaultColors.random()
		colorRGBstring = tinycolor(colorName).toRgbString()
		g.strokeColor = colorRGBstring
		g.fillColor = "rgb(255,255,255,255)"
		g.displayGrid = false

		return

	g.initializeGlobalParameters()

	# Initialize general and default parameters
	g.initParameters = () ->

		g.optionsJ = $(".option-list")


		# --- DAT GUI/ --- #

		# todo: use addItems for general settings!!!
		g.controllerManager = new g.ControllerManager()

		generalFolder = new g.Folder('General')

		for name, parameter of g.parameters['General']
			g.controllerManager.createController(name, parameter, generalFolder)

		# controller = g.generalFolder.add({location: g.parameters.location.default}, 'location')
		# .name("Location")
		# .onFinishChange( g.parameters.location.onFinishChange )

		# g.generalFolder.add({zoom: 100}, 'zoom', g.parameters.zoom.min, g.parameters.zoom.max)
		# .name("Zoom")
		# .onChange( g.parameters.zoom.onChange )
		# .onFinishChange( g.parameters.zoom.onFinishChange )

		# g.generalFolder.add({displayGrid: g.parameters.displayGrid.default}, 'displayGrid', true)
		# .name("Display grid")
		# .onChange(g.parameters.displayGrid.onChange)
		# # g.generalFolder.add({fastMode: g.parameters.fastMode.default}, 'fastMode', true).name("Fast mode").onChange(g.parameters.fastMode.onChange)

		# g.generalFolder.add({ignoreSockets: g.parameters.ignoreSockets.default}, 'ignoreSockets', false)
		# .name(g.parameters.ignoreSockets.name)
		# .onChange(g.parameters.ignoreSockets.onChange)

		# g.generalFolder.add(g.parameters.snap, 'snap', g.parameters.snap.min, g.parameters.snap.max)
		# .name(g.parameters.snap.label)
		# .step(g.parameters.snap.step)
		# .onChange(g.parameters.snap.onChange)

		g.addRasterizerParameters()

		# --- /DAT GUI --- #

		# --- Text options --- #

		# g.textOptionsJ = g.optionsJ.find(".text-options")

		# g.stylePickerJ = g.textOptionsJ.find('#fontStyle')
		# # g.subsetPickerJ = g.optionsJ.find('#fontSubset')
		# g.effectPickerJ = g.textOptionsJ.find('#fontEffect')
		# g.sizePickerJ = g.textOptionsJ.find('#fontSizeSlider')
		# g.sizePickerJ.slider().on('slide', (event)-> g.fontSize = event.value )

		g.availableFonts = []
		g.usedFonts = []
		jQuery.support.cors = true

		# $.getJSON("https://www.googleapis.com/webfonts/v1/webfonts?key=AIzaSyD2ZjTQxVfi34-TMKjB5WYK3U8K6y-IQH0", initTextOptions)
		jqxhr = $.getJSON("https://www.googleapis.com/webfonts/v1/webfonts?key=AIzaSyBVfBj_ugQO_w0AK1x9F6yiXByhcNgjQZU", g.initTextOptions)
		jqxhr.done (json)->
			console.log 'done'
			g.initTextOptions(json)
			return
		jqxhr.fail (jqxhr, textStatus, error)->
			err = textStatus + ", " + error
			console.log 'failed: ' + err
			return
		jqxhr.always (jqxhr, textStatus, error)->
			err = textStatus + ", " + error
			console.log 'always: ' + err
			return

	# add font to the page:
	# - check if the font is already loaded, and with which effect
	# - load web font from google font if needed
	g.addFont = (fontFamily, effect)->
		if not fontFamily? then return

		fontFamilyURL = fontFamily.split(" ").join("+")

		# update g.usedFonts, check if the font is already
		fontAlreadyUsed = false
		for font in g.usedFonts
			if font.family == fontFamilyURL
				# if font.subsets.indexOf(subset) == -1 and subset != 'latin'
				# 	font.subsets.push(subset)
				# if font.styles.indexOf(style) == -1
				# 	font.styles.push(style)
				if font.effects.indexOf(effect) == -1 and effect?
					font.effects.push(effect)
				fontAlreadyUsed = true
				break
		if not fontAlreadyUsed 		# if the font is not already used (loaded): load the font with the effect
			# subsets = [subset]
			# if subset!='latin'
			# 	subsets.push('latin')
			effects = []
			if effect?
				effects.push(effect)
			if not fontFamilyURL or fontFamilyURL == ''
				console.log 'ERROR: font family URL is null or empty'
			g.usedFonts.push( family: fontFamilyURL, effects: effects )
		return

	# todo: use google web api to update text font on load callback
	# fonts could have multiple effects at once, but the gui does not allow this yet
	# since having multiple effects would not be of great use
	# must be improved!!
	g.loadFonts = ()->
		$('head').remove("link.fonts")

		for font in g.usedFonts
			newFont = font.family
			# if font.styles.length>0
			# 	newFont += ":"
			# 	for style in font.styles
			# 		newFont += style + ','
			# 	newFont = newFont.slice(0,-1)
			# if font.subsets.length>0
			# 	newFont += "&subset="
			# 	for subset in font.subsets
			# 		newFont += subset + ','
			# 	newFont = newFont.slice(0,-1)

			if $('head').find('link[data-font-family="' + font.family + '"]').length==0

				if font.effects.length>0 and not (font.effects.length == 1 and font.effects.first() == 'none')
					newFont += "&effect="
					for effect, i in font.effects
						newFont += effect + '|'
					newFont = newFont.slice(0,-1)

				fontLink = $('<link class="fonts" data-font-family="' + font.family + '" rel="stylesheet" type="text/css">')
				fontLink.attr('href', "http://fonts.googleapis.com/css?family=" + newFont)
				$('head').append(fontLink)
		return

	# initialize typeahead font engine to quickly search for a font by typing its first letters
	g.initTextOptions = (data, textStatus, jqXHR) ->

		# gather all font names
		fontFamilyNames = []
		for item in data.items
			fontFamilyNames.push({ value: item.family })

		# initialize typeahead font engine
		g.typeaheadFontEngine = new Bloodhound({
			name: 'Font families',
			local: fontFamilyNames,
			datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
			queryTokenizer: Bloodhound.tokenizers.whitespace
		})
		promise = g.typeaheadFontEngine.initialize()

		g.availableFonts = data.items

		# test
		# g.familyPickerJ = g.textOptionsJ.find('#fontFamily')
		# g.familyPickerJ.typeahead(
		# 	{ hint: true, highlight: true, minLength: 1 },
		# 	{ valueKey: 'value', displayKey: 'value', source: typeaheadFontEngine.ttAdapter() }
		# )

		# g.fontSubmitJ = g.textOptionsJ.find('#fontSubmit')


		# g.fontSubmitJ.click( (event) ->
		# 	g.setFontStyles()
		# )

		return

	# g.setControllerValueByName = (name, value, item)->
	# 	checked = value?
	# 	for folderName, folder of g.gui.__folders
	# 		for controller in folder.__controllers
	# 			if controller.property == name
	# 				g.setControllerValue(controller, { min: controller.__min, max: controller.__max }, value, item, checked)
	# 				break
	# 	return

	# # todo: better manage parameter..
	# # set the value of the controller without calling its onChange and onFinishChange callback
	# # controller.rSetValue (a user defined callback) is called here
	# # called when the controller is updated (when it existed, and must be updated to fit data of a newly selected tool or item)
	# g.setControllerValue = (controller, parameter, value, item, checked=false)->
	# 	onChange = controller.__onChange
	# 	onFinishChange = controller.__onFinishChange
	# 	controller.__onChange = ()->return
	# 	controller.__onFinishChange = ()->return
	# 	if parameter?
	# 		controller.min?(parameter.min)
	# 		controller.max?(parameter.max)
	# 	controller.setValue(value)
	# 	controller.rSetValue?(value, item, checked)
	# 	controller.__onChange = onChange
	# 	controller.__onFinishChange = onFinishChange

	# # doctodo: copy deault parameter doc here
	# # add a controller to dat.gui (corresponding to a parameter, from a tool or an item)
	# # @param name [String] name of the parameter (short name without spaces, same as RItem.data[name] )
	# # @param parameter [Parameter] the parameter to add
	# # @param item [RItem] optional RItem, the controller will be initialized with *item.data* if any
	# # @param datFolder [DatFolder] folder in which to add the controller
	# # @param resetValues [Boolean] (optional) true if must reset value to default (create a new default if parameter has a defaultFunction)
	# addItem = (name, parameter, item, datFolder, resetValues)->

	# 	# intialize the default value
	# 	# a color can be null, then it is disabled
	# 	if item? and datFolder.name != 'General' and item.data? and (item.data[name]? or parameter.type=='color')
	# 		value = item.data[name]
	# 	else if parameter.value?
	# 		value = parameter.value
	# 	else if parameter.defaultFunction?
	# 		value = parameter.defaultFunction()
	# 	else
	# 		value = parameter.default

	# 	# add controller to the current tool or item if parameter.addController
	# 	# @param [Parameter] the parameter of the controller
	# 	# @param [String] the name of the parameter
	# 	# @param [RItem] (optional) the RItem
	# 	# @param [Dat Controller] the controller to add
	# 	updateItemControllers = (parameter, name, item, controller)->
	# 		if parameter.addController
	# 			if item?
	# 				item.parameterControllers ?= {}
	# 				item.parameterControllers[name] = controller
	# 			else
	# 				g.selectedTool.parameterControllers ?= {}
	# 				g.selectedTool.parameterControllers[name] = controller
	# 		return

	# 	# check if controller already exists for this parameter, and update if exists
	# 	for controller in datFolder.__controllers
	# 		if controller.property == name and not parameter.permanent
	# 			if resetValues
	# 				# disable onChange and onFinishChange when updating the GUI after selection
	# 				checked = if item? then item.data[name] else parameter.defaultCheck
	# 				g.setControllerValue(controller, parameter, value, item, checked)
	# 				updateItemControllers(parameter, name, item, controller)
	# 			g.unusedControllers.remove(controller)
	# 			return

	# 	# - snap the value according to parameter.step
	# 	# - update item.data[name] if it is defined
	# 	# - call item.parameterChanged()
	# 	# - emit "parameter change" on websocket
	# 	onParameterChange = (value) ->
	# 		g.c = this
	# 		for item in g.selectedItems
	# 			# do not update if the value was never set (not even to null), update if it was set (even to null, for colors)
	# 			if typeof item.data?[name] isnt 'undefined'
	# 				# if parameter.step? then value = value-value%parameter.step
	# 				item.setParameterCommand(name, value)
	# 				# if g.me? and datFolder.name != 'General' then g.chatSocket.emit( "parameter change", g.me, item.pk, name, value )
	# 		return

	# 	# if parameter has no onChange function: create a default one which will update item.data[name]
	# 	if parameter.type == 'string' and not parameter.fireOnEveryChange
	# 		parameter.onFinishChange ?= onParameterChange
	# 	else
	# 		parameter.onChange ?= onParameterChange


	# 	obj = {}

	# 	switch parameter.type
	# 		when 'color' 		# create a color controller
	# 			obj[name] = ''
	# 			controller = datFolder.add(obj, name).name(parameter.label)
	# 			colorInputJ = $(datFolder.domElement).find("div.c > input:last")
	# 			colorInputJ.addClass("color-input")
	# 			checkboxJ = $('<input type="checkbox">')
	# 			checkboxJ.insertBefore(colorInputJ)
	# 			checkboxJ[0].checked = if item? and datFolder.name != 'General' then item.data[name]? else parameter.defaultCheck

	# 			# colorGUI = new dat.GUI({ autoPlace: false })
	# 			# color = :
	# 			# 	hue: 0
	# 			# 	saturation: 0
	# 			# 	lightness: 0
	# 			# 	red: 0
	# 			# 	green: 0
	# 			# 	blue: 0

	# 			# colorGUI.add(color, 'hue', 0, 1).onChange( (value)-> tinycolor.("hsv 0 1 1"))
	# 			# colorGUI.add(color, 'saturation', 0, 1)
	# 			# colorGUI.add(color, 'lightness', 0, 1)
	# 			# colorGUI.add(color, 'red', 0, 1)
	# 			# colorGUI.add(color, 'green', 0, 1)
	# 			# colorGUI.add(color, 'blue', 0, 1)

	# 			# $("body").appendChild(colorGUI.domElement)
	# 			# colorGuiJ = $(colorGUI.domElement)
	# 			# colorGuiJ.css( position: 'absolute', left: inputJ.offset().left, top: inputJ.offset().top )

	# 			initialValue = tinycolor(if value? then value else parameter.default).toRgbString()
	# 			if initialValue.gradient?
	# 				initialValue = initialValue.gradient.stops[0][0].toCSS()

	# 			gradientCheckboxChanged = (event)->
	# 				colorInputJ = $(this).parent().siblings('.color-input')

	# 				parameterName = colorInputJ.attr('data-parameter-name')
	# 				value = g.items[colorInputJ.attr('data-item-pk')]?.data[parameterName]

	# 				if this.checked
	# 					g.tools['Gradient'].select(parameterName, colorInputJ, value)
	# 					colorInputJ.attr('data-gradient', 1)
	# 				else
	# 					g.tools['Select'].select()
	# 					colorInputJ.attr('data-gradient', 0)
	# 				return

	# 			initializeColorPicker = (colorInputJ, container, gradient, parameterName, value)->
	# 				checkboxJ = $("<label><input type='checkbox' class='gradient-checkbox' form-control>Gradient</label>")
	# 				checkboxJ.insertBefore(container.find('.cp-preview'))
	# 				checkboxJ.css( 'color': 'black' )

	# 				checkboxJ.find('input').click(gradientCheckboxChanged)

	# 				if gradient
	# 					checkboxJ.find('input').attr('checked', true)
	# 					g.tools['Gradient'].select(parameterName, colorInputJ, value)

	# 				colorInputJ.attr('data-initialized', 1)
	# 				container.attr('data-trigger', '')

	# 				return

	# 			colorInputJ.attr('data-trigger', 'click')

	# 			colorInputJ = colorInputJ.ColorPickerSliders({
	# 				title: parameter.label,
	# 				placement: 'auto',
	# 				size: 'sm',
	# 				# trigger: 'click',
	# 				# hsvpanel: true
	# 				color: initialValue,
	# 				order: {
	# 					hsl: 1,
	# 					rgb: 2,
	# 					opacity: 3,
	# 					preview: 4
	# 				},
	# 				labels: {
	# 					rgbred: 'Red',
	# 					rgbgreen: 'Green',
	# 					rgbblue: 'Blue',
	# 					hslhue: 'Hue',
	# 					hslsaturation: 'Saturation',
	# 					hsllightness: 'Lightness',
	# 					preview: 'Preview',
	# 					opacity: 'Opacity'
	# 				},
	# 				customswatches: "different-swatches-groupname",
	# 				swatches: false,
	# 				# swatches: g.defaultColors,
	# 				# hsvpanel: true,
	# 				onchange: (container, color) ->
	# 					colorInputJ = this.connectedinput
	# 					initialized = parseInt(colorInputJ.attr('data-initialized'))
	# 					gradient = parseInt(colorInputJ.attr('data-gradient')
	# 					parameterName = colorInputJ.attr('data-parameter-name')
	# 					value = g.items[colorInputJ.attr('data-item-pk')]?.data[parameterName])

	# 					if not initialized
	# 						initializeColorPicker(colorInputJ, container, gradient, parameterName, value)

	# 					if gradient
	# 						g.tools['Gradient'].colorChange(color.tiny.toRgbString(), parameterName, colorInputJ, value)
	# 					else
	# 						parameter.onChange(color.tiny.toRgbString())

	# 					colorInputCheckbox = colorInputJ.siblings('[type="checkbox"]')[0]
	# 					colorInputCheckbox.checked = true
	# 			})

	# 			colorInputJ.on 'shown.bs.popover', ()->
	# 				console.log 'shown'
	# 				return

	# 			colorInputJ.on 'hidden.bs.popover', ()->
	# 				console.log 'hidden'
	# 				return

	# 			# colorInputJ.popover( trigger: 'click' )

	# 			colorInputJ.attr('data-initialized', 0)
	# 			colorInputJ.attr('data-gradient', Number(value?.gradient?))
	# 			colorInputJ.attr('data-item-pk', item?.pk or item?.id)
	# 			colorInputJ.attr('data-parameter-name', name)

	# 			# inputJ.click ()->
	# 			# 	console.log 'color click'
	# 			# 	guiJ = $(g.gui.domElement)
	# 			# 	colorPickerPopoverJ = $(".cp-popover-container .popover")

	# 			# 	# # swatchesJ = colorPickerPopoverJ.find('.cp-swatches')
	# 			# 	checkboxJ = $("<label><input type='checkbox' class='gradient-checkbox' form-control>Gradient</label>")
	# 			# 	checkboxJ.insertBefore(colorPickerPopoverJ.find('.cp-preview'))
	# 			# 	checkboxJ.css( 'color': 'black' )
	# 			# 	checkboxJ.find('input').click (event)->
	# 			# 		if this.checked
	# 			# 			g.tools['Gradient'].select(parameter, colorPicker)
	# 			# 		else
	# 			# 			g.tools['Select'].select()
	# 			# 		return
	# 			# 	# # swatchesJ.append(gradientSwatchesJ)

	# 			# 	# if guiJ.parent().hasClass("dg-sidebar")
	# 			# 	# 	# position = guiJ.offset().left + guiJ.outerWidth()
	# 			# 	# 	# colorPickerPopoverJ.css( left: position )
	# 			# 	# 	colorPickerPopoverJ.removeClass("left").addClass("right")
	# 			# 	# 	# $(".cp-popover-container .arrow").hide()
	# 			# 	# # else
	# 			# 	# # 	position = guiJ.offset().left - colorPickerPopoverJ.width()
	# 			# 	# # 	colorPickerPopoverJ.css( left: position )
	# 			# 	return
	# 			checkboxJ.change ()-> if this.checked then parameter.onChange(colorInputJ.val()) else parameter.onChange(null)
	# 			datFolder.__controllers[datFolder.__controllers.length-1].rValue = () -> return if checkboxJ[0].checked then colorInputJ.val() else null
	# 			controller.rSetValue = (value, item, checked)->
	# 				if checked
	# 					if value? then colorInputJ.trigger("colorpickersliders.updateColor", value)
	# 				checkboxJ[0].checked = checked
	# 				return
	# 		when 'slider', 'checkbox', 'dropdown', 'button', 'button-group', 'radio-button-group', 'string', 'input-typeahead'
	# 			obj[name] = value
	# 			firstOptionalParameter = if parameter.min? then parameter.min else parameter.values
	# 			controllerBox = datFolder.add(obj, name, firstOptionalParameter, parameter.max)
	# 			.name(parameter.label)
	# 			.onChange(parameter.onChange)
	# 			.onFinishChange(parameter.onFinishChange)
	# 			controller = datFolder.__controllers.last()
	# 			if parameter.step? then controller.step?(parameter.step)
	# 			controller.rValue = controller.getValue

	# 			controller.rSetValue = parameter.setValue
	# 			updateItemControllers(parameter, name, item, controller)
	# 			parameter.initializeController?(controller, item)

	# 		else
	# 			console.log 'unknown parameter type'

	# 	return

	# # update parameters according to the selected tool or items
	# # @param tools [{ tool: RTool constructor, item: RItem } or Array of { tool: RTool constructor, item: RItem }] list of tools from which controllers will be created or updated
	# # @param resetValues [Boolean] true to reset controller values, false to let them untouched (values must be reset when selecting a new tool, but not when creating another similar shape... this must be improved)

	# g.updateParameters = (tools, resetValues=false)->

	# 	# add every controllers in g.unusedControllers (we will potentially remove them all)
	# 	g.unusedControllers = []
	# 	for folderName, folder of g.gui.__folders
	# 		for controller in folder.__controllers
	# 			if not g.parameters[controller.property]?.permanent
	# 				g.unusedControllers.push(controller)

	# 	if not Array.isArray(tools) # make tools an array if it was not
	# 		tools = [tools]

	# 	# for all tools: add one controller per parameter to corresponding folder (create folder if it does not exist)
	# 	for toolObject in tools											# for all tools
	# 		tool = toolObject.tool
	# 		item  = toolObject.item
	# 		for folderName, folder of tool.parameters() 				# for all folders of the tool
	# 			folderExists = g.gui.__folders[folderName]?
	# 			datFolder = if folderExists then g.gui.__folders[folderName] else g.gui.addFolder(folderName) 	# get or create folder
	# 			for name, parameter of folder  							# for all parameters of the folder
	# 				if name != 'folderIsClosedByDefault'
	# 					addItem(name, parameter, item, datFolder, resetValues)

	# 			# open folder if it did not exist (and is opened by default)
	# 			if not folderExists and not folder.folderIsClosedByDefault
	# 				datFolder.open()

	# 	# remove all controllers which are not used anymore
	# 	for unusedController in g.unusedControllers
	# 		for folderName, folder of g.gui.__folders
	# 			if folder.__controllers.indexOf(unusedController)>=0
	# 				folder.remove(unusedController)
	# 				folder.__controllers.remove(unusedController)
	# 				if folder.__controllers.length==0
	# 					g.gui.removeFolder(folderName)

	# 	# if dat.gui is in sidebar refresh its size and visibility in 500 milliseconds,
	# 	# (to fix a bug: sometimes dat.gui is too small, with a scrollbar or is not visible)
	# 	if $(g.gui.domElement).parent().hasClass('dg-sidebar')
	# 		setTimeout( ()->
	# 			$(g.gui.domElement).find("ul:first").css( 'height': 'initial' )
	# 			$(g.gui.domElement).css( 'opacity': 1, 'z-index': 'auto' )
	# 		,
	# 		500)
	# 	return

	# g.updateParametersForSelectedItems = ()->
	# 	g.callNextFrame(g.updateParametersForSelectedItemsCallback, 'updateParametersForSelectedItems')
	# 	return

	# g.updateParametersForSelectedItemsCallback = ()->
	# 	console.log 'updateParametersForSelectedItemsCallback'
	# 	items = g.selectedItems.map( (item)-> return { tool: item.constructor, item: item } )
	# 	g.updateParameters(items, true)
	# 	return



	# g.setControllerValueByName = (name, value, item)->
	# 	checked = value?
	# 	for folderName, folder of g.gui.__folders
	# 		for controller in folder.__controllers
	# 			if controller.property == name
	# 				g.setControllerValue(controller, { min: controller.__min, max: controller.__max }, value, item, checked)
	# 				break
	# 	return

	class Controller

		constructor: (@name, @parameter, @folder)->
			@folder.controllers[@name] = @
			@initialize(@parameter.value or @parameter.default)
			return

		initialize: (value)->

			@parameter.onChange ?= @onChange

			object = {}
			object[@name] = value
			firstOptionalParameter = if @parameter.min? then @parameter.min else @parameter.values

			controllerBox = @folder.datFolder.add(object, @name, firstOptionalParameter, @parameter.max)
			.name(@parameter.label)
			.onChange(@parameter.onChange)
			.onFinishChange(@parameter.onFinishChange)

			@datController = @folder.datFolder.__controllers.last()

			if @parameter.step? then @datController.step(@parameter.step)

			return

		onChange = (value) ->
			g.c = @
			for item in g.selectedItems
				# do not update if the value was never set (not even to null), update if it was set (even to null, for colors)
				if typeof item.data?[name] isnt 'undefined'
					item.setParameterCommand(name, value)
			return

		getValue: ()->
			@datController.getValue()
			return

		setValue: (value)->
			@datController.object[@datController.property] = value
			@datController.updateDisplay()
			@parameter.setValue?(value)
			return

		addItems: (items)->
			@items = @items.concat(items)
			controlled = @items.first() or g.selectedTool
			controlled.parameterControllers ?= {}
			controlled.parameterControllers[@name] = @
			return

		reset: ()->
			@items = []
			return

		remove: ()->
			@folder.datFolder.remove(@datController)
			@folder.datFolder.__controllers.remove(@datController)

			delete @folder.controllers[@name]
			if Object.keys(@folder.controllers).length == 0
				@folder.remove()

			@folder = null
			@name = null
			return

	g.Controller = Controller

	class ColorController

		constructor: (@name, @parameter, @folder)->
			super(@name, @parameter, @folder)
			return

		initialize: (value)->

			object = {}
			object[@name] = value

			controllerBox = @folder.datFolder.add(object, @name)
			.name(@parameter.label)
			.onChange(@parameter.onChange)
			.onFinishChange(@parameter.onFinishChange)

			@datController = @folder.datFolder.__controllers.last()

			@colorInputJ = $(@datController.domElement).find('input')
			@colorInputJ.addClass("color-input")
			@enableCheckboxJ = $('<input type="checkbox">')
			@enableCheckboxJ.insertBefore(@colorInputJ)
			@enableCheckboxJ[0].checked = value or parameter.defaultCheck

			if value.gradient?
				@gradient = true
				value = value.gradient.stops[0].color.toCSS()

			@colorInputJ.ColorPickerSliders(
				title: parameter.label
				placement: 'auto'
				size: 'sm'
				color: initialValue
				order:
					hsl: 1
					rgb: 2
					opacity: 3
					preview: 4
				labels:
					rgbred: 'Red'
					rgbgreen: 'Green'
					rgbblue: 'Blue'
					hslhue: 'Hue'
					hslsaturation: 'Saturation'
					hsllightness: 'Lightness'
					preview: 'Preview'
					opacity: 'Opacity'
				customswatches: "different-swatches-groupname"
				swatches: false
				onchange: colorPickerChanged
				# swatches: g.defaultColors
				# hsvpanel: true
				# trigger: 'click'
				# hsvpanel: true
			)

			@colorInputJ.on 'shown.bs.popover', @initializeColorPicker

			@enableCheckboxJ.change(@enableCheckboxChanged)

			return

		getValue: ()->
			return if @enableCheckboxJ[0].checked then colorInputJ.val() else null

		setValue: (value)->
			super(value)
			@enableCheckboxJ[0].checked = value?
			@colorInputJ.trigger("colorpickersliders.updateColor", value)
			return

		enableCheckboxChanged: (event)=>
			@parameter.onChange(@getValue())
			return

		gradientCheckboxChanged: (event)=>
			@gradient = event.target.checked

			if @gradient
				g.tools['Gradient'].select(@)
			else
				g.tools['Select'].select()
			return

		initializeColorPicker: (event)=>
			containerJ = $('#'+$(event.target).attr('aria-describedby'))
			checkboxJ = $("<label><input type='checkbox' class='gradient-checkbox' form-control>Gradient</label>")
			checkboxJ.insertBefore(containerJ.find('.cp-preview'))
			checkboxJ.css( 'color': 'black' )

			checkboxJ.find('input').click(@gradientCheckboxChanged)

			if @gradient
				checkboxJ.find('input').attr('checked', true)
				g.tools['Gradient'].select(@)

			return

		colorPickerChanged: (container, color)=>
			color = color.tiny.toRgbString()

			if @gradient
				g.tools['Gradient'].colorChange(color, @)
			else
				@parameter.onChange(color)

			@enableCheckboxJ[0].checked = true
			return

	g.ColorController = ColorController

	class Folder

		constructor: (@name, closedByDefault=false, @parentFolder)->
			@controllers = {}
			@folders = {}

			if not @parentFolder
				g.controllerManager.folders[@name] = @
				@datFolder = g.gui.addFolder(@name)
			else
				@parentFolder.folders[@name] = @
				@datFolder = @parentFolder.datFolder.addFolder(@name)

			if not closedByDefault
				@datFolder.open()
			return

		remove: ()->
			@datFolder.close()
			$(@datFolder.domElement).parent().remove()
			delete @datFolder.parent.__folders[@datFolder.name]
			g.gui.onResize()
			return

	g.Folder = Folder

	class ControllerManager

		constructor: ()->
			dat.GUI.autoPace = false
			g.gui = new dat.GUI()
			dat.GUI.toggleHide = ()-> return
			@folders = {}

			g.templatesJ.find("button.dat-gui-toggle").clone().appendTo(g.gui.domElement)
			toggleGuiButtonJ = $(g.gui.domElement).find("button.dat-gui-toggle")

			toggleGuiButtonJ.click(@toggleGui)

			if localStorage.optionsBarPosition? and localStorage.optionsBarPosition == 'sidebar'
				$(".dat-gui.dg-sidebar").append(g.gui.domElement)
			else
				$(".dat-gui.dg-right").append(g.gui.domElement)

			return

		toggleGui: ()->
			parentJ = $(g.gui.domElement).parent()
			if parentJ.hasClass("dg-sidebar")
				$(".dat-gui.dg-right").append(g.gui.domElement)
				localStorage.optionsBarPosition = 'right'
			else if parentJ.hasClass("dg-right")
				$(".dat-gui.dg-sidebar").append(g.gui.domElement)
				localStorage.optionsBarPosition = 'sidebar'
			return

		removeUnusedControllers: ()->
			for folderName, folder of @folders
				if folder.name == 'General' then continue
				for name, controller of folder.controllers
					if not controller.used
						controller.remove()
					else
						controller.used = false 	# for the next time
			return

		updateHeight: ()->

			# # if dat.gui is in sidebar refresh its size and visibility in 500 milliseconds,
			# # (to fix a bug: sometimes dat.gui is too small, with a scrollbar )
			# if $(g.gui.domElement).parent().hasClass('dg-sidebar')
			# 	setTimeout( ()->
			# 		$(g.gui.domElement).find("ul:first").css( 'height': 'initial' )
			# 		$(g.gui.domElement).css( 'z-index': 'auto' )
			# 	,
			# 	500)

			return

		createController: (name, parameter, folder)->
			controller = null
			switch parameter.type
				when 'color'
					controller = new g.ColorController(name, parameter, folder)
				else
					controller = new g.Controller(name, parameter, folder)
			return controller

		initializeControllers: ()->
			for folderName, folder of @folders
				for name, controller of folder.controllers
					controller.parameter.initializeController?(controller)
			return

		resetControllers: ()->
			for folderName, folder of @folders
				for name, controller of folder.controllers
					controller.reset()
			return

		initializeValue: (name, parameter, firstItem)->
			value = null
			if firstItem?.data?[name] isnt undefined
				value = firstItem.data[name]
			else if parameter.default?
				value = parameter.default
			else if parameter.defaultFunction?
				value = parameter.defaultFunction()
			return value

		updateControllers: (tools, resetValues=false)->
			@resetControllers()

			for name, toolType in tools

				for folderName, folderParameters of toolTypes.parameters

					if folderName == 'General' then continue

					folder = @folders[folderName]
					folder ?= new g.Folder(folderName, folderParameters.folderIsClosedByDefault)
					delete folderParameters.folderIsClosedByDefault

					for name, parameter of folderParameters  							# for all parameters of the folder

						controller = folder.controllers[name]

						parameter.value = @initializeValue(name, parameter, toolType.items.first())

						if controller?
							if resetValues then controller.setValue(parameter.value)
						else
							controller ?= @createController(name, parameter, folder)

						if @parameter.addController then controller.addItems(toolType.items)

						controller.used = true

			@removeUnusedControllers()
			@initializeControllers()

			return

		updateParametersForSelectedItems: ()->
			g.callNextFrame(@updateParametersForSelectedItemsCallback, 'updateParametersForSelectedItems')
			return

		updateParametersForSelectedItemsCallback: ()=>
			tools = {}

			for item in g.selectedItems

				tools[item.constructor.name] ?= parameters: item.constructor.parameters(), items: []
				tools[item.constructor.name].items.push(item)

			@updateControllers(tools, true)
			return

		setSelectedTool: (tool)->
			g.cancelCallNextFrame('updateParametersForSelectedItems')
			tools = {}
			tools[tool.constructor.name] = parameter: tool.constructor.parameters(), items: []
			@updateControllers(tools, false)
			return

		updateItemData: (item)->
			for name, folder of @folders
				if name=='General' or name=='Items' then continue
				for name, controller of folder.controllers
					item.data[controller.name] ?= controller.getValue()
			return

		# todo: replace parameters() with getParameters() and get only once

	g.ControllerManager = ControllerManager

	return
