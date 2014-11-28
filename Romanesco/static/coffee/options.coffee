# --- Options --- #

# todo: squarify GUI (http://glyphrstudio.com/sandbox/)
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

this.initOptions = () ->

	g.parameters = {}
	g.parameters.location = 
		type: 'input'
		label: 'Location'
		default: '0.0, 0.0'
		permanent: true
		onFinishChange: (value)->
			g.moving = false
			location.hash = value
			return
	g.parameters.zoom = 
		type: 'slider'
		label: 'Zoom'
		min: 10
		max: 200
		default: 100
		permanent: true
		onChange: (value)->
			g.parameters.zoom.value = value
			g.project.view.zoom = value/100.0
			g.updateGrid()
			for div in g.divs
				div.zoom(g.project.view.zoom)
		onFinishChange: (value) -> return g.load()
	g.parameters.displayGrid = 
		type: 'checkbox'
		label: 'Display grid'
		default: false
		permanent: true
		onChange: (value)->
			g.displayGrid = !g.displayGrid
			g.updateGrid()
			return
	g.parameters.fastMode = 
		type: 'checkbox'
		label: 'Fast mode'
		default: g.fastMode
		permanent: true
		onChange: (value)->
			g.fastMode = value
			return
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
		default: ()-> item.delete() for item in g.selectedItems()
	g.parameters.duplicate =
		type: 'button'
		label: 'Duplicate items'
		default: ()-> item.duplicate() for item in g.selectedItems()
	g.parameters.snap =
		type: 'slider'
		label: 'Snap'
		min: 0
		max: 100
		step: 5
		default: 0
		snap: 0
		permanent: true
		onChange: ()-> g.updateGrid()
	g.parameters.align =
		type: 'button-group'
		label: 'Align'
		value: ''
		initializeController: (controller)->
			$(controller.domElement).find('input').remove()

			align = (type)->
				items = g.selectedItems()
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
			g.templatesJ.find("#align").clone().appendTo(controller.domElement)
			alignJ = $("#align:first")
			alignJ.find("button").click ()-> align($(this).attr("data-type"))
			return
	g.parameters.distribute =
		type: 'button-group'
		label: 'Distribute'
		value: ''
		initializeController: (controller)->
			$(controller.domElement).find('input').remove()

			distribute = (type)->
				items = g.selectedItems()
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
			g.templatesJ.find("#distribute").clone().appendTo(controller.domElement)
			distributeJ = $("#distribute:first")
			distributeJ.find("button").click ()-> distribute($(this).attr("data-type"))
			return

	g.optionsJ = $(".option-list")
	colorName = g.defaultColors.random()
	colorRGBstring = tinycolor(colorName).toRgbString() 
	g.strokeColor = colorRGBstring
	g.fillColor = "rgb(255,255,255,255)"

	g.fillShape = false
	g.strokeWidth = 3

	project.selectedMedias = []
	g.displayGrid = false

	# --- DAT GUI/ --- #

	# todo: use addItems !!!
	dat.GUI.autoPace = false
	g.gui = new dat.GUI()
	g.generalFolder = g.gui.addFolder('General')
	controller = g.generalFolder.add({location: g.parameters.location.default}, 'location').name("Location").onFinishChange( g.parameters.location.onFinishChange )
	g.parameters.location.controller = controller
	g.generalFolder.add({zoom: 100}, 'zoom', 10, 200).name("Zoom").onChange( (value)->
		g.project.view.zoom = value/100.0
		g.updateGrid()
		for div in g.divs
			div.zoom(g.project.view.zoom)
	).onFinishChange( (value) -> g.load() )
	g.generalFolder.add({displayGrid: g.parameters.displayGrid.default}, 'displayGrid', true).name("Display grid").onChange(g.parameters.displayGrid.onChange)
	g.generalFolder.add({fastMode: g.parameters.fastMode.default}, 'fastMode', true).name("Fast mode").onChange(g.parameters.fastMode.onChange)
	g.generalFolder.add(g.parameters.snap, 'snap', g.parameters.snap.min, g.parameters.snap.max).name(g.parameters.snap.label).onChange(g.parameters.snap.onChange)
	$("#dat-gui").append(g.gui.domElement)
	g.generalFolder.open()
	g.gui.constructor.prototype.removeFolder = (name)->
		this.__folders[name].close()
		this.__ul.removeChild(this.__folders[name].domElement.parentElement)
		delete this.__folders[name]
		this.onResize()

	# --- /DAT GUI --- #

	# --- Text options --- #
	g.availableFonts = []
	g.textOptionsJ = g.optionsJ.find(".text-options")

	g.stylePickerJ = g.textOptionsJ.find('#fontStyle')
	# g.subsetPickerJ = g.optionsJ.find('#fontSubset')
	g.effectPickerJ = g.textOptionsJ.find('#fontEffect')
	g.sizePickerJ = g.textOptionsJ.find('#fontSizeSlider')
	g.sizePickerJ.slider().on('slide', (event)-> g.fontSize = event.value )
	
	g.usedFonts = []
	jQuery.support.cors = true

	# $.getJSON("https://www.googleapis.com/webfonts/v1/webfonts?key=AIzaSyD2ZjTQxVfi34-TMKjB5WYK3U8K6y-IQH0", initTextOptions)
	$.getJSON("https://www.googleapis.com/webfonts/v1/webfonts?key=AIzaSyBVfBj_ugQO_w0AK1x9F6yiXByhcNgjQZU", initTextOptions)

