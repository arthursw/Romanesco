@RollerPath.source = """
class RollerPath extends PrecisePath
	@rname = 'Roller brush'
	@iconUrl = 'static/icons/inverted/rollerBrush.png'
	@iconAlt = 'roller brush'
	@rdescription = "The stroke width is function of the speed: the faster the wider."

	@parameters: ()->
		parameters = super()
		parameters['Style'].strokeWidth.default = 0 
		parameters['Style'].strokeColor.defaultCheck = false
		parameters['Style'].fillColor.defaultCheck = true

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 30
			max: 300
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].trackWidth =
			type: 'slider'
			label: 'Track width'
			min: 1
			max: 100
			default: 20
		return parameters

	drawBegin: ()->
		@initializeDrawing(false)
		@path = @addPath()
		@path.add(@controlPath.firstSegment.point)
		return

	drawUpdate: (length)->

		point = @controlPath.getPointAt(length)
		normal = @controlPath.getNormalAt(length).normalize()

		delta = normal.multiply(@data.trackWidth/2)
		top = point.add(delta)
		bottom = point.subtract(delta)

		@path.add(top)
		@path.insert(0, bottom)
		return

	drawEnd: ()->
		@path.add(@controlPath.lastSegment.point)
		@path.closed = true
		@path.smooth()
		return
"""
@SpiralPath.source = """
class SpiralPath extends PrecisePath
	@rname = 'Spiral path'
	@rdescription = "Spiral path."

	@parameters: ()->
		parameters = super()
		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 10
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].thickness =
			type: 'slider'
			label: 'Thickness'
			min: 1
			max: 30
			default: 5
			step: 1
		parameters['Parameters'].rsmooth =
			type: 'checkbox'
			label: 'Smooth'
			default: false

		return parameters

	drawBegin: ()->
		@initializeDrawing(false)
		@line = @addPath()
		@spiral = @addPath()
		return

	drawUpdate: (length)->

		point = @controlPath.getPointAt(length)
		normal = @controlPath.getNormalAt(length).normalize()
		tangent = normal.rotate(90)

		@line.add(point)

		@spiral.add(point.add(normal.multiply(@data.thickness)))

		p1 = point.add(normal.multiply(@data.step))
		@spiral.add(p1)

		p2 = p1.add(tangent.multiply(@data.step-@data.thickness))
		@spiral.add(p2)

		p3 = p2.add(normal.multiply( -(@data.step-2*@data.thickness) ))
		@spiral.add(p3)

		p4 = p3.add(tangent.multiply( -(@data.step-3*@data.thickness) ))
		@spiral.add(p4)

		p5 = p4.add(normal.multiply( @data.thickness ))
		@spiral.add(p5)

		p6 = p5.add(tangent.multiply( @data.step-4*@data.thickness ))
		@spiral.add(p6)

		p7 = p6.add(normal.multiply( @data.step-4*@data.thickness ))
		@spiral.add(p7)

		p8 = p7.add(tangent.multiply( -(@data.step-3*@data.thickness) ))
		@spiral.add(p8)

		p9 = p8.add(normal.multiply( -(@data.step-2*@data.thickness) ))
		@spiral.add(p9)

		return

	drawEnd: ()->
		if @data.rsmooth 
			@spiral.smooth()
			@line.smooth()
		return

"""
@FuzzyPath.source = """
class FuzzyPath extends SpeedPath
	@rname = 'Fuzzy brush'
	@rdescription = "Brush with lines poping out of the path."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {} 
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].minWidth =
			type: 'slider'
			label: 'Min width'
			min: 1
			max: 100
			default: 20
		parameters['Parameters'].maxWidth =
			type: 'slider'
			label: 'Max width'
			min: 1
			max: 250
			default: 200
		parameters['Parameters'].minSpeed =
			type: 'slider'
			label: 'Min speed'
			min: 1
			max: 250
			default: 1
		parameters['Parameters'].maxSpeed =
			type: 'slider'
			label: 'Max speed'
			min: 1
			max: 250
			default: 200
		parameters['Parameters'].nLines =
			type: 'slider'
			label: 'N lines'
			min: 1
			max: 5
			default: 2
			simplified: 2
			step: 1
		parameters['Parameters'].symmetric =
			type: 'dropdown'
			label: 'Symmetry'
			values: ['symmetric', 'top', 'bottom']
			default: 'symmetric'
		parameters['Parameters'].speedForWidth =
			type: 'checkbox'
			label: 'Speed for width'
			default: true
		parameters['Parameters'].speedForLength =
			type: 'checkbox'
			label: 'Speed for length'
			default: false
		parameters['Parameters'].orthoLines =
			type: 'checkbox'
			label: 'Orthogonal lines'
			default: true
		parameters['Parameters'].lengthLines =
			type: 'checkbox'
			label: 'Length lines'
			default: true

		return parameters

	drawBegin: ()->
		@initializeDrawing(false)

		if @data.lengthLines
			@lines = []
			nLines = @data.nLines
			if @data.symmetric == 'symmetric' then nLines *= 2
			for i in [1 .. nLines]
				@lines.push( @addPath() )

		@lastLength = 0

		return

	drawUpdate: (length)->
		console.log "drawUpdate"

		speed = @speedAt(length)

		addPoint = (length, speed)=>
			point = @controlPath.getPointAt(length)
			normal = @controlPath.getNormalAt(length).normalize()

			if @data.speedForWidth
				width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.speedMax
			else
				width = @data.minWidth


			if @data.lengthLines
				divisor = if @data.nLines>1 then @data.nLines-1 else 1
				if @data.symmetric == 'symmetric'
					for line, i in @lines by 2
						@lines[i+0].add(point.add(normal.multiply(i*width*0.5/divisor)))
						@lines[i+1].add(point.add(normal.multiply(-i*width*0.5/divisor)))
				else
					if @data.symmetric == 'top'
						line.add(point.add(normal.multiply(i*width/divisor))) for line, i in @lines
					else if @data.symmetric == 'bottom'
						line.add(point.add(normal.multiply(-i*width/divisor))) for line, i in @lines

			if @data.orthoLines
				path = @addPath()
				delta = normal.multiply(width)
				switch @data.symmetric
					when 'symmetric'
						path.add(point.add(delta))
						path.add(point.subtract(delta))
					when 'top'
						path.add(point.add(delta))
						path.add(point)
					when 'bottom'
						path.add(point.subtract(delta))
						path.add(point)
			return

		if not @data.speedForLength
			addPoint(length, speed)
		else 	# @data.speedForLength
			speed = @data.minSpeed + (speed / @constructor.speedMax) * (@data.maxSpeed - @data.minSpeed)
	
			stepLength = length-@lastLength

			if stepLength>speed
				midLength = (length+@lastLength)/2
				addPoint(midLength, speed)
				@lastLength = length

		return

	drawEnd: ()->
		return
"""
@SketchPath.source = """
class SketchPath extends PrecisePath
	@rname = 'Sketch brush'
	@rdescription = "Sketch path."

	@parameters: ()->
		parameters = super()
		parameters['Style'].strokeColor.default = "rgba(0, 0, 0, 0.25)"
		delete parameters['Style'].fillColor

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].distance =
			type: 'slider'
			label: 'Distance'
			min: 5
			max: 250
			default: 100
			simplified: 100

		return parameters

	drawBegin: ()->
		@initializeDrawing(true)

		@points = []
		return

	drawUpdate: (length)->
		console.log "drawUpdate"

		point = @controlPath.getPointAt(length)
		normal = @controlPath.getNormalAt(length).normalize()

		point = @projectToRaster(point)
		@points.push(point)
		
		distMax = @data.distance*@data.distance

		for pt in @points

			if point.getDistance(pt, true) < distMax
				@context.beginPath()
				@context.moveTo(point.x,point.y)
				@context.lineTo(pt.x,pt.y)
				@context.stroke()
		
		return

	drawEnd: ()->
		return
"""
@ShapePath.source = """
class ShapePath extends SpeedPath
	@rname = 'Shape path'
	@rdescription = "Places shape along the path."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].minWidth =
			type: 'slider'
			label: 'Min width'
			min: 1
			max: 250
			default: 1
		parameters['Parameters'].maxWidth =
			type: 'slider'
			label: 'Max width'
			min: 1
			max: 250
			default: 200
		parameters['Parameters'].speedForLength =
			type: 'checkbox'
			label: 'Speed for length'
			default: false
		parameters['Parameters'].minSpeed =
			type: 'slider'
			label: 'Min speed'
			min: 1
			max: 250
			default: 1
		parameters['Parameters'].maxSpeed =
			type: 'slider'
			label: 'Max speed'
			min: 1
			max: 250
			default: 200

		return parameters


	drawBegin: ()->
		@initializeDrawing(false)
		@lastLength = 0
		return

	drawUpdate: (length)->
		console.log "drawUpdate"

		speed = @speedAt(length)

		addPoint = (length, height, speed)=>
			point = @controlPath.getPointAt(length)
			normal = @controlPath.getNormalAt(length)

			width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.speedMax
			shape = @addPath(new Path.Rectangle(point.subtract(new Point(width/2, height/2)), new Size(width, height)))
			shape.rotation = normal.angle
			return

		if not @data.speedForLength
			addPoint(length, @data.step, speed)
		else 	# @data.speedForLength
			speed = @data.minSpeed + (speed / @constructor.speedMax) * (@data.maxSpeed - @data.minSpeed)
			
			stepLength = length-@lastLength
			if stepLength>speed
				midLength = (length+@lastLength)/2
				addPoint(midLength, stepLength, speed)
				@lastLength = length

		return

	drawEnd: ()->
		return
"""
@RectangleShape.source = """
class RectangleShape extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Rectangle'
	# @iconUrl = 'static/icons/inverted/rectangle.png'
	# @iconAlt = 'rectangle'
	@rdescription = "Simple rectangle, square by default (use shift key to change to a rectangle). It can have rounded corners."

	@parameters: ()->
		parameters = super()
		parameters['Style'] ?= {} 
		parameters['Style'].cornerRadius =
			type: 'slider'
			label: 'Corner radius'
			min: 0
			max: 100
			default: 0
		return parameters

	createShape: ()->
		@shape = @addPath(new @constructor.Shape(@rectangle, @data.cornerRadius))

"""
@EllipseShape.source = """
class EllipseShape extends RShape
	@Shape = paper.Path.Ellipse
	@rname = 'Ellipse'
	@iconUrl = 'static/icons/inverted/circle.png'
	@iconAlt = 'circle'
	@rdescription = "Simple ellipse, circle by default (use shift key to change to an ellipse)."

"""
@StarShape.source = """
class StarShape extends RShape
	@Shape = paper.Path.Star
	@rname = 'Star'
	@rdescription = "Star shape."

	@parameters: ()->
		parameters = super()
		parameters['Style'] ?= {} 
		parameters['Style'].nPoints =
			type: 'slider'
			label: 'N points'
			min: 1
			max: 100
			default: 5
			step: 2
		parameters['Style'].internalRadius =
			type: 'slider'
			label: 'Internal radius'
			min: -200
			max: 100
			default: 37
		parameters['Style'].rsmooth =
			type: 'checkbox'
			label: 'Smooth'
			default: false
		return parameters

	createShape: ()->
		if @data.internalRadius>-100
			externalRadius = @rectangle.width/2
			internalRadius = externalRadius*@data.internalRadius/100
		else
			internalRadius = @rectangle.width/2
			externalRadius = internalRadius*100/@data.internalRadius
		@shape = @addPath(new @constructor.Shape(@rectangle.center, @data.nPoints, externalRadius, internalRadius))
		if @data.rsmooth then @shape.smooth()

"""
@SpiralShape.source = """
class SpiralShape extends RShape
	@Shape = paper.Path.Ellipse
	@rname = 'Spiral'
	# @iconUrl = 'static/icons/inverted/spiral.png'
	# @iconAlt = 'spiral'
	@rdescription = "Spiral shape, can have an intern radius, and any number of sides."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {} 
		parameters['Parameters'].minRadius =
			type: 'slider'
			label: 'Minimum radius'
			min: 0
			max: 100
			default: 0
			# onSlide: @radiusMinChanged #optional slide event handler
			# onSlideStop: @radiusMinStopped
		parameters['Parameters'].nTurns =
			type: 'slider'
			label: 'Number of turns'
			min: 1 
			max: 50
			default: 10
		parameters['Parameters'].nSides =
			type: 'slider'
			label: 'Sides'
			min: 3
			max: 100
			default: 50

		return parameters

	createShape: ()->
		@shape = @addPath()

		hw = @rectangle.width/2
		hh = @rectangle.height/2
		c = @rectangle.center
		angle = 0

		angleStep = 360.0/@data.nSides
		spiralWidth = hw-hw*@data.minRadius/100.0
		spiralHeight = hh-hh*@data.minRadius/100.0
		radiusStepX = (spiralWidth / @data.nTurns) / @data.nSides
		radiusStepY = (spiralHeight / @data.nTurns) / @data.nSides
		for i in [0..@data.nTurns-1]
			for step in [0..@data.nSides-1]
				@shape.add(new Point(c.x+hw*Math.cos(angle), c.y+hh*Math.sin(angle)))
				angle += (2.0*Math.PI*angleStep/360.0)
				hw -= radiusStepX
				hh -= radiusStepY
		@shape.add(new Point(c.x+hw*Math.cos(angle), c.y+hh*Math.sin(angle)))
"""

