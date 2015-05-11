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
			item.draw()
			return

		selectItem: (item)->
			return

		deselectItem: (item)->
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

		drawItems: (showPath=false)->
			return

		rasterizeItems: ()->

			for pk, item of g.items
				item.rasterize?()

			return

	g.Rasterizer = Rasterizer

	class SimpleRasterizer extends g.Rasterizer

		@TYPE = 'simple'

		constructor:()->
			super()
			return

		loadItem: (item)->
			super(item)
			item.rasterize()
			return

		selectItem: (item)->
			super(item)
			return

		deselectItem: (item)->
			item.rasterize()
			super(item)
			return

	g.SimpleRasterizer = SimpleRasterizer

	class TileRasterizer extends g.Rasterizer

		@TYPE = 'abstract tile'

		constructor: ()->
			super()
			@itemsToExclude = []
			@areaToRasterize = null 	# areas to rasterize on the client (when user modifies an item)
			@areasToUpdate = [] 		# areas to update stored in server (areas not yet rasterized by the server rasterizer)

			@rasters = {}

			@keepRastersMode = true
			@rasterizationDisabled = false

			@move()
			return

		loadItem: (item)->
			if item.data?.animate or g.selectedToolNeedsDrawings()	# only draw if animated thanks to rasterization
				item.draw()
			if @keepRastersMode
				item.rasterize()
			return

		selectItem: (item)->
			@rasterize(item, true)
			return

		deselectItem: (item)->
			if @keepRastersMode
				item.rasterize()
			@rasterize(item)
			return

		rasterLoaded: (raster)->
			raster.context.clearRect(0, 0, g.scale, g.scale)
			raster.context.drawImage(raster.image, 0, 0)
			raster.ready = true
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

		load: (rasters, qZoom)->
			@move()

			for r in rasters
				x = r.position.x * g.scale
				y = r.position.y * g.scale
				raster = @rasters[x]?[y]
				if raster
					raster.ready = false
					raster.image.src = g.romanescoURL + r.url + '?' + Math.random()

			return

		move: ()->
			qZoom = g.quantizeZoom(1.0 / view.zoom)
			scale = g.scale * qZoom
			qBounds = @quantizeBounds(view.bounds, scale)
			for x in [qBounds.l .. qBounds.r] by scale
				for y in [qBounds.t .. qBounds.b] by scale
					@createRaster(x, y, qZoom)

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

		rasterizeCanvasInRaster: (x, y, canvas, rectangle, qZoom, clearRasters=false)->
			if not @rasters[x]?[y]? then return
			rasterRectangle = @getRasterBounds(x, y)
			intersection = rectangle.intersect(rasterRectangle)
			sourceRectangle = new Rectangle(intersection.topLeft.subtract(rectangle.topLeft).divide(qZoom), intersection.size.divide(qZoom))
			destinationRectangle = new Rectangle(intersection.topLeft.subtract(rasterRectangle.topLeft).divide(qZoom), intersection.size.divide(qZoom))
			context = @rasters[x][y].context
			# context.fillRect(destinationRectangle.x-1, destinationRectangle.y-1, destinationRectangle.width+2, destinationRectangle.height+2)
			if clearRasters then context.clearRect(destinationRectangle.x, destinationRectangle.y, destinationRectangle.width, destinationRectangle.height)
			# if clearRasters
			# 	context.globalCompositeOperation = 'copy' # this clear completely and then draw the new image (not what we want)
			# else
			# 	context.globalCompositeOperation = 'source-over'
			context.drawImage(canvas, sourceRectangle.x, sourceRectangle.y, sourceRectangle.width, sourceRectangle.height,
			destinationRectangle.x, destinationRectangle.y, destinationRectangle.width, destinationRectangle.height)
			return

		rasterizeCanvas: (canvas, rectangle, clearRasters=false)->
			console.log "rasterize: " + rectangle.width + ", " + rectangle.height
			qZoom = g.quantizeZoom(1.0 / view.zoom)
			scale = g.scale * qZoom
			qBounds = @quantizeBounds(rectangle, scale)
			for x in [qBounds.l .. qBounds.r] by scale
				for y in [qBounds.t .. qBounds.b] by scale
					@rasterizeCanvasInRaster(x, y, canvas, rectangle, qZoom, clearRasters)
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

		rasterizeCallback: (step)=>

			console.log "rasterize"

			g.logElapsedTime()

			g.startTimer()

			# show all items
			for pk, item of g.items
				item.group.visible = true

			areas = @splitAreaToRasterize()

			# hide excluded items
			for item in @itemsToExclude
				item.group?.visible = false 	# group is null when item has been deleted

			g.grid.visible = false
			g.selectionLayer.visible = false
			g.carLayer.visible = false
			viewOnFrame = view.onFrame
			view.onFrame = null

			@rasterLayer?.visible = false

			@rasterizeAreas(areas)

			@rasterLayer?.visible = true

			view.onFrame = viewOnFrame
			g.carLayer.visible = true
			g.selectionLayer.visible = true
			g.grid.visible = true

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

			g.stopTimer('Time to rasterize path: ')
			g.logElapsedTime()
			return

		rasterize: (items, excludeItems)->
			if @rasterizationDisabled then return

			console.log "ask rasterize" + (if excludeItems then "exclude items" else "")
			g.logElapsedTime()

			if not g.isArray(items) then items = [items]

			for item in items
				@areaToRasterize ?= item.getDrawingBounds()
				@areaToRasterize = @areaToRasterize.unite(item.getDrawingBounds())
				if excludeItems
					g.pushIfAbsent(@itemsToExclude, item)

			g.callNextFrame(@rasterizeCallback, 'rasterize')
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

		drawItems: (showPath=false)->

			for pk, item of g.items
				if not item.drawing? then item.draw?()
				item.group.visible = showPath or item.selectionRectangle?
				if @keepRastersMode
					item.rasterize?()
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

	g.TileRasterizer = TileRasterizer

	class PaperTileRasterizer extends g.TileRasterizer

		@TYPE = 'paper tile'

		constructor:()->
			@rasterLayer = new Layer()
			@rasterLayer.moveBelow(g.mainLayer)
			@useCanvasMode = true
			super()
			return

		createRaster: (x, y, zoom)->
			if @rasters[x]?[y]? then return

			raster = new Raster()
			raster.position.x = x + 0.5 * g.scale * zoom
			raster.position.y = y + 0.5 * g.scale * zoom
			raster.width = g.scale
			raster.height = g.scale
			raster.scale(zoom)
			raster.context = raster.canvas.getContext('2d')
			@rasterLayer.addChild(raster)
			raster.onLoad = ()=>
				@rasterLoaded(this)
				return
			super(x, y, zoom, raster)
			return

		rasterizeCallback2: ()->

			console.log "rasterize"

			g.logElapsedTime()

			g.startTimer()

			# show all items
			for pk, item of g.items
				item.group.visible = true

			areas = @splitAreaToRasterize()

			# hide excluded items
			for item in @itemsToExclude
				item.group?.visible = false 	# group is null when item has been deleted

			for area in areas
				qZoom = g.quantizeZoom(1.0 / view.zoom)
				scale = g.scale * qZoom
				qBounds = @quantizeBounds(area, scale)
				for x in [qBounds.l .. qBounds.r] by scale
					for y in [qBounds.t .. qBounds.b] by scale
						if not @rasters[x]?[y]? then continue
						rasterRectangle = @getRasterBounds(x, y)

						@rasters[x][y].context.clearRect(0, 0, g.scale, g.scale)

						for pk, item of g.items
							if item.raster?.bounds.intersects(rasterRectangle)
								raster = @rasters[x][y]
								rasterTopLeft = raster.position.subtract(raster.zoom * 0.5 * g.scale)
								position = item.raster.bounds.topLeft.subtract(rasterTopLeft)
								@rasters[x][y].drawImage(item.raster.canvas, position)

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

			g.stopTimer('Time to rasterize path: ')
			g.logElapsedTime()
			return

		rasterizeCallback: (step)=>
			if @useCanvasMode
				super()
			else
				@rasterizeCallback2()
			return

		removeRaster: (raster, x, y)->
			raster.remove()
			super(raster, x, y)
			return

	g.PaperTileRasterizer = PaperTileRasterizer


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

	g.CanvasTileRasterizer = CanvasTileRasterizer

	class FastCanvasTileRasterizer extends g.CanvasTileRasterizer

		@TYPE = 'fast canvas tile'

		constructor:()->
			super()
			return

		loadItem: (item)->
			super(item)
			item.rasterize()
			return

		selectItem: (item)->
			super(item)
			return

		deselectItem: (item)->
			item.rasterize()
			super(item)
			return

	g.FastCanvasTileRasterizer = FastCanvasTileRasterizer

	g.initializeRasterizers = ()->
		g.rasterizers = {}
		new g.Rasterizer()
		new g.CanvasTileRasterizer()
		new g.FastCanvasTileRasterizer()
		g.rasterizer = new g.PaperTileRasterizer()

		g.parameters ?= { renderingMode: values: [], default: g.rasterizer.constructor.TYPE }
		for type, rasterizer of g.rasterizers
			g.parameters.renderingMode.values.push(type)
		return

	g.setRasterizerType = (type)->
		g.unload()
		g.rasterizer = g.rasterizers[type]
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