this.addFont = (fontFamily, effect)->		
	if not fontFamily? then return

	fontFamilyURL = fontFamily.split(" ").join("+")

	# update g.usedFonts
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
	if not fontAlreadyUsed
		# subsets = [subset]
		# if subset!='latin'
		# 	subsets.push('latin')
		effects = []
		if effect?
			effects.push(effect)
		if not fontFamilyURL or fontFamilyURL == ''
			debugger
		g.usedFonts.push( family: fontFamilyURL, effects: effects )

# todo: use google web api to update text font on load callback
this.loadFonts = ()->
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
		if font.effects.length>0 and not (font.effects.length == 1 and font.effects.first() == 'none')
			newFont += "&effect="
			for effect, i in font.effects
				newFont += effect + '|'					
			newFont = newFont.slice(0,-1)

		fontLink = $('<link class="fonts" rel="stylesheet" type="text/css" href="http://fonts.googleapis.com/css?family=' + newFont + '">')
		
		$('head').append(fontLink)


this.initTextOptions = (data, textStatus, jqXHR) ->

	fontFamilyNames = []
	for item in data.items
		fontFamilyNames.push({ value: item.family })

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

	g.fontSubmitJ = g.textOptionsJ.find('#fontSubmit')


	g.fontSubmitJ.click( (event) ->
		g.setFontStyles()
	)
# todo: better manage parameter..
this.setControllerValue = (controller, parameter, value, item, checked=false)->
	onChange = controller.__onChange
	onFinishChange = controller.__onFinishChange
	controller.__onChange = ()->return
	controller.__onFinishChange = ()->return
	if parameter?
		controller.min?(parameter.min)
		controller.max?(parameter.max)
	controller.setValue(value)
	controller.rSetValue?(value, item, checked)
	controller.__onChange = onChange
	controller.__onFinishChange = onFinishChange