@PrecisePath.source = """
class PrecisePath extends RPath 	# must extend PrecisePath, SpeedPath or RShape
	@rname = 'Precise path'
	# @iconUrl = '/static/icons/inverted/editCurve.png'
	# @iconAlt = 'edit curve'
	@rdescription = "This path offers precise controls, one can modify points along with their handles and their type."


	@parameters: ()->

		parameters = super()

		parameters['General'].polygonMode =
			type: 'checkbox'
			label: 'Polygon mode'
			default: g.polygonMode
			onChange: (value)-> g.polygonMode = value

		parameters['Edit curve'] =			
			smooth:
				type: 'checkbox'
				label: 'Smooth'
				default: false
			pointType:
				type: 'dropdown'
				label: 'Point type'
				values: ['smooth', 'corner', 'point']
				default: 'smooth'
				onChange: (value)-> item.changeSelectedPoint?(true, value) for item in g.selectedItems()
			deletePoint: 
				type: 'button'
				label: 'Delete point'
				default: ()-> item.deleteSelectedPoint?() for item in g.selectedItems()

		return parameters

	drawBegin: ()->
		@initializeDrawing(false)
		@path = @addPath()
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	drawUpdate: (length)->
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	drawEnd: ()->
		@path.segments = @controlPath.segments
		@path.selected = false
		return
"""
@Checkpoint.source = """
class Checkpoint extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Checkpoint'
	# @iconUrl = 'static/icons/inverted/spiral.png'
	# @iconAlt = 'spiral'
	@rdescription = "Checkpoint."
	
	constructor: (@date=null, @data=null, @pk=null, points=null) ->
		super(@date, @data, @pk, points)
		return
	
	createShape: ()->
		@game = g.gameAt(@rectangle.center)
		if @game?
			if @game.checkpoints.indexOf(@)<0 then @game.checkpoints.push(@)
			@data.checkpointNumber ?= @game.checkpoints.indexOf(@)

		@data.strokeColor = 'rgb(150,30,30)'
		@data.fillColor = null
		@checkpointRectangle = @rectangle
		@checkpointRectangle.height = 30
		@checkpointRectangle.center = @rectangle.center
		@shape = @addPath(new Path.Rectangle(@checkpointRectangle))
		@text = @addPath(new PointText(@rectangle.center.add(0,4)))
		@text.content = if @data.checkpointNumber? then 'Checkpoint ' + @data.checkpointNumber else 'Checkpoint'
		@text.justification = 'center'
		
		return

	contains: (point)->
		delta = point.subtract(@checkpointRectangle.center)
		delta.rotation = -@data.rotation
		return @checkpointRectangle.contains(@checkpointRectangle.center.add(delta))

	remove: ()->
		@game?.checkpoints.remove(@)
		super()
		return
"""

g.codeExample = """
class NewPath extends PrecisePath
	@rname = 'New path'
	@rdescription = "New tool description."

	drawBegin: ()->
		@initializeDrawing(false)
		@path = @addPath()
		return

	drawUpdate: (length)->
		point = @controlPath.getPointAt(length)
		@path.add(point)
		return

	drawEnd: ()->
		@path.simplify()
		@path.smooth()
		return
"""
