class Rasterizer

	constructor:()->
		@drawAllMode = false
		@rasters = {}

		bounds = view.bounds

		zoom = @quantizeZoom(1.0 / view.zoom)
		scale = zoom * g.scale

		t = g.roundToLowerMultiple(bounds.top, scale)
		l = g.roundToLowerMultiple(bounds.left, scale)
		b = g.roundToLowerMultiple(bounds.bottom, scale)
		r = g.roundToLowerMultiple(bounds.right, scale)

		# add areas to load
		areasToLoad = []
		for x in [l .. r] by scale
			for y in [t .. b] by scale
				@createRaster(x, y, zoom)

		@moveRasters()
		return

	quantizeZoom: (zoom)->
		if zoom < 5
			zoom = 1
		else if zoom < 25
			zoom = 5
		else
			zoom = 25
		return zoom

	createRaster: (x, y, zoom)->
		if @rasters[x]?[y]? then return
		raster = {}
		raster.canvasJ = $('<canvas hidpi="off" width="1000" height="1000">')
		raster.canvas = raster.canvasJ[0]
		# raster.position = new Point(x, y)
		raster.zoom = zoom
		raster.context = raster.canvas.getContext('2d')
		raster.image = new Image()
		raster.image.onload = ()->
			raster.context.drawImage(raster.image, 0, 0)
			return
		@rasters[x] ?= {}
		@rasters[x][y] = raster
		return

	getRasterBounds: (x, y)->
		size = @rasters[x][y].zoom * 1000
		return new Rectangle(x, y, size, size)

	removeRaster: (raster, x, y)->
		raster.canvasJ.remove()
		delete @rasters[x][y]
		if g.isEmpty(@rasters[x]) then delete @rasters[x]
		return

	unload: (limit)->
		for x, rasterColumn of @rasters
			for y, raster of rasterColumn
				rectangle = @getRasterBounds(x, y)
				if not limit.contains(rectangle)
					@removeRaster(raster, x, y)
		return

	load: (rasters, zoom)->
		zoom = @quantizeZoom(zoom)

		for r in rasters
			x = r.position.x
			y = r.position.y
			@createRaster(x, y, zoom)
			@rasters[x][y][zoom].image.src = g.romanescoURL + r.url

		@moveRasters()
		return

	moveRasters: ()->
		for x, rasterColumn of @rasters
			for y, raster of rasterColumn

				viewPos = view.projectToView(new Point(x, y))
				
				if view.zoom == 1
					raster.canvasJ.css( 'left': viewPos.x, 'top': viewPos.y, 'transform': 'none' )
				else
					zoom = view.zoom * raster.zoom
					css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
					css += ' scale(' + zoom + ')'
					raster.canvasJ.css( 'transform': css, 'top': 0, 'left': 0 )
		return

	drawImageInRaster: (raster, x, y, zoom)->
		if not @rasters[x]?[y]? then return
		rectangle = @getRasterBounds(x, y)
		intersection = raster.bounds.intersect(rectangle)
		imageData = raster.getImageData(new Rectangle(intersection.x-bounds.x, intersection.y-bounds.y, intersection.width, intersection.height))
		destinationRectangle = new Rectangle(intersection.topLeft.subtract(rectangle.topLeft).divide(zoom), intersection.size.divide(zoom))
		@rasters[x][y].context.drawImage(imageData, destinationRectangle)
		return

	drawRaster: (raster)->
		bounds = raster.bounds
		
		zoom = @quantizeZoom(1.0 / view.zoom)
		scale = zoom * g.scale

		t = g.roundToLowerMultiple(bounds.top, scale)
		l = g.roundToLowerMultiple(bounds.left, scale)
		b = g.roundToLowerMultiple(bounds.bottom, scale)
		r = g.roundToLowerMultiple(bounds.right, scale)

		for x in [l .. r] by scale
			for y in [t .. b] by scale
				@drawImageInRaster(raster, x, y, zoom)
		return

	drawView: (bounds=view.bounds)->
		bounds = g.projectToViewRectangle(bounds)
		
		scale = g.scale

		t = g.roundToLowerMultiple(bounds.top, scale)
		l = g.roundToLowerMultiple(bounds.left, scale)
		b = g.roundToLowerMultiple(bounds.bottom, scale)
		r = g.roundToLowerMultiple(bounds.right, scale)

		for x in [l .. r] by scale
			for y in [t .. b] by scale
				if not g.rasters[x]?[y]?
					console.log 'Error: missing raster: ' + x ', ' + y
				rectangle = g.projectToViewRectangle(@getRasterBounds(x, y))
				intersection = bounds.intersect(rectangle)
				imageData = g.context.getImageData(intersection.x, intersection.y, intersection.width, intersection.height)
				g.rasters[x][y].context.drawImage(imageData, intersection.x-rectangle.x, intersection.y-rectangle.y, intersection.width, intersection.height)
		return

	drawAll: ()->
		@drawAllMode = true
		for pk, item of g.items
			item.draw?()
			item.group.visible = true

		for x, rasterColumn of @rasters
			for y, raster of rasterColumn
				@removeRaster(raster, x, y)
		return

	rasterize: (items, excludeItems=false)->
		if @drawAllMode then return

		if RItem.prototype.isPrototypeOf(items)
			items = [items]
		
		bounds = items.first().getDrawingBounds()
		bounds = bounds.unite(item.getDrawingBounds()) for item in items

		if bounds.area > 1.5 * view.bounds.area
			@drawAll()
			return

		for pk, p of g.path
			if not p.drawing? and p.getDrawingBounds().intersects(bounds) then p.draw()
		
		# show all paths
		for pk, p of g.path
			p.group.visible = true
		
		# hide excluded items
		if excludeItems
			for item in items
				item.group.visible = false

		viewSize = view.viewSize
		viewPosition = view.center

		view.viewSize = bounds.size
		view.center = bounds.center
		view.update()
		
		@drawView(bounds)

		view.center = viewPosition
		view.viewSize = viewSize
		
		for pk, p of g.paths
			p.group.visible = false

		if excludeItems
			for item in items
				item.group.visible = true

		return

	drawItem: (item)->
		if @drawAllMode then return

		if item.getDrawingBounds().area > 1.5 * view.bounds.area
			@drawAll()
			return

		raster = item.drawing.rasterize()
		@drawRaster(raster)
		raster.remove()
		item.group.visible = false
		return

@Rasterizer = Rasterizer
