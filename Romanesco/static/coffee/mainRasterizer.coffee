define ['utils'], (utils) ->

	g = utils.g()

	if not window.rasterizerMode then return

	g.initializeRasterizerMode = ()->

		g.initToolsRasterizer = ()->
			g.tools = {}
			g.modules = {}
			for pathClass in g.pathClasses
				g.tools[pathClass.rname] = RPath: pathClass
				g.modules[pathClass.rname] = { name: pathClass.rname, iconURL: pathClass.iconURL, source: pathClass.source, description: pathClass.description, owner: 'Romanesco', thumbnailURL: pathClass.thumbnailURL, accepted: true, coreModule: true, category: pathClass.category }
			g.initializeModules()
			return

		g.fakeFunction = ()->
			return

		g.updateRoom = g.fakeFunction
		g.setControllerValueByName = g.fakeFunction
		g.setControllerValue = g.fakeFunction
		g.deferredExecution = g.fakeFunction
		g.romanesco_alert = g.fakeFunction
		g.rasterizer =
			load: g.fakeFunction
			unload: g.fakeFunction
			move: g.fakeFunction
			rasterizeAreasToUpdate: g.fakeFunction
			addAreaToUpdate: g.fakeFunction
			setQZoomToUpdate: g.fakeFunction
			clearRasters: g.fakeFunction
		jQuery.fn.mCustomScrollbar = g.fakeFunction

		g.selectedToolNeedsDrawings = ()->
			return true

		g.CommandManager = g.fakeFunction
		g.Rasterizer = g.fakeFunction
		g.initializeGlobalParameters = g.fakeFunction
		g.initParameters = g.fakeFunction
		g.initCodeEditor = g.fakeFunction
		g.initSocket = g.fakeFunction
		g.initPosition = g.fakeFunction
		g.updateGrid = g.fakeFunction
		g.RSound = g.fakeFunction
		g.chatSocket = emit: g.fakeFunction
		g.defaultColors = []
		g.gui = __folders: {}
		g.animatedItems = []
		g.areaToRasterize = null				# the area to rasterize

		# rasterizer

		g.createItemsDates = (bounds)->
			itemsDates = {}
			for pk, item of g.items
				# if bounds.contains(item.getBounds())
				type = ''
				if g.RLock.prototype.isPrototypeOf(item)
					type = 'Box'
				else if g.RDiv.prototype.isPrototypeOf(item)
					type = 'Div'
				else if g.RPath.prototype.isPrototypeOf(item)
					type = 'Path'
				itemsDates[pk] = item.lastUpdateDate
				# itemsDates.push( pk: pk, lastUpdate: item.lastUpdateDate, type: type )
			return itemsDates

		# g.removeItemsToUpdate = (itemsToUpdate)->
		# 	for pk in itemsToUpdate
		# 		g.items[pk].remove()
		# 	return


		window.loopRasterize = ()->

			rectangle = g.areaToRasterize

			width = Math.min(1000, rectangle.right - view.bounds.left)
			height = Math.min(1000, rectangle.bottom - view.bounds.top)

			newSize = new Size(width, height)

			if not view.viewSize.equals(newSize)
				topLeft = view.bounds.topLeft
				view.viewSize = newSize
				view.center = topLeft.add(newSize.multiply(0.5))

			imagePosition = view.bounds.topLeft.clone()

			# text = new PointText(view.bounds.center)
			# text.justification = 'center'
			# text.fillColor = 'black'
			# text.content = 'Pos: ' + view.bounds.center.toString()

			# view.update()
			dataURL = g.canvas.toDataURL()

			finished = view.bounds.bottom >= rectangle.bottom and view.bounds.right >= rectangle.right

			if not finished
				if view.bounds.right < rectangle.right
					view.center = view.center.add(1000, 0)
				else
					view.center = new Point(rectangle.left+view.viewSize.width*0.5, view.bounds.bottom+view.viewSize.height*0.5)
			else
				g.areaToRasterize = null
			window.saveOnServer(dataURL, imagePosition.x, imagePosition.y, finished, g.city)
			return

		g.loopRasterize = window.loopRasterize

		g.rasterizeAndSaveOnServer = ()->
			console.log "area rasterized"

			view.viewSize = Size.min(new Size(1000,1000), g.areaToRasterize.size)
			view.center = g.areaToRasterize.topLeft.add(view.size.multiply(0.5))
			g.loopRasterize()

			return

		window.loadArea = (args)->
			console.log "load_area"

			if g.areaToRasterize?
				console.log "error: load_area while loading !!"
				return

			areaObject = JSON.parse(args)

			if areaObject.city != g.city
				g.unload()
				g.city = areaObject.city

			area = g.expandRectangleToInteger(g.rectangleFromBox(areaObject))
			g.areaToRasterize = area
			# view.viewSize = Size.min(area.size, new Size(1000, 1000))

			# move the view
			delta = area.center.subtract(view.center)
			project.view.scrollBy(delta)
			for div in g.divs
				div.updateTransform()

			console.log "call load"

			g.load(area)

			return

		g.loadArea = window.loadArea

		# rasterizer tests

		g.getAreasToUpdate = ()->
			if g.areasToRasterize.length==0 and g.imageSaved
				Dajaxice.draw.getAreasToUpdate(g.getAreasToUpdateCallback)
			return

		g.loadNextArea = ()->
			if g.areasToRasterize.length>0
				area = g.areasToRasterize.shift()
				g.areaToRasterizePk = area._id.$oid
				g.imageSaved = false
				g.loadArea(JSON.stringify(area))
			return

		g.getAreasToUpdateCallback = (areas)->
			g.areasToRasterize = areas
			g.loadNextArea()
			return

		g.testSaveOnServer = (imageDataURL, x, y, finished)->
			if not imageDataURL
				console.log "no image data url"
			g.rasterizedAreasJ.append($('<img src="' + imageDataURL + '" data-position="' + x + ', ' + y + '" finished="' + finished + '">')
			.css( border: '1px solid black'))
			console.log 'position: ' + x + ', ' + y
			console.log 'finished: ' + finished
			if finished
				Dajaxice.draw.deleteAreaToUpdate(g.deleteAreaToUpdateCallback, { pk: g.areaToRasterizePk } )
			else
				g.loopRasterize()
			return

		g.deleteAreaToUpdateCallback = (result)->
			g.checkError(result)
			g.imageSaved = true
			g.loadNextArea()
			return

		g.testRasterizer = ()->
			g.rasterizedAreasJ = $('<div class="rasterized-areas">')
			g.rasterizedAreasJ.css( position: 'absolute', top: 1000, left: 0 )
			$('body').css( overflow: 'auto' ).prepend(g.rasterizedAreasJ)
			window.saveOnServer = g.testSaveOnServer
			g.areasToRasterize = []
			g.imageSaved = true
			setInterval(g.getAreasToUpdate, 1000)
			return

	return
