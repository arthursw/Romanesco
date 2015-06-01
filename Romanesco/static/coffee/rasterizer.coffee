define [
	'utils', 'jquery', 'paper'
], (utils) ->

	g = utils.g()

	#  values: ['one raster per shape', 'paper.js only', 'tiled canvas', 'hide inactives', 'single canvas']

	class Rasterizer
		@TYPE = 'default'
		@MAX_AREA = 1.5
		@UNION_RATIO = 1.5

		constructor:()->
			g.rasterizers[@constructor.TYPE] = @
			@rasterizeItems = true
			return

		quantizeBounds: (bounds=view.bounds, scale=g.scale)->
			quantizedBounds =
				t: g.floorToMultiple(bounds.top, scale)
				l: g.floorToMultiple(bounds.left, scale)
				b: g.floorToMultiple(bounds.bottom, scale)
				r: g.floorToMultiple(bounds.right, scale)
			return quantizedBounds

		rasterize: (items, excludeItems)->
			return

		unload: (limit)->
			return

		load: (rasters, qZoom)->
			return

		move: ()->
			return

		loadItem: (item)->
			item.draw?()
			if @rasterizeItems
				item.rasterize?()
			return

		requestDraw: ()->
			return true

		selectItem: (item)->
			return

		deselectItem: (item)->
			item.rasterize?()
			return

		rasterizeRectangle: (rectangle)->
			return

		addAreaToUpdate: (area)->
			return

		setQZoomToUpdate: (qZoom)->
			return

		rasterizeAreasToUpdate: ()->
			return

		maxArea: ()->
			return view.bounds.area * @constructor.MAX_AREA

		rasterizeView: ()->
			return

		clearRasters: ()->
			return

		drawItems: ()->
			return

		rasterizeAllItems: ()->

			for pk, item of g.items
				item.rasterize?()

			return

		hideOthers: (itemsToExclude)->
			return

		showItems: ()->
			return

		hideRasters: ()->
			return

		showRasters: ()->
			return

		extractImage: (rectangle, redraw)->
			return g.areaToImageDataUrl(rectangle)

	g.Rasterizer = Rasterizer

	class TileRasterizer extends g.Rasterizer

		@TYPE = 'abstract tile'
		@loadingBarJ = null

		constructor: ()->
			super()
			@itemsToExclude = []
			@areaToRasterize = null 	# areas to rasterize on the client (when user modifies an item)
			@areasToUpdate = [] 		# areas to update stored in server (areas not yet rasterized by the server rasterizer)

			@rasters = {}

			@rasterizeItems = true
			@rasterizationDisabled = false
			@autoRasterization = 'deferred'
			@rasterizationDelay = 800

			@renderInView = false

			@itemsAreDrawn = false
			@itemsAreVisible = false

			@move()
			return

		loadItem: (item)->
			if item.data?.animate or g.selectedToolNeedsDrawings()	# only draw if animated thanks to rasterization
				item.draw?()
			else
				@itemsAreDrawn = false
			if @rasterizeItems
				item.rasterize?()
			return

		startLoading: ()->
			@startLoadingTime = view._time
			g.TileRasterizer.loadingBarJ.css( width: 0 )
			g.TileRasterizer.loadingBarJ.show()

			g.deferredExecution(@rasterizeCallback, 'rasterize', @rasterizationDelay)
			return

		stopLoading: (cancelTimeout=true)->
			@startLoadingTime = null
			g.TileRasterizer.loadingBarJ.hide()

			if cancelTimeout
				clearTimeout(g.updateTimeout['rasterize'])
			return

		rasterizeImmediately: ()=>
			@stopLoading()
			@rasterizeCallback()
			return

		updateLoadingBar: (time)->
			if not @startLoadingTime? then return
			duration = 1000 * ( time - @startLoadingTime ) / @rasterizationDelay
			totalWidth = 241
			g.TileRasterizer.loadingBarJ.css( width: duration * totalWidth )
			if duration>=1
				@stopLoading(false)
			return

		drawItemsAndHideRasters: ()->
			@drawItems(true)
			@hideRasters()
			return

		selectItem: (item)->
			@drawItems()
			@rasterize(item, true)

			switch @autoRasterization
				when 'disabled'
					@drawItemsAndHideRasters()
					item.group.visible = true
				when 'deferred'
					@drawItemsAndHideRasters()
					item.group.visible = true
					@stopLoading()
				when 'immediate'
					g.callNextFrame(@rasterizeCallback, 'rasterize')
			return

		deselectItem: (item)->
			if @rasterizeItems
				item.rasterize?()

			@rasterize(item)

			switch @autoRasterization
				when 'deferred'
					@startLoading()
				when 'immediate'
					g.callNextFrame(@rasterizeCallback, 'rasterize')

			return

		rasterLoaded: (raster)->
			raster.context.clearRect(0, 0, g.scale, g.scale)
			raster.context.drawImage(raster.image, 0, 0)
			raster.ready = true
			raster.loaded = true
			allRastersAreReady = true
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					allRastersAreReady &= raster.ready
			if allRastersAreReady
				@rasterizeAreasToUpdate()
			return

		createRaster: (x, y, zoom, raster)->
			raster.zoom = zoom
			raster.ready = true
			raster.loaded = false
			@rasters[x] ?= {}
			@rasters[x][y] = raster
			return

		getRasterBounds: (x, y)->
			size = @rasters[x][y].zoom * g.scale
			return new Rectangle(x, y, size, size)

		removeRaster: (raster, x, y)->
			delete @rasters[x][y]
			if g.isEmpty(@rasters[x]) then delete @rasters[x]
			return

		unload: (limit)->
			qZoom = g.quantizeZoom(1.0 / view.zoom)

			for x, rasterColumn of @rasters
				x = Number(x)
				for y, raster of rasterColumn
					y = Number(y)
					rectangle = @getRasterBounds(x, y)
					if not limit.intersects(rectangle) or @rasters[x][y].zoom != qZoom
						@removeRaster(raster, x, y)

			return

		loadImageForRaster: (raster, url)->
			return

		load: (rasters, qZoom)->
			@move()

			for r in rasters
				x = r.position.x * g.scale
				y = r.position.y * g.scale
				raster = @rasters[x]?[y]
				if raster and not raster.loaded
					raster.ready = false
					url = g.romanescoURL + r.url + '?' + Math.random()
					@loadImageForRaster(raster, url)

			return

		createRasters: (rectangle)->
			qZoom = g.quantizeZoom(1.0 / view.zoom)
			scale = g.scale * qZoom
			qBounds = @quantizeBounds(rectangle, scale)
			for x in [qBounds.l .. qBounds.r] by scale
				for y in [qBounds.t .. qBounds.b] by scale
					@createRaster(x, y, qZoom)
			return

		move: ()->
			@createRasters(view.bounds)
			return

		splitAreaToRasterize: ()->
			maxSize = view.size.multiply(2)

			areaToRasterizeInteger = g.expandRectangleToInteger(@areaToRasterize)
			area = g.expandRectangleToInteger(new Rectangle(@areaToRasterize.topLeft, Size.min(maxSize, @areaToRasterize.size)))
			areas = [area.clone()]

			while area.right < @areaToRasterize.right or area.bottom < @areaToRasterize.bottom
				if area.right < @areaToRasterize.right
					area.x += maxSize.width
				else
					area.x = areaToRasterizeInteger.left
					area.y += maxSize.height

				areas.push(area.intersect(areaToRasterizeInteger))

			return areas

		rasterizeCanvasInRaster: (x, y, canvas, rectangle, qZoom, clearRasters=false, sourceRectangle=null)->
			if not @rasters[x]?[y]? then return
			rasterRectangle = @getRasterBounds(x, y)
			intersection = rectangle.intersect(rasterRectangle)

			destinationRectangle = new Rectangle(intersection.topLeft.subtract(rasterRectangle.topLeft).divide(qZoom), intersection.size.divide(qZoom))

			context = @rasters[x][y].context

			# context.fillRect(destinationRectangle.x-1, destinationRectangle.y-1, destinationRectangle.width+2, destinationRectangle.height+2)

			if clearRasters then context.clearRect(destinationRectangle.x, destinationRectangle.y, destinationRectangle.width, destinationRectangle.height)
			# if clearRasters
			# 	context.globalCompositeOperation = 'copy' # this clear completely and then draw the new image (not what we want)
			# else
			# 	context.globalCompositeOperation = 'source-over'
			if canvas?
				if sourceRectangle?
					sourceRectangle = new Rectangle(intersection.topLeft.subtract(sourceRectangle.topLeft), intersection.size)
				else
					sourceRectangle = new Rectangle(intersection.topLeft.subtract(rectangle.topLeft).divide(qZoom), intersection.size.divide(qZoom))
				context.drawImage(canvas, sourceRectangle.x, sourceRectangle.y, sourceRectangle.width, sourceRectangle.height,
					destinationRectangle.x, destinationRectangle.y, destinationRectangle.width, destinationRectangle.height)
			return

		rasterizeCanvas: (canvas, rectangle, clearRasters=false, sourceRectangle=null)->
			console.log "rasterize: " + rectangle.width + ", " + rectangle.height
			qZoom = g.quantizeZoom(1.0 / view.zoom)
			scale = g.scale * qZoom
			qBounds = @quantizeBounds(rectangle, scale)
			for x in [qBounds.l .. qBounds.r] by scale
				for y in [qBounds.t .. qBounds.b] by scale
					@rasterizeCanvasInRaster(x, y, canvas, rectangle, qZoom, clearRasters, sourceRectangle)
			return

		clearAreaInRasters: (rectangle)->
			@rasterizeCanvas(null, rectangle, true)
			return

		rasterizeArea: (area)->
			view.viewSize = area.size.multiply(view.zoom)
			view.center = area.center
			view.update()

			@rasterizeCanvas(g.canvas, area, true)
			return

		rasterizeAreas: (areas)->
			viewZoom = view.zoom
			viewSize = view.viewSize
			viewPosition = view.center

			view.zoom = 1.0 / g.quantizeZoom(1.0 / view.zoom)

			for area in areas
				@rasterizeArea(area)

			view.zoom = viewZoom
			view.viewSize = viewSize
			view.center = viewPosition
			return

		prepareView: ()->
			# show all items
			for pk, item of g.items
				item.group.visible = true

			# hide excluded items
			for item in @itemsToExclude
				item.group?.visible = false 	# group is null when item has been deleted

			g.grid.visible = false
			g.selectionLayer.visible = false
			g.carLayer.visible = false
			@viewOnFrame = view.onFrame
			view.onFrame = null

			@rasterLayer?.visible = false
			return

		restoreView: ()->
			@rasterLayer?.visible = true

			view.onFrame = @viewOnFrame
			g.carLayer.visible = true
			g.selectionLayer.visible = true
			g.grid.visible = true
			return

		rasterizeCallback: (step)=>

			if not @areaToRasterize then return

			console.log "rasterize"

			g.logElapsedTime()

			g.startTimer()

			if @autoRasterization == 'deferred' or @autoRasterization == 'disabled'
				@showRasters()

			areas = @splitAreaToRasterize()

			if @renderInView
				@prepareView()
				@rasterizeAreas(areas)
				@restoreView()
			else
				sortedItems = g.getSortedItems()
				for area in areas
					# p = new Path.Rectangle(area)
					# p.strokeColor = 'red'
					# p.strokeWidth = 1
					# g.debugLayer.addChild(p)
					@clearAreaInRasters(area)
					for item in sortedItems
						if item.raster?.bounds.intersects(area) and item not in @itemsToExclude
							@rasterizeCanvas(item.raster.canvas, item.raster.bounds.intersect(area), false, item.raster.bounds)

			# hide all items except selected ones and the ones being created
			for pk, item of g.items
				if item == g.currentPaths[g.me] or item.selectionRectangle? then continue
				item.group?.visible = false

			# show excluded items and their children
			for item in @itemsToExclude
				item.group?.visible = true
				item.showChildren?()

			@itemsToExclude = []
			@areaToRasterize = null
			@itemsAreVisible = false

			@stopLoading()

			g.stopTimer('Time to rasterize path: ')
			g.logElapsedTime()
			return

		rasterize: (items, excludeItems)->

			if @rasterizationDisabled then return

			console.log "ask rasterize" + (if excludeItems then " excluding items." else "")
			g.logElapsedTime()

			if not g.isArray(items) then items = [items]
			if not excludeItems then @itemsToExclude = []

			for item in items
				@areaToRasterize ?= item.getDrawingBounds()
				@areaToRasterize = @areaToRasterize.unite(item.getDrawingBounds())
				if excludeItems
					g.pushIfAbsent(@itemsToExclude, item)

			return

		rasterizeRectangle: (rectangle)->
			@drawItems()

			if not @areaToRasterize?
				@areaToRasterize = rectangle
			else
				@areaToRasterize = @areaToRasterize.unite(rectangle)

			g.callNextFrame(@rasterizeCallback, 'rasterize')
			return

		addAreaToUpdate: (area)->
			@areasToUpdate.push(area)
			return

		setQZoomToUpdate: (qZoom)->
			@areasToUpdateQZoom = qZoom
			return

		rasterizeAreasToUpdate: ()->

			if @areasToUpdate.length==0 then return

			@drawItems(true)

			previousItemsToExclude = @itemsToExclude
			previousAreaToRasterize = @areaToRasterize
			previousZoom = view.zoom
			view.zoom = 1.0 / @areasToUpdateQZoom

			@itemsToExclude = []
			for area in @areasToUpdate
				# @createRasters(area)
				@areaToRasterize = area
				@rasterizeCallback()

			@areasToUpdate = []

			@itemsToExclude = previousItemsToExclude
			@areaToRasterize = previousAreaToRasterize
			view.zoom = previousZoom

			return

		clearRasters: ()->
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					raster.context.clearRect(0, 0, g.scale, g.scale)
			return

		drawItems: (showItems=false)->
			if showItems then @showItems()

			if @itemsAreDrawn then return

			for pk, item of g.items
				if not item.drawing? then item.draw?()
				if @rasterizeItems
					item.rasterize?()

			@itemsAreDrawn = true

			return

		showItems: ()->
			if @itemsAreVisible then return

			for pk, item of g.items
				item.group.visible = true

			@itemsAreVisible = true
			return

		disableRasterization: ()->
			@rasterizationDisabled = true
			@clearRasters()
			@drawItems(true)
			return

		enableRasterization: ()->
			@rasterizationDisabled = false
			@rasterizeView()
			return

		rasterizeView: ()->
			@rasterizeRectangle(view.bounds)
			return

		hideRasters: ()->
			return

		showRasters: ()->
			return

		hideOthers: (itemToExclude)->
			console.log itemToExclude.pk
			for pk, item of g.items
				if item != itemToExclude
					item.group.visible = false
			return

		extractImage: (rectangle, redraw)->
			if redraw

				rasterizeItems = @rasterizeItems
				@rasterizeItems = false
				disableDrawing = @disableDrawing
				@disableDrawing = false
				@drawItemsAndHideRasters()

				dataURL = g.areaToImageDataUrl(rectangle)

				if rasterizeItems
					@rasterizeItems = true
					for pk, item of g.items
						item.rasterize?()

				if disableDrawing then @disableDrawing = true

				@showRasters()
				@rasterizeImmediately()

				return dataURL
			else
				return g.areaToImageDataUrl(rectangle)


	g.TileRasterizer = TileRasterizer

	class PaperTileRasterizer extends g.TileRasterizer

		@TYPE = 'paper tile'

		constructor:()->
			@rasterLayer = new Layer()
			@rasterLayer.name = 'raster layer'
			@rasterLayer.moveBelow(g.mainLayer) 	# this will activate the top layer (selection layer or areasToUpdateLayer)
			g.mainLayer.activate()
			super()
			return

		createRaster: (x, y, zoom)->
			if @rasters[x]?[y]? then return

			raster = new Raster()
			raster.name = 'raster: ' + x + ', ' + y
			console.log raster.name
			raster.position.x = x + 0.5 * g.scale * zoom
			raster.position.y = y + 0.5 * g.scale * zoom
			raster.width = g.scale
			raster.height = g.scale
			raster.scale(zoom)
			raster.context = raster.canvas.getContext('2d')
			@rasterLayer.addChild(raster)
			raster.onLoad = ()=>
				raster.context = raster.canvas.getContext('2d')
				@rasterLoaded(raster)
				return
			super(x, y, zoom, raster)
			return

		removeRaster: (raster, x, y)->
			raster.remove()
			super(raster, x, y)
			return

		loadImageForRaster: (raster, url)->
			raster.source = url
			return

		hideRasters: ()->
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					raster.visible = false
			return

		showRasters: ()->
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					raster.visible = true
			return

	g.PaperTileRasterizer = PaperTileRasterizer


	class InstantPaperTileRasterizer extends g.PaperTileRasterizer

		@TYPE = 'light'

		constructor:()->
			super()
			@disableDrawing = true
			@updateDrawingAfterDelay = true
			@itemsToDraw = {}
			return

		drawItemsAndHideRasters: ()->
			return

		requestDraw: (item, simplified, redrawing)->
			if @disableDrawing
				if @updateDrawingAfterDelay
					time = Date.now()
					delay = 500
					if not @itemsToDraw[item.pk]? or time-@itemsToDraw[item.pk] < delay
						@itemsToDraw[item.pk] = time
						g.deferredExecution(item.draw, 'item.draw:'+item.pk, delay, [simplified, redrawing], item)
					else
						delete @itemsToDraw[item.pk]
						return true
			return not @disableDrawing

		selectItem: (item)->
			if not @rasterizeItems
				item.removeDrawing()
			super(item)
			return

		deselectItem: (item)->
			super(item)

			if not @rasterizeItems
				item.replaceDrawing()
			return

		rasterizeCallback: (step)->

			@disableDrawing = false

			for pk, item of g.items
				if item.drawn? and not item.drawn and item.getDrawingBounds().intersects(@areaToRasterize)
					item.draw?()
					if @rasterizeItems then item.rasterize?()

			@disableDrawing = true

			super(step)

			return

		rasterizeAreasToUpdate: ()->
			@disableDrawing = false
			super()
			@disableDrawing = true
			return

	g.InstantPaperTileRasterizer = InstantPaperTileRasterizer

	class CanvasTileRasterizer extends g.TileRasterizer

		@TYPE = 'canvas tile'

		constructor: ()->
			super()
			return

		createRaster: (x, y, zoom)->
			raster = @rasters[x]?[y]
			if raster?
				# if raster.zoom != zoom
				# 	scale = raster.zoom / zoom
				# 	raster.zoom = zoom
				# 	raster.context.clearRect(0, 0, g.scale, g.scale)
				# 	raster.context.drawImage(raster.image, 0, 0, raster.image.width * scale, raster.image.height * scale)
				# 	console.log "image scaled by: " + scale
				return

			raster = {}
			raster.canvasJ = $('<canvas hidpi="off" width="' + g.scale + '" height="' + g.scale + '">')
			raster.canvas = raster.canvasJ[0]
			# raster.position = new Point(x, y)
			raster.context = raster.canvas.getContext('2d')
			raster.image = new Image()

			raster.image.onload = ()=>
				@rasterLoaded(raster)
				return

			$("#rasters").append(raster.canvasJ)
			super(x, y, zoom, raster)
			return

		removeRaster: (raster, x, y)->
			raster.canvasJ.remove()
			super(raster, x, y)
			return

		loadImageForRaster: (raster, url)->
			raster.image.src = url
			return

		move: ()->
			super()

			for x, rasterColumn of @rasters
				x = Number(x)
				for y, raster of rasterColumn
					y = Number(y)

					viewPos = view.projectToView(new Point(x, y))

					if view.zoom == 1
						raster.canvasJ.css( 'left': viewPos.x, 'top': viewPos.y, 'transform': 'none' )
					else
						scale = view.zoom * raster.zoom
						css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
						css += ' scale(' + scale + ')'
						raster.canvasJ.css( 'transform': css, 'top': 0, 'left': 0, 'transform-origin': '0 0' )
			return

		hideRasters: ()->
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					raster.canvasJ.hide()
			return

		showRasters: ()->
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					raster.canvasJ.show()
			return

	g.CanvasTileRasterizer = CanvasTileRasterizer

	g.initializeRasterizers = ()->
		g.rasterizers = {}
		new g.Rasterizer()
		new g.CanvasTileRasterizer()
		new g.InstantPaperTileRasterizer()
		g.rasterizer = new g.PaperTileRasterizer()

		return

	g.addRasterizerParameters = ()->

		values = []
		for type, rasterizer of g.rasterizers
			values.push(type)

		g.rasterizerFolder = g.generalFolder.addFolder('Rasterizer')
		divJ = $('<div>')
		divJ.addClass('loadingBar')
		$(g.rasterizerFolder.__ul).find('li.title').append(divJ)
		g.TileRasterizer.loadingBarJ = divJ

		g.rasterizerFolder.add({ renderingMode: g.rasterizer.constructor.TYPE, permanent: true }, 'renderingMode', values)
		.name('Render mode')
		.onFinishChange(g.setRasterizerType)

		g.rasterizerFolder.add({ rasterizeItems: true, permanent: true }, 'rasterizeItems')
		.name('Rasterize items')
		.onFinishChange (value)->
			g.rasterizer.rasterizeItems = value

			if not value
				g.rasterizer.renderInView = true

			for controller in g.rasterizerFolder.__controllers
				if controller.property == 'renderInView'
					if value
						$(controller.__li).show()
					else
						$(controller.__li).hide()
			return

		g.rasterizerFolder.add({ renderInView: false, permanent: true }, 'renderInView')
		.name('Render in view')
		.onFinishChange (value)->
			g.rasterizer.renderInView = value
			return

		g.rasterizerFolder.add({ autoRasterization: 'deferred', permanent: true }, 'autoRasterization', ['immediate', 'deferred', 'disabled'])
		.name('Auto rasterization')
		.onFinishChange (value)->
			g.rasterizer.autoRasterization = value
			return

		g.rasterizerFolder.add({ rasterizationDelay: 800, permanent: true }, 'rasterizationDelay', 0, 10000)
		.name('Delay')
		.onFinishChange (value)->
			g.rasterizer.rasterizationDelay = value
			return

		rasterizeImmediately = ()->
			g.rasterizer.rasterizeImmediately()
			return

		g.rasterizerFolder.add({ rasterizeImmediately: rasterizeImmediately, permanent: true }, 'rasterizeImmediately')
		.name('Rasterize')

		return

	g.setRasterizerType = (type)->
		if type == g.Rasterizer.TYPE
			for controller in g.rasterizerFolder.__controllers
				if controller.property in [ 'renderInView', 'autoRasterization', 'rasterizationDelay', 'rasterizeImmediately' ]
					$(controller.__li).hide()
		else
			for controller in g.rasterizerFolder.__controllers
				$(controller.__li).show()

		g.unload()
		g.rasterizer = g.rasterizers[type]

		for controller in g.rasterizerFolder.__controllers
			if g.rasterizer[controller.property]?
				onFinishChange = controller.__onFinishChange
				controller.__onFinishChange = ()->return
				controller.setValue(g.rasterizer[controller.property])
				controller.__onFinishChange = onFinishChange

		g.load()
		return

	g.hideCanvas = ()->
		g.canvasJ.css opacity: 0
		return

	g.showCanvas = ()->
		g.canvasJ.css opacity: 1
		return

	g.hideRasters = ()->
		$("#rasters").css opacity: 0
		return

	g.showRasters = ()->
		$("#rasters").css opacity: 1
		return


	return