this.addItem = (name, parameter, item, datFolder, resetValues)->
	
	if item? and datFolder.name != 'General' and item.data? and (item.data[name]? or parameter.type=='color') 	# a color can be null, then it is disabled
		value = item.data[name]
	else if parameter.value?
		value = parameter.value
	else if parameter.defaultFunction?
		value = parameter.defaultFunction()
	else
		value = parameter.default

	updateItemControllers = (parameter, name, item, controller)->
		if parameter.addController
			if item?
				item.parameterControllers ?= {}
				item.parameterControllers[name] = controller
			else
				g.selectedTool.parameterControllers ?= {}
				g.selectedTool.parameterControllers[name] = controller
		return

	# check if controller already exists for this parameter, and update if exists
	for controller in datFolder.__controllers
		if controller.property == name and not parameter.permanent
			if resetValues
				# disable onChange and onFinishChange when updating the GUI after selection
				checked = if item? then item.data[name] else parameter.defaultCheck
				g.setControllerValue(controller, parameter, value, item, checked)
				updateItemControllers(parameter, name, item, controller)
			g.unusedControllers.remove(controller)
			return

	if not parameter.onChange?

		parameter.onChange = (value) -> 
			console.log "onChange"
			for item in g.selectedItems()
				if typeof item?.data?[name] isnt 'undefined' 	# do not update if the value was never set (not even to null), update if it was set (even to null, for colors)
					if parameter.step? then value = value-value%parameter.step
					item.data[name] = value
					item.changed = name
					item.parameterChanged()
					if g.me? and datFolder.name != 'General' then g.chatSocket.emit( "parameter change", g.me, item.pk, name, value )
			return

	obj = {}

	switch parameter.type
		when 'color'
			obj[name] = ''
			controller = datFolder.add(obj, name).name(parameter.label)
			inputJ = $(datFolder.domElement).find("div.c > input:last")
			inputJ.addClass("color-input")
			checkboxJ = $('<input type="checkbox">')
			checkboxJ.insertBefore(inputJ)
			checkboxJ[0].checked = if item? and datFolder.name != 'General' then item.data[name]? else parameter.defaultCheck
			colorPicker = inputJ.ColorPickerSliders({
				title: parameter.label,
				placement: 'right',
				color: tinycolor(if value? then value else parameter.default).toRgbString(),
				order: {
					hsl: 1,
					rgb: 2,
					opacity: 3,
					preview: 4
				},
				labels: {
					rgbred: 'Red',
					rgbgreen: 'Green',
					rgbblue: 'Blue',
					hslhue: 'Hue',
					hslsaturation: 'Saturation',
					hsllightness: 'Lightness',
					preview: 'Preview',
					opacity: 'Opacity'
				},
				customswatches: "different-swatches-groupname",
				swatches: ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ],
				onchange: (container, color) -> 
					parameter.onChange(color.tiny.toRgbString())
					checkboxJ[0].checked = true
			})
			checkboxJ.change ()-> if this.checked then parameter.onChange(colorPicker.val()) else parameter.onChange(null)
			datFolder.__controllers[datFolder.__controllers.length-1].rValue = () -> return if checkboxJ[0].checked then colorPicker.val() else null
			controller.rSetValue = (value, item, checked)-> 
				if checked
					if value? then colorPicker.trigger("colorpickersliders.updateColor", value)
				checkboxJ[0].checked = checked
		when 'slider', 'checkbox', 'dropdown', 'button', 'button-group', 'radio-button-group', 'input', 'input-typeahead'
			obj[name] = value
			firstOptionalParameter = if parameter.min? then parameter.min else parameter.values
			controller = datFolder.add(obj, name, firstOptionalParameter, parameter.max).name(parameter.label).onChange(parameter.onChange).onFinishChange(parameter.onFinishChange)
			if parameter.step? then controller.step?(parameter.step)
			datFolder.__controllers[datFolder.__controllers.length-1].rValue = controller.getValue

			controller.rSetValue = parameter.setValue
			updateItemControllers(parameter, name, item, controller)
			parameter.initializeController?(controller, item)
			
		else
			console.log 'unknown parameter type'

	return

this.updateParameters = (tools, resetValues=false)->
	
	# add every controllers in g.unusedcontroller (we will potentially remove them all)
	g.unusedControllers = []
	for folderName, folder of g.gui.__folders
		for controller in folder.__controllers
			if not g.parameters[controller.property]?.permanent
				g.unusedControllers.push(controller)

	if not Array.isArray(tools)
		tools = [tools]

	for toolObject in tools
		tool = toolObject.tool
		item  = toolObject.item
		for folderName, folder of tool.parameters()
			folderExists = g.gui.__folders[folderName]?
			datFolder = if folderExists then g.gui.__folders[folderName] else g.gui.addFolder(folderName)
			for name, parameter of folder
				addItem(name, parameter, item, datFolder, resetValues)
			if not folderExists
				datFolder.open()

	for unusedController in g.unusedControllers
		for folderName, folder of g.gui.__folders
			if folder.__controllers.indexOf(unusedController)>=0
				folder.remove(unusedController)
				folder.__controllers.remove(unusedController)
				if folder.__controllers.length==0
					g.gui.removeFolder(folderName)

	setTimeout( ()->
		$(g.gui.domElement).find("ul:first").css( 'height': 'initial' )
		$(g.gui.domElement).css( 'opacity': 1, 'z-index': 'auto' )
	,
	500)
	return
