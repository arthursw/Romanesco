define [
	'utils', 'jquery', 'paper'
], (utils) ->

	g = utils.g()

	class Rasterizer

		@MAX_AREA = 1.5
		@UNION_RATIO = 1.5

		constructor:()->
			@itemsToExclude = []
			@areaToRasterize = null
			@areasToUpdate = []

			@rasters = {}

			bounds = view.bounds

			zoom = g.quantizeZoom(1.0 / view.zoom)
			scale = zoom * g.scale

			qBounds = @quantizeBounds(bounds, scale)
			for x in [qBounds.l .. qBounds.r] by scale
				for y in [qBounds.t .. qBounds.b] by scale
					@createUpdateRaster(x, y, zoom)

			@move()
			return

		quantizeBounds: (bounds=view.bounds, scale=g.scale)->
			quantizedBounds =
				t: g.floorToMultiple(bounds.top, scale)
				l: g.floorToMultiple(bounds.left, scale)
				b: g.floorToMultiple(bounds.bottom, scale)
				r: g.floorToMultiple(bounds.right, scale)
			return quantizedBounds

		createUpdateRaster: (x, y, zoom)->
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
			raster.zoom = zoom
			raster.context = raster.canvas.getContext('2d')
			raster.image = new Image()
			raster.image.onload = ()=>
				console.log raster.image.src
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
			raster.ready = true
			$("#rasters").append(raster.canvasJ)
			@rasters[x] ?= {}
			@rasters[x][y] = raster
			return

		getRasterBounds: (x, y)->
			size = @rasters[x][y].zoom * g.scale
			return new Rectangle(x, y, size, size)

		removeRaster: (raster, x, y)->
			raster.canvasJ.remove()
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
					@createUpdateRaster(x, y, qZoom)

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

		splitAreaToRasterize: ()->
			maxSize = view.size.multiply(2)
			area = g.expandRectangleToInteger(new Rectangle(@areaToRasterize.topLeft, Size.min(maxSize, @areaToRasterize.size)))
			areas = [area.clone()]

			while area.right < @areaToRasterize.right or area.bottom < @areaToRasterize.bottom
				if area.right < @areaToRasterize.right
					area.x += maxSize.width
				else
					area.y += maxSize.height
				areas.push(area.clone())

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
			if @rasterizationDisabled then return

			console.log "rasterize"
			console.log Date.now()

			# show all items
			for pk, item of g.items
				item.group.visible = true

			areas = @splitAreaToRasterize()

			# hide excluded items
			for item in @itemsToExclude
				item.group?.visible = false 	# group is null when item has been deleted

			g.grid.visible = false
			g.selectionLayer.visible = false

			@rasterizeAreas(areas)

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
			return

		rasterize: (items, excludeItems)->
			if @rasterizationDisabled then return
			console.log "ask rasterize" + (if excludeItems then "exclude items" else "")

			if not g.isArray(items) then items = [items]

			for item in items
				@areaToRasterize ?= item.getDrawingBounds()
				@areaToRasterize = @areaToRasterize.unite(item.getDrawingBounds())
				if excludeItems
					g.pushIfAbsent(@itemsToExclude, item)

			g.callNextFrame(@rasterizeCallback, 'rasterize')
			return

		rasterizeRectangle: (rectangle)->
			if @rasterizationDisabled then return

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
			if @rasterizationDisabled then return

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

		# rasterizeItem: (item)->
		# 	if item.getDrawingBounds().area > @maxArea()
		# 		return
		# 	item.drawing.visible = true
		# 	item.selectionRectangle?.visible = false
		# 	raster = item.drawing.rasterize()
		# 	@rasterizeCanvas(raster.canvas, raster.bounds)
		# 	raster.remove()
		# 	item.drawing.visible = false
		# 	item.selectionRectangle?.visible = true
		# 	return

		maxArea: ()->
			return view.bounds.area * @constructor.MAX_AREA

		drawItems: (showPath=false)->
			if @rasterizationDisabled then return

			for pk, item of g.items
				if not item.drawing? then item.draw?()
				item.group.visible = showPath or item.selectionRectangle?
			return

		clearRasters: ()->
			for x, rasterColumn of @rasters
				for y, raster of rasterColumn
					raster.context.clearRect(0, 0, g.scale, g.scale)
			return

		rasterizeView: ()->
			@rasterizeRectangle(view.bounds)
			return

		disableRasterization: ()->
			@drawItems(true)
			g.hideRasters()
			@previousFunctions = {}
			for name, property of @
				if typeof(property) == 'function' and name != 'enableRasterization'
					@previousFunctions[name] = property
					@[name] = ()-> return
			return

		enableRasterization: ()->
			for name, property of @previousFunction
				if typeof(property) == 'function'
					@[name] = @previousFunction[name]

			delete @previousFunctions

			g.showRasters()
			@clearRasters()
			@rasterizeView()
			return

	g.Rasterizer = Rasterizer

	return