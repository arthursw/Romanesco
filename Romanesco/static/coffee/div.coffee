define [
	'utils', 'item', 'jquery', 'oembed', 'paper'
], (utils) ->

	g = utils.g()

	# todo: change ownership through websocket?
	# todo: change lock/link popover to romanesco alert?

	# RDiv is a div on top of the canvas (i.e. on top of the paper.js project) which can be resized, unless it is locked
	# it is lock if it is owned by another user
	#
	# There are different RDivs, with different content:
	#     they define areas which can only be modified by a single user (the one who created the); all RItems in the area is the property of this user
	# - RText: a textarea to write some text. The text can have any google font, any effect, but the whole text has the same formating.
	# - RMedia: an image, video or any content inside an iframe (can be a [shadertoy](https://www.shadertoy.com/))
	# - RSelectionRectangle: a special div just to defined a selection rectangle, user by {ScreenshotTool}
	#
	class RDiv extends g.RContent

		@zIndexMin = 1
		@zIndexMax = 100000

		# parameters are defined as in {RTool}
		@parameters: ()->
			if @parameters then return @parameters

			parameters = super()

			strokeWidth = $.extend(true, {}, g.parameters.strokeWidth)
			strokeWidth.default = 1
			strokeColor = $.extend(true, {}, g.parameters.strokeColor)
			strokeColor.default = 'black'

			parameters['Style'].strokeWidth = strokeWidth
			parameters['Style'].strokeColor = strokeColor

			@parameters = parameters
			return parameters

		@initializeParameters: ()->
			# parameters = super()

			strokeWidth = $.extend(true, {}, g.parameters.strokeWidth)
			strokeWidth.default = 1
			strokeColor = $.extend(true, {}, g.parameters.strokeColor)
			strokeColor.default = 'black'

			parameters = {}
			parameters['Style'] ?= {}
			parameters['Style'].strokeWidth = strokeWidth
			parameters['Style'].strokeColor = strokeColor

			@parameters = parameters
			return parameters

		@initializeParameters()

		@updateHiddenDivs: (event)->
			if g.hiddenDivs.length > 0
				point = new Point(event.pageX, event.pageY)
				projectPoint = view.viewToProject(point)
				for div in g.hiddenDivs
					if not div.getBounds().contains(projectPoint)
						div.show()
			return

		@showDivs: ()->
			while g.hiddenDivs.length > 0
				g.hiddenDivs.first().show()
			return

		@updateZIndex: (sortedDivs)->
			for div, i in sortedDivs
				div.divJ.css( 'z-index': i )
			return

		# add the div jQuery element (@divJ) on top of the canvas and intialize it
		# initialize @data
		# @param bounds [Paper Rectangle] the bounding box of the div (@rectangle extended depending on the rotation)
		# @param rectangle [Paper Rectangle]  the rectangle which defines the div position and size
		# @param owner [String] the username of the owner of the div
		# @param pk [ID] the primary key of the div
		# @param lock [Boolean] (optional) whether the pk of the lock (if locked)
		# @param data [Object] the data of the div (containing the stroke width, colors, etc.)
		# @param date [Number] the date of the div (used as zindex)
		constructor: (bounds, @data=null, @pk=null, @date, @lock=null) ->
			# @rectangle is equal to bounds when creating it, and is stored in @data.rectangle when loading it
			@rectangle = if @data?.rectangle? then new Rectangle(@data.rectangle) else bounds

			@controller = this
			@object_type = @constructor.object_type

			# initialize @divJ: main jQuery element of the div
			separatorJ = g.stageJ.find("." + @object_type + "-separator")
			@divJ = g.templatesJ.find(".custom-div").clone().insertAfter(separatorJ)

			@divJ.mouseenter (event)=>
				for item in g.selectedItems
					if item != @ and item.getBounds().intersects(@getBounds())
						@hide()
						break
				return

			if not @lock
				super(@data, @pk, @date, g.divList, g.sortedDivs)
			else
				super(@data, @pk, @date, @lock.itemListsJ.find('.rDiv-list'), @lock.sortedDivs)

			@maskJ = @divJ.find(".mask")

			@divJ.css(width: @rectangle.width, height: @rectangle.height)

			@updateTransform(false)

			if @owner != g.me and @lock? 	# lock div it is not mine and it is locked
				@divJ.addClass("locked")

			@divJ.attr("data-pk",@pk)

			@divJ.controller = @
			@setCss()

			g.divs.push(@)

			if g.selectedTool.name == 'Move' then @disableInteraction()

			@divJ.click (event)=>
				if @selectionRectangle? then return
				if not event.shiftKey
					g.deselectAll()
				@select()
				return

			if not bounds.contains(@rectangle.expand(-1))
				console.log "Error: invalid div"
				@remove()

			return

		hide: ()->
			@divJ.css( opacity: 0.5, 'pointer-events': 'none' )
			g.hiddenDivs.push(@)
			return

		show: ()->
			@divJ.css( opacity: 1, 'pointer-events': 'auto' )
			g.hiddenDivs.remove(@)
			return

		save: (addCreateCommand=true) ->
			if g.rectangleOverlapsTwoPlanets(@rectangle)
				return

			if @rectangle.area == 0
				@remove()
				g.romanesco_alert "Error: your div is not valid.", "error"
				return

			args =
				city: g.city
				box: g.boxFromRectangle(@getBounds())
				object_type: @object_type
				date: Date.now()
				data: @getStringifiedData()

			Dajaxice.draw.saveDiv(@saveCallback, args)
			super
			return

		# check if the save was successful and set @pk if it is
		saveCallback: (result)=>
			g.checkError(result)
			if not result.pk?  		# if @pk is null, the path was not saved, do not set pk nor rasterize
				@remove()
				return
			@owner = result.owner
			@setPK(result.pk)
			if @updateAfterSave?
				@update(@updateAfterSave)
			super
			return

		moveTo: (position, update)->
			super(position, update)
			@updateTransform()
			return

		setRectangle: (rectangle, update)->
			super(rectangle, update)
			@updateTransform()
			return

		setRotation: (rotation, update)->
			super(rotation, update)
			@updateTransform()
			return

		# update the scale and position of the RDiv (depending on its position and scale, and the view position and scale)
		# if zoom equals 1, do no use css translate() property to avoid blurry text
		updateTransform: ()->
			# the css of the div in styles.less: transform-origin: 0% 0% 0

			viewPos = view.projectToView(@rectangle.topLeft)
			# viewPos = new Point( -g.offset.x + @position.x, -g.offset.y + @position.y )
			if view.zoom == 1 and ( @rotation == 0 or not @rotation? )
				@divJ.css( 'left': viewPos.x, 'top': viewPos.y, 'transform': 'none' )
			else
				sizeScaled = @rectangle.size.multiply(view.zoom)
				translation = viewPos.add(sizeScaled.divide(2))
				css = 'translate(' + translation.x + 'px,' + translation.y + 'px)'
				css += 'translate(-50%, -50%)'
				css += ' scale(' + view.zoom + ')'
				if @rotation then css += ' rotate(' + @rotation + 'deg)'

				@divJ.css( 'transform': css, 'top': 0, 'left': 0, 'transform-origin': '50% 50%' )

				# css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
				# css += ' scale(' + view.zoom + ')'

				# @divJ.css( 'transform': css, 'top': 0, 'left': 0 )

			@divJ.css( width: @rectangle.width, height: @rectangle.height )

			return

		# insert above given *div*
		# @param div [RDiv] div on which to insert this
		# @param index [Number] the index at which to add the div in g.sortedDivs
		insertAbove: (div, index=null, update=false)->
			super(div, index, update)
			if not index then @constructor.updateZIndex(@sortedItems)
			return

		# insert below given *div*
		# @param div [RDiv] div under which to insert this
		# @param index [Number] the index at which to add the div in g.sortedDivs
		insertBelow: (div, index=null, update=false)->
			super(div, index, update)
			if not index then @constructor.updateZIndex(@sortedItems)
			return

		beginSelect: (event) =>
			super(event)
			if @selectionState? then g.currentDiv = @
			return

		endSelect: (event) =>
			super(event)
			g.currentDiv = null
			return

		# mouse interaction must be disabled when user has the move tool (a click on an RDiv must not start a resize action)
		# disable user interaction on this div by putting a transparent mask (div) on top of the div
		disableInteraction: () ->
			@maskJ.show()
			return

		# see {RDiv#disableInteraction}
		# enable user interaction on this div by hiding the mask (div)
		enableInteraction: () ->
			@maskJ.hide()
			return

		# called when a parameter is changed:
		# - from user action (parameter.onChange)
		# @param name [String] the name of the value to change
		# @param value [Anything] the new value
		setParameter: (name, value)->
			super(name, value)
			switch name
				when 'strokeWidth', 'strokeColor', 'fillColor'
					@setCss()
			return

		getUpdateFunction: ()->
			return 'updateDiv'

		getUpdateArguments: (type)->
			switch type
				when 'z-index'
					args = pk: @pk, date: @date
				else
					args =
						pk: @pk
						box: g.boxFromRectangle(@getBounds())
						data: @getStringifiedData()
			return args

		# update the RDiv in the database
		update: (type) =>
			if not @pk?
				@updateAfterSave = type
				return
			delete @updateAfterSave

			bounds = @getBounds()

			# check if position is valid
			if g.rectangleOverlapsTwoPlanets(bounds)
				return

			Dajaxice.draw.updateDiv( @updateCallback, @getUpdateArguments(type) )

			return

		updateCallback: (result)->
			g.checkError(result)
			return

		select: (updateOptions, updateSelectionRectangle=true) =>
			if not super(updateOptions, updateSelectionRectangle) or @divJ.hasClass("selected") then return false
			if g.selectedTool != g.tools['Select'] then g.tools['Select'].select()
			@divJ.addClass("selected")
			return true

		# common to all RItems
		# deselect the div
		deselect: () =>
			if not super() then return false
			if not @divJ.hasClass("selected") then return
			@divJ?.removeClass("selected")
			return true

		# update basic apparence parameters (fill color, stroke color and stroke width) from @data
		setCss: ()->
			@setFillColor()
			@setStrokeColor()
			@setStrokeWidth()
			return

		# update fill color from @data.fillColor
		setFillColor: ()->
			@contentJ?.css( 'background-color': @data.fillColor ? 'transparent')
			return

		# update stroke color from @data.strokeColor
		setStrokeColor: ()->
			@contentJ?.css( 'border-color': @data.strokeColor ? 'transparent')
			return

		# update stroke width from @data.strokeWidth
		setStrokeWidth: ()->
			@contentJ?.css( 'border-width': @data.strokeWidth ? '0')
			return

		# common to all RItems
		# called by @delete() and to update users view through websockets
		# @delete() removes the path and delete it in the database
		# @remove() just removes visually
		remove: () ->
			@deselect()
			@divJ.remove()
			g.divs.remove(@)
			if @data.loadEntireArea then g.entireAreas.remove(@)
			if g.divToUpdate==@ then delete g.divToUpdate
			super()
			return

		# called when user deletes the item by pressing delete key or from the gui
		# @delete() removes the path and delete it in the database
		# @remove() just removes visually
		delete: () ->
			if @lock? and @lock.owner != g.me then return
			@remove()
			if not @pk? then return
			if not @socketAction then Dajaxice.draw.deleteDiv( g.checkError, { 'pk': @pk } )
			super
			return

	g.RDiv = RDiv

	# RText: a textarea to write some text.
	# The text can have any google font, any effect, but all the text has the same formating.
	class RText extends RDiv
		@rname = 'Text'

		@modalTitle = "Insert some text"
		@modalTitleUpdate = "Modify your text"
		@object_type = 'text'

		# parameters of the RText highly customize the gui (add functionnalities like font selector, etc.)
		@parameters: ()->

			parameters = super()

			parameters['Font'] =
				fontName:
					type: 'input-typeahead'
					label: 'Font name'
					default: ''
					initializeController: (controller)->
						typeaheadJ = $(controller.datController.domElement)
						input = typeaheadJ.find("input")
						inputValue = null

						input.typeahead(
							{ hint: true, highlight: true, minLength: 1 },
							{ valueKey: 'value', displayKey: 'value', source: g.typeaheadFontEngine.ttAdapter() }
						)

						input.on 'typeahead:opened', ()->
							dropDown = typeaheadJ.find(".tt-dropdown-menu")
							dropDown.insertAfter(typeaheadJ.parents('.cr:first'))
							dropDown.css(position: 'relative', display: 'inline-block', right:0)
							return

						input.on 'typeahead:closed', ()->
							if inputValue?
								input.val(inputValue)
							else
								inputValue = input.val()
							for item in g.selectedItems
								item.setFontFamily?(inputValue) 	# not necessarly an RText
							return

						input.on 'typeahead:cursorchanged', ()->
							inputValue = input.val()
							return

						input.on 'typeahead:selected', ()->
							inputValue = input.val()
							return

						input.on 'typeahead:autocompleted', ()->
							inputValue = input.val()
							return

						firstItem = g.selectedItems.first()
						if firstItem?.data?.fontFamily?
							input.val(firstItem.data.fontFamily)

						return
				effect:
					type: 'dropdown'
					label: 'Effect'
					values: ['none', 'anaglyph', 'brick-sign', 'canvas-print', 'crackle', 'decaying', 'destruction',
					'distressed', 'distressed-wood', 'fire', 'fragile', 'grass', 'ice', 'mitosis', 'neon', 'outline',
					'puttinggreen', 'scuffed-steel', 'shadow-multiple', 'static', 'stonewash', '3d', '3d-float',
					'vintage', 'wallpaper']
					default: 'none'
				styles:
					type: 'button-group'
					label: 'Styles'
					default: ''
					setValue: (value)->
						fontStyleJ = $("#fontStyle:first")

						for item in g.selectedItems
							if item.data?.fontStyle?
								if item.data.fontStyle.italic then fontStyleJ.find("[name='italic']").addClass("active")
								if item.data.fontStyle.bold then fontStyleJ.find("[name='bold']").addClass("active")
								if item.data.fontStyle.decoration?.indexOf('underline')>=0
									fontStyleJ.find("[name='underline']").addClass("active")
								if item.data.fontStyle.decoration?.indexOf('overline')>=0
									fontStyleJ.find("[name='overline']").addClass("active")
								if item.data.fontStyle.decoration?.indexOf('line-through')>=0
									fontStyleJ.find("[name='line-through']").addClass("active")
					initializeController: (controller)->
						domElement = controller.datController.domElement
						$(domElement).find('input').remove()

						setStyles = (value)->
							for item in g.selectedItems
								item.changeFontStyle?(value)
							return

						# todo: change fontStyle id to class
						g.templatesJ.find("#fontStyle").clone().appendTo(domElement)
						fontStyleJ = $("#fontStyle:first")
						fontStyleJ.find("[name='italic']").click( (event)-> setStyles('italic') )
						fontStyleJ.find("[name='bold']").click( (event)-> setStyles('bold') )
						fontStyleJ.find("[name='underline']").click( (event)-> setStyles('underline') )
						fontStyleJ.find("[name='overline']").click( (event)-> setStyles('overline') )
						fontStyleJ.find("[name='line-through']").click( (event)-> setStyles('line-through') )

						controller.setValue()
						return
				align:
					type: 'radio-button-group'
					label: 'Align'
					default: ''
					initializeController: (controller)->
						domElement = controller.datController.domElement
						$(domElement).find('input').remove()

						setStyles = (value)->
							for item in g.selectedItems
								item.changeFontStyle?(value)
							return

						g.templatesJ.find("#textAlign").clone().appendTo(domElement)
						textAlignJ = $("#textAlign:first")
						textAlignJ.find(".justify").click( (event)-> setStyles('justify') )
						textAlignJ.find(".align-left").click( (event)-> setStyles('left') )
						textAlignJ.find(".align-center").click( (event)-> setStyles('center') )
						textAlignJ.find(".align-right").click( (event)-> setStyles('right') )
						return
				fontSize:
					type: 'slider'
					label: 'Font size'
					min: 5
					max: 300
					default: 11
				fontColor:
					type: 'color'
					label: 'Color'
					default: 'black'
					defaultCheck: true 					# checked/activated by default or not

			return parameters

		# overload {RDiv#constructor}
		# initialize mouse event listeners to be able to select and edit text, bind key event listener to @textChanged
		constructor: (bounds, @data=null, @pk=null, @date, @lock=null) ->
			super(bounds, @data, @pk, @date, @lock)

			@contentJ = $("<textarea></textarea>")
			@contentJ.insertBefore(@maskJ)
			@contentJ.val(@data.message)

			lockedForMe = @owner != g.me and @lock?

			if lockedForMe
				# @contentJ.attr("readonly", "true")
				message = @data.message
				@contentJ[0].addEventListener("input", (()-> this.value = message), false)

			@setCss()

			@contentJ.focus( () -> $(this).addClass("selected form-control") )
			@contentJ.blur( () -> $(this).removeClass("selected form-control") )
			@contentJ.focus()

			@contentJ.keydown (event)=>
				if event.metaKey or event.ctrlKey
					@deselect()
					event.stopImmediatePropagation()
					return false
				return

			if not lockedForMe
				@contentJ.bind('input propertychange', (event) => @textChanged(event) )

			if @data? and Object.keys(@data).length>0
				@setFont(false)
			return

		# select: (updateOptions=true, updateSelectionRectangle=true)->
		# 	if not super(updateOptions, updateSelectionRectangle) then return false
		# 	return true

		deselect: ()->
			if not super() then return false
			@contentJ.blur()
			return true

		# called whenever the text is changed:
		# emit the new text to websocket
		# update the RText in 1 second (deferred execution)
		# @param event [jQuery Event] the key event
		textChanged: (event) =>
			newText = @contentJ.val()
			@deferredAction(g.ModifyTextCommand, newText)
			# g.deferredExecution(@update, 'update', 1000, ['text'], @)
			return

		setText: (newText, update=false)->
			@data.message = newText
			@contentJ.val(newText)
			if not @socketAction
				if update then @update('text')
				g.chatSocket.emit "bounce", itemPk: @pk, function: "setText", arguments: [newText, false]
			return

		# set the font family for the text
		# - check font validity
		# - add font to the page header (in a script tag, this will load the font)
		# - update css
		# - update RText if *update*
		# @param fontFamily [String] the name of the font family
		# @param update [Boolean] whether to update the RText
		setFontFamily: (fontFamily, update=true)->
			if not fontFamily? then return

			# check font validity
			available = false
			for item in g.availableFonts
				if item.family == fontFamily
					available = true
					break
			if not available then return

			@data.fontFamily = fontFamily

			# WebFont.load( google: {	families: ['Droid Sans', 'Droid Serif']	} )

			g.addFont(fontFamily, @data.effect)
			g.loadFonts()

			@contentJ.css( "font-family": "'" + fontFamily + "', 'Helvetica Neue', Helvetica, Arial, sans-serif")

			if update
				@update()
				# g.chatSocket.emit( "parameter change", g.me, @pk, "fontFamily", @data.fontFamily)

			return

		# only called when user modifies GUI
		# add/remove (toggle) the font style of the text defined by *value*
		# if *value* is 'justify', 'left', 'right' or 'center', the text is aligned as the *value* (the previous value is ignored, no toggle)
		# this only modifies @data, the css will be modified in {RText#setFontStyle}
		# eit the change on websocket
		# @param value [String] the style to toggle, can be 'underline', 'overline', 'line-through', 'italic', 'bold', 'justify', 'left', 'right' or 'center'
		changeFontStyle: (value)=>

			if not value? then return

			if typeof(value) != 'string'
				return

			@data.fontStyle ?= {}
			@data.fontStyle.decoration ?= ''

			switch value
				when 'underline'
					if @data.fontStyle.decoration.indexOf(' underline')>=0
						@data.fontStyle.decoration = @data.fontStyle.decoration.replace(' underline', '')
					else
						@data.fontStyle.decoration += ' underline'
				when 'overline'
					if @data.fontStyle.decoration.indexOf(' overline')>=0
						@data.fontStyle.decoration = @data.fontStyle.decoration.replace(' overline', '')
					else
						@data.fontStyle.decoration += ' overline'
				when 'line-through'
					if @data.fontStyle.decoration.indexOf(' line-through')>=0
						@data.fontStyle.decoration = @data.fontStyle.decoration.replace(' line-through', '')
					else
						@data.fontStyle.decoration += ' line-through'
				when 'italic'
					@data.fontStyle.italic = !@data.fontStyle.italic
				when 'bold'
					@data.fontStyle.bold = !@data.fontStyle.bold
				when 'justify', 'left', 'right', 'center'
					@data.fontStyle.align = value

			# only called when user modifies GUI
			@setFontStyle(true)
			# g.chatSocket.emit( "parameter change", g.me, @pk, "fontStyle", @data.fontStyle)
			return

		# set the font style of the text (update the css)
		# called by {RText#changeFontStyle}
		# @param update [Boolean] (optional) whether to update the RText
		setFontStyle: (update=true)->
			if @data.fontStyle?.italic?
				@contentJ.css( "font-style": if @data.fontStyle.italic then "italic" else "normal")
			if @data.fontStyle?.bold?
				@contentJ.css( "font-weight": if @data.fontStyle.bold then "bold" else "normal")
			if @data.fontStyle?.decoration?
				@contentJ.css( "text-decoration": @data.fontStyle.decoration)
			if @data.fontStyle?.align?
				@contentJ.css( "text-align": @data.fontStyle.align)
			if update
				@update()
			return

		# set the font size of the text (update @data and the css)
		# @param fontSize [Number] the new font size
		# @param update [Boolean] (optional) whether to update the RText
		setFontSize: (fontSize, update=true)->
			if not fontSize? then return
			@data.fontSize = fontSize
			@contentJ.css( "font-size": fontSize+"px")
			if update
				@update()
			return

		# set the font effect of the text, only one effect can be applied at the same time (for now)
		# @param fontEffect [String] the new font effect
		# @param update [Boolean] (optional) whether to update the RText
		setFontEffect: (fontEffect, update=true)->
			if not fontEffect? then return

			g.addFont(@data.fontFamily, fontEffect)

			i = @contentJ[0].classList.length-1
			while i>=0
				className = @contentJ[0].classList[i]
				if className.indexOf("font-effect-")>=0
					@contentJ.removeClass(className)
				i--

			g.loadFonts()

			@contentJ.addClass( "font-effect-" + fontEffect)
			if update
				@update()
			return

		# set the font color of the text, update css
		# @param fontColor [String] the new font color
		# @param update [Boolean] (optional) whether to update the RText
		setFontColor: (fontColor, update=true)->
			@contentJ.css( "color": fontColor ? 'black')
			return

		# update font to match the styles, effects and colors in @data
		# @param update [Boolean] (optional) whether to update the RText
		setFont: (update=true)->
			@setFontStyle(update)
			@setFontFamily(@data.fontFamily, update)
			@setFontSize(@data.fontSize, update)
			@setFontEffect(@data.effect, update)
			@setFontColor(@data.fontColor, update)
			return

		# update = false when called by parameter.onChange from websocket
		# overload {RDiv#setParameter}
		# update text content and font styles, effects and colors
		setParameter: (name, value)->
			super(name, value)
			switch name
				when 'fontStyle', 'fontFamily', 'fontSize', 'effect', 'fontColor'
					@setFont(false)
				else
					@setFont(false)
			return

		# overload {RDiv#delete}
		# do not delete RText if we are editing the text (the delete key is used to delete the text)
		delete: () ->
			if @contentJ.hasClass("selected")
				return
			super()
			return

	g.RText = RText

	# todo: remove @url? duplicated in @data.url or remove data.url
	# todo: websocket the url change

	# RMedia holds an image, video or any content inside an iframe (can be a [shadertoy](https://www.shadertoy.com/))
	# The first attempt is to load the media as an image:
	# - if it succeeds, the image is embedded as a simple image tag,
	#   and can be either be fit (proportion are kept) or resized (dimensions will be the same as RMedia) in the RMedia
	#   (the user can modify this in the gui with the 'fit image' button)
	# - if it fails, RMedia checks if the url start with 'iframe'
	#   if it does, the iframe is embedded as is (this enables to embed shadertoys for example)
	# - otherwise RMedia tries to embed it with jquery oembed (this enable to embed youtube and vimeo videos just with the video link)
	class RMedia extends RDiv
		@rname = 'Media'
		@modalTitle = "Insert a media"
		@modalTitleUpdate = "Modify your media"
		@object_type = 'media'

		@initialize: (rectangle)->
			submit = (data)->
				div = new g.RMedia(rectangle, data)
				div.finish()
				if not div.group then return
				div.save()
				div.select()
				return
			g.RModal.initialize('Add media', submit)
			g.RModal.addTextInput('url', 'http:// or <iframe>', 'url', 'url', 'URL', true)
			g.RModal.show()
			return

		@parameters: ()->

			parameters = super()

			parameters['Media'] =
				url:
					type: 'string'
					label: 'URL'
					default: 'http://'
				fitImage:
					type: 'checkbox'
					label: 'Fit image'
					default: false

			return parameters

		constructor: (bounds, @data=null, @pk=null, @date, @lock=null) ->
			super(bounds, @data, @pk, @date, @lock)
			@url = @data.url
			if @url? and @url.length>0
				@urlChanged(@url, false)

			return

		dispatchLoadedEvent: ()->
			return

		beginSelect: (event)->
			super(event)
			@contentJ?.css( 'pointer-events': 'none' )
			return

		endSelect: (event)->
			super(event)
			@contentJ?.css( 'pointer-events': 'auto' )
			return

		select: (updateOptions=true, updateSelectionRectangle=true)->
			if not super(updateOptions, updateSelectionRectangle) then return false
			@contentJ?.css( 'pointer-events': 'auto' )
			return true

		deselect: ()->
			if not super() then return false
			@contentJ?.css( 'pointer-events': 'none' )
			return true

		# update the size of the iframe according to the size of @divJ
		setRectangle: (rectangle, update)->
			super(rectangle, update)
			width = @divJ.width()
			height = @divJ.height()
			# @contentJ.attr("width", width).attr("height", height).css( "max-width": width, "max-height": height )
			# if @contentJ.find('iframe').length>0
			# 	@contentJ.find('iframe').attr("width", width).attr("height", height).css( "max-width": width, "max-height": height )
			# iframeJ = if @contentJ?.is('iframe') then @contentJ else @contentJ?.find('iframe')
			# iframeJ?.attr("width", width).attr("height", height).css( "max-width": width, "max-height": height )
			@contentJ.attr("width", width).attr("height", height).css( "max-width": width, "max-height": height )
			if not @contentJ?.is('iframe')
				@contentJ.find('iframe').attr("width", width).attr("height", height).css( "max-width": width, "max-height": height )
			return

		# called when user clicks in the "fit image" button in the gui
		# toggle the 'fit-image' class to fit (proportion are kept) or resize (dimensions will be the same as RMedia) the image in the RMedia
		toggleFitImage: ()->
			if @isImage?
				@contentJ.toggleClass("fit-image", @data.fitImage)
			return

		# overload {RDiv#setParameter}
		# update = false when called by parameter.onChange from websocket
		# toggle fit image if required
		setParameter: (name, value)->
			super(name, value)
			switch name
				when 'fitImage'
					@toggleFitImage()
				when 'url'
					@urlChanged(value, false)
			return

		# return [Boolean] true if the url ends with an image extension: "jpeg", "jpg", "gif" or "png"
		hasImageUrlExt: (url)->
			exts = [ "jpeg", "jpg", "gif", "png" ]
			ext = url.substring(url.lastIndexOf(".")+1)
			if ext in exts
				return true
			return false

		# try to load the url as an image: and call {RMedia#loadMedia} with the following string:
		# - 'success' if it succeeds
		# - 'error' if it fails
		# - 'timeout' if there was no response for 1 seconds (wait 5 seconds if the url as an image extension since it is likely that it will succeed)
		checkIsImage: ()->
			timedOut = false
			timeout = if @hasImageUrlExt(@url) then 5000 else 1000
			image = new Image()
			timer = setTimeout(()=>
				timedOut = true
				@loadMedia("timeout")
				return
			, timeout)
			image.onerror = image.onabort = ()=>
				if not timedOut
					clearTimeout(timer)
					@loadMedia('error')
				return
			image.onload = ()=>
				if not timedOut
					clearTimeout(timer)
				else
					@contentJ?.remove()
				@loadMedia('success')
				return
			image.src = @url
			return

		# embed the media in the div (this will load it) and update css
		# called by {RMedia#checkIsImage}
		# @param imageLoadResult [String] the result of the image load test: 'success', 'error' or 'timeout'
		loadMedia: (imageLoadResult)=>
			if imageLoadResult == 'success'
				@contentJ = $('<img class="content image" src="'+@url+'" alt="'+@url+'"">')
				@contentJ.mousedown( (event) -> event.preventDefault() )
				@isImage = true
			else
				# @contentJ = $(@url.replace("http://", ""))

				oembbedContent = ()=>
					@contentJ = $('<div class="content oembedall-container"></div>')
					args =
						includeHandle: false
						embedMethod: 'fill'
						maxWidth: @divJ.width()
						maxHeight: @divJ.height()
						afterEmbed: @afterEmbed
					@contentJ.oembed(@url, args)
					return

				if @url.indexOf("http://")!=0 and @url.indexOf("https://")!=0
					@contentJ = $(@url)
					# if 'url' starts with 'iframe', the user wants to integrate an iframe, not embed using jquery oembed
					if @contentJ.is('iframe')
						@contentJ.attr('width', @divJ.width())
						@contentJ.attr('height', @divJ.height())
					else
						oembbedContent()
				else
					oembbedContent()

			@contentJ.insertBefore(@maskJ)

			@setCss()

			if not @isSelected()
				@contentJ.css( 'pointer-events': 'none' )

			commandEvent = document.createEvent('Event')
			commandEvent.initEvent('command executed', true, true)
			document.dispatchEvent(commandEvent)
			return

		# bug?: called many times when div is resized, maybe because update called urlChanged

		# remove the RMedia content and embed the media from *url*
		# update the RMedia if *updateDiv*
		# @param url [String] the url of the media to embed
		# @param updateDiv [Boolean] whether to update the RMedia
		urlChanged: (url, updateDiv=false) =>
			console.log 'urlChanged, updateDiv: ' + updateDiv + ', ' + @pk
			@url = url

			if @contentJ?
				@contentJ.remove()
				$("#jqoembeddata").remove()

			@checkIsImage()

			# websocket urlchange
			if updateDiv
				# if g.me? then g.chatSocket.emit( "parameter change", g.me, @pk, "url", @url ) # will not work unless url is in @data.url
				@update()
			return

		# set the size of the iframe to fit the size of the media once the media is loaded
		# called when the media embedded with jquery oembed is loaded
		afterEmbed: ()=>
			width = @divJ.width()
			height = @divJ.height()
			@contentJ?.find("iframe").attr("width",width).attr("height",height)
			return

	g.RMedia = RMedia

	return