define [
	'utils', 'item', 'jquery', 'paper'
], (utils) ->

	g = utils.g()

	# RLock are locked area which can only be modified by their author
	# all RItems on the area are also locked, and can be unlocked if the user drags them outside the div

	# There are different RLocks:
	# - RLock: a simple RLock which just locks the area and the items underneath, and displays a popover with a message when the user clicks on it
	# - RLink: extends RLock but works as a link: the one who clicks on it is redirected to the website
	# - RWebsite:
	#    - extends RLock and provide the author a special website adresse
	#    - the owner of the site can choose a few options: "restrict area" and "hide toolbar"
	#    - a user going to a site with the "restricted area" option can not go outside the area
	#    - the tool bar will be hidden to users navigating to site with the "hide toolbar" option
	# - RVideogame:
	#    - a video game is an area which can interact with other RItems (very experimental)
	#    - video games are always loaded entirely (the whole area is loaded at once with its items)

	# an RLock can be set in background mode ({RLock#updateBackgroundMode}):
	# - this hide the jQuery div and display a equivalent rectangle on the paper project instead (named controlPath in the code)
	# - it is usefull to add and edit items on the area
	#

	class RLock extends g.RItem
		@rname = 'Lock'
		@object_type = 'lock'

		@initialize: (rectangle)->
			submit = (data)->
				switch data.object_type
					when 'lock'
						lock = new g.RLock(rectangle, data)
					when 'website'
						lock = new g.RWebsite(rectangle, data)
					when 'video-game'
						lock = new g.RVideoGame(rectangle, data)
					when 'link'
						lock = new g.RLink(rectangle, data)
				lock.save(true)
				lock.update('rectangle') 	# update to add items which are under the lock
				lock.select()
				return
			g.RModal.initialize('Create a locked area', submit)

			radioButtons = [
				{ value: 'lock', checked: true, label: 'Create simple lock', submitShortcut: true, linked: [] }
				{ value: 'link', checked: false, label: 'Create link', linked: ['linkName', 'url', 'message'] }
				{ value: 'website', checked: false, label: 'Create  website (® x2)', linked: ['restrictArea', 'disableToolbar', 'siteName'] }
				{ value: 'video-game', checked: false, label: 'Create  video game (® x2)', linked: ['message'] }
			]

			radioGroupJ = g.RModal.addRadioGroup('object_type', radioButtons)
			g.RModal.addCheckbox('restrictArea', 'Restrict area', "Users visiting your website will not be able to go out of the site boundaries.")
			g.RModal.addCheckbox('disableToolbar', 'Disable toolbar', "Users will not have access to the toolbar on your site.")
			g.RModal.addTextInput('linkName', 'Site name', 'text', '', 'Site name')
			g.RModal.addTextInput('url', 'http://', 'url', 'url', 'URL')
			siteURLJ = $("""
				<div class="form-group siteName">
					<label for="modalSiteName">Site name</label>
					<div class="input-group">
						<input id="modalSiteName" type="text" class="name form-control" placeholder="Site name">
						<span class="input-group-addon">.romanesco.city</span>
					</div>
				</div>
			""")
			siteUrlExtractor = (data, siteURLJ)->
				data.siteURL = siteURLJ.find("#modalSiteName").val()
				return true
			g.RModal.addCustomContent('siteName', siteURLJ, siteUrlExtractor)
			g.RModal.addTextInput('message', 'Enter the message you want others to see when they look at this link.', 'text', '', 'Message', true)

			radioGroupJ.click (event)->
				lockType = radioGroupJ.find('input[type=radio][name=object_type]:checked')[0].value
				for radioButton in radioButtons
					if radioButton.value == lockType
						for name, extractor of g.RModal.extractors
							if radioButton.linked.indexOf(name) >= 0
								extractor.div.show()
							else if name != 'object_type'
								extractor.div.hide()
				return
			radioGroupJ.click()
			g.RModal.show()
			radioGroupJ.find('input:first').focus()
			return

		# # @param point [Paper point] the point to test
		# # @return [RLock] the intersecting lock or null
		# @intersectPoint: (point)->
		# 	for lock in g.locks
		# 		if lock.getBounds().contains(point)
		# 			return g.items[lock.pk]
		# 	return null

		# # @param rectangle [Paper Rectangle] the rectangle to test
		# # @return [Boolean] whether it intersects a lock
		# @intersectsRectangle: (rectangle)->
		# 	return @intersectRectangle(rectangle).length>0

		# @param rectangle [Paper Rectangle] the rectangle to test
		# @return [Array<RLock>] the locks
		@getLockWhichContains: (rectangle)->
			for lock in g.locks
				if lock.getBounds().contains(rectangle)
					return lock
			return null

		# @param rectangle [Paper Rectangle] the rectangle to test
		# @return [Array<RLock>] the intersecting locks
		@getLocksWhichIntersect: (rectangle)->
			locks = []
			for lock in g.locks
				if lock.getBounds().intersects(rectangle)
					locks.push(lock)
			return locks

		@getSelectedLock: (warnIfMultipleLocksSelected)->
			lock = null
			for item in g.selectedItems
				if g.RLock.prototype.isPrototypeOf(item)
					if lock != null and warnIfMultipleLocksSelected
						g.romanesco_alert "Two locks are selected, please choose a single lock.", "Warning"
						return null
					lock = item
			return lock

		@parameters: ()->
			parameters = super()

			strokeWidth = $.extend(true, {}, g.parameters.strokeWidth)
			strokeWidth.default = 1
			strokeColor = $.extend(true, {}, g.parameters.strokeColor)
			strokeColor.default = 'black'
			fillColor = $.extend(true, {}, g.parameters.fillColor)
			fillColor.default = 'white'
			fillColor.defaultCheck = true
			fillColor.defaultFunction = null

			parameters['Style'].strokeWidth = strokeWidth
			parameters['Style'].strokeColor = strokeColor
			parameters['Style'].fillColor = fillColor
			parameters['Options'] =
				addModule:
					type: 'button'
					label: 'Add module'
					default: ()->
						lock = g.RLock.getSelectedLock(true)
						if lock? then g.codeEditor.setLockModule(lock)
					initializeController: (controller, item)->
						lock = g.RLock.getSelectedLock(true)
						if lock? and lock.modulePk?
							$(controller.domElement).parent().find(".property-name").text('Update module')
						return

			return parameters

		constructor: (@rectangle, @data=null, @pk=null, @owner=null, @date, @modulePk) ->
			super(@data, @pk)

			g.locks.push(@)

			@group.name = 'lock group'

			# create background

			@background = new Path.Rectangle(@rectangle)
			@background.name = 'rlock background'
			@background.strokeWidth = if @data.strokeWidth>0 then @data.strokeWidth else 1
			@background.strokeColor = if @data.strokeColor? then @data.strokeColor else 'black'
			@background.fillColor = @data.fillColor or 'white'
			@background.controller = @
			@group.addChild(@background)
			g.lockLayer.addChild(@group)

			# create special list to contains children paths
			@sortedPaths = []
			@sortedDivs = []

			@itemListsJ = g.templatesJ.find(".layer").clone()
			pkString = '' + (@pk or @id)
			pkString = pkString.substring(pkString.length-3)
			title = "Lock ..." + pkString
			if @owner then title += " of " + @owner
			titleJ = @itemListsJ.find(".title")
			titleJ.text(title)
			titleJ.click (event)->
				$(this).parent().toggleClass('closed')
				return

			@itemListsJ.find('.rDiv-list').sortable( stop: g.zIndexSortStop, delay: 250 )
			@itemListsJ.find('.rPath-list').sortable( stop: g.zIndexSortStop, delay: 250 )

			@itemListsJ.mouseover (event)=>
				@highlight()
				return
			@itemListsJ.mouseout (event)=>
				@unhighlight()
				return

			g.itemListsJ.prepend(@itemListsJ)
			@itemListsJ = g.itemListsJ.find(".layer:first")

			# check if items are under this lock
			for pk, item in g.items
				if g.RLock.prototype.isPrototypeOf(item)
					continue
				if item.getBounds().intersects(@rectangle)
					@addItem(item)

			# check if the lock must be entirely loaded
			if @data?.loadEntireArea
				g.entireAreas.push(@)

			if @modulePk?
				Dajaxice.draw.getModuleSource(g.initializeModule, pk: modulePk)

			return

		# @param name [String] the name of the value to change
		# @param value [Anything] the new value
		# @param updateGUI [Boolean] (optional, default is false) whether to update the GUI (parameters bar), true when called from SetParameterCommand
		setParameter: (name, value, updateGUI)->
			super(name, value, updateGUI)
			switch name
				when 'strokeWidth', 'strokeColor', 'fillColor'
					@background[name] = @data[name]
			return

		save: (addCreateCommand=true) ->

			if g.rectangleOverlapsTwoPlanets(@rectangle)
				return

			if @rectangle.area == 0
				@remove()
				g.romanesco_alert "Error: your box is not valid.", "error"
				return

			data = @getData()

			siteData =
				restrictArea: data.restrictArea
				disableToolbar: data.disableToolbar
				loadEntireArea: data.loadEntireArea

			args =
				box: g.boxFromRectangle(@rectangle)
				object_type: @constructor.object_type
				data: JSON.stringify(data)
				siteData: JSON.stringify(siteData)
				name: data.name
			Dajaxice.draw.saveBox( @saveCallback, args)
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

		update: (type) =>
			if not @pk?
				@updateAfterSave = type
				return
			delete @updateAfterSave

			# check if position is valid
			if g.rectangleOverlapsTwoPlanets(@rectangle)
				return

			# initialize data to be saved
			updateBoxArgs =
				box: g.boxFromRectangle(@rectangle)
				pk: @pk
				object_type: @object_type
				name: @data.name
				data: @getStringifiedData()
				updateType: type 		# not used anymore
				modulePk: @modulePk
				# message: @data.message

			# Dajaxice.draw.updateBox( @updateCallback, args )
			args = []
			args.push( function: 'updateBox', arguments: updateBoxArgs )

			if type == 'position' or type == 'rectangle'
				itemsToUpdate = if type == 'position' then @children() else []

				# check if new items are inside @rectangle
				for pk, item of g.items
					if not g.RLock.prototype.isPrototypeOf(item)
						if item.lock != @ and @rectangle.contains(item.getBounds())
							@addItem(item)
							itemsToUpdate.push(item)

				for item in itemsToUpdate
					args.push( function: item.getUpdateFunction(), arguments: item.getUpdateArguments() )

			Dajaxice.draw.multipleCalls( @updateCallback, functionsAndArguments: args)
			return

		updateCallback: (results)->
			for result in results
				g.checkError(result)
			return

		# called when user deletes the item by pressing delete key or from the gui
		# @delete() removes the item and delete it in the database
		# @remove() just removes visually
		delete: () ->
			@remove()
			if not @pk? then return
			if not @socketAction then Dajaxice.draw.deleteBox( g.checkError, { 'pk': @pk } )
			super
			return

		setRectangle: (rectangle, update)->
			super(rectangle, update)
			p = new Path.Rectangle(rectangle)
			@background.segments = p.segments.slice()
			p.remove()
			return

		moveTo: (position, update)->
			delta = position.subtract(@rectangle.center)
			for item in @children()
				item.rectangle.center.x += delta.x
				item.rectangle.center.y += delta.y
				if g.RDiv.prototype.isPrototypeOf(item)
					item.updateTransform()
			super(position, update)
			return

		# check if lock contains its children
		containsChildren: ()->
			for item in @children()
				if not @rectangle.contains(item.getBounds())
					return false
			return true

		showChildren: ()->
			for item in @children()
				item.group?.visible = true
			return

		# can not select a lock which the user does not own
		select: (updateOptions=true) =>
			if not super(updateOptions) or @owner != g.me then return false
			for item in @children()
				item.deselect()
			return true

		remove: () ->
			for path in @children()
				@removeItem(path)

			@itemListsJ.remove()
			@itemListsJ = null
			g.locks.remove(@)
			@background = null
			super
			return

		children: ()->
			return @sortedDivs.concat(@sortedPaths)

		addItem: (item)->
			g.addItemTo(item, @)
			return

		removeItem: (item)->
			g.addItemToStage(item)
			return

		highlight: (color)->
			super()
			if color
				@highlightRectangle.fillColor = color
				@highlightRectangle.strokeColor = color
				@highlightRectangle.dashArray = []
			return

		addModule: (@modulePk)->
			Dajaxice.draw.updateBox( g.checkError, { pk: @pk, modulePk: @modulePk } )
			return

	g.RLock = RLock

	# RWebsite:
	#  - extends RLock and provide the author a special website adresse
	#  - the owner of the site can choose a few options: "restrict area" and "hide toolbar"
	#  - a user going to a site with the "restricted area" option can not go outside the area
	#  - the tool bar will be hidden to users navigating to site with the "hide toolbar" option
	class RWebsite extends RLock
		@rname = 'Website'
		@object_type = 'website'

		# overload {RDiv#constructor}
		# the mouse interaction is modified to enable user navigation (the user can scroll the view by dragging on the website area)
		constructor: (@rectangle, @data=null, @pk=null, @owner=null, date=null) ->
			super(@rectangle, @data, @pk, @owner, date)
			return

		# todo: remove
		# can not enable interaction if the user not owner and is website
		enableInteraction: () ->
			return

	g.RWebsite = RWebsite

	# RVideogame:
	# - a video game is an area which can interact with other RItems (very experimental)
	# - video games are always loaded entirely (the whole area is loaded at the same time with its items)
	# this a default videogame class which must be redefined in custom scripts
	class RVideoGame extends RLock
		@rname = 'Video game'
		@object_type = 'video-game'

		# overload {RDiv#constructor}
		# the mouse interaction is modified to enable user navigation (the user can scroll the view by dragging on the videogame area)
		constructor: (@rectangle, @data=null, @pk=null, @owner=null, date=null) ->
			super(@rectangle, @data, @pk, @owner, date)
			@currentCheckpoint = -1
			@checkpoints = []
			return

		# overload {RDiv#getData} + set data.loadEntireArea to true (we want videogames to load entirely)
		getData: ()->
			data = super()
			data.loadEntireArea = true
			return data

		# todo: remove
		# redefine {RLock#enableInteraction}
		enableInteraction: () ->
			return

		# initialize the video game gui (does nothing for now)
		initGUI: ()->
			console.log "Gui init"
			return

		# update game machanics:
		# called at each frame (currently by the tool event, but should move to main.coffee in the onFrame event)
		# @param tool [RTool] the car tool to get the car position
		updateGame: (tool)->
			for checkpoint in @checkpoints
				if checkpoint.contains(tool.car.position)
					if @currentCheckpoint == checkpoint.data.checkpointNumber-1
						@currentCheckpoint = checkpoint.data.checkpointNumber
						if @currentCheckpoint == 0
							@startTime = Date.now()
							g.romanesco_alert "Game started, go go go!", "success"
						else
							g.romanesco_alert "Checkpoint " + @currentCheckpoint + " passed!", "success"
					if @currentCheckpoint == @checkpoints.length-1
						@finishGame()
			return

		# ends the game: called when user passes the last checkpoint!
		finishGame: ()->
			time = (Date.now() - @startTime)/1000
			g.romanesco_alert "You won ! Your time is: " + time.toFixed(2) + " seconds.", "success"
			@currentCheckpoint = -1
			return

	g.RVideoGame = RVideoGame

	# todo: make the link enabled even with the move tool?
	# RLink: extends RLock but works as a link: the one who clicks on it is redirected to the website
	class RLink extends RLock
		@rname = 'Link'
		@modalTitle = "Insert a hyperlink"
		@modalTitleUpdate = "Modify your link"
		@object_type = 'link'

		@parameters: ()->
			parameters = super()
			delete parameters['Lock']
			return parameters

		constructor: (@rectangle, @data=null, @pk=null, @owner=null, date=null) ->
			super(@rectangle, @data, @pk, @owner, date)

			@linkJ?.click (event)=>
				if @linkJ.attr("href").indexOf("http://romanesc.co/#") == 0
					location = @linkJ.attr("href").replace("http://romanesc.co/#", "")
					pos = location.split(',')
					p = new Point()
					p.x = parseFloat(pos[0])
					p.y = parseFloat(pos[1])
					g.RMoveTo(p, 1000)
					event.preventDefault()
					return false
				return
			return

	g.RLink = RLink
	return