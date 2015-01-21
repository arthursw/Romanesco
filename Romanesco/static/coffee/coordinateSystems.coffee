# Romansco relies on different coordinate systems:
# - the paper view: corresponds to the canvas on the html document, top left corner of canvas is [0,0] and bottom left is [view.size.width, view.size.height]
# - the paper project: the infinite space, 0,0 is the origin of the infinite space, from [-inf,-inf] to [inf,inf]
# - the planet: the project positions are defined on a grid of cells of dimension [360*g.scale, 180*g.scale] (g.scale = 1000 by default)
# 				the origin of the space [0,0] is in the middle of a cell (meaning the first top left limit will be at [-180*g.scale, -90*g.scale])
# 				one cell correspond to a planet with two coordinates, objects in the database are stored and sorted in a planet (x,y) and then in a map
# 				the map is defined within a rectangle {x: -180, y: -90, width: 360, height: 180} in GeoJson format

# When loading/saving to the database: posOnPlanet <-> project

this.g = this

# Get the planet on which *point* lies
#
# @param [Point] point to convert
# @return [Point object] the planet on which *point* lies
this.projectToPlanet = (point)->
	planet = {}
	# if not point.x? and not point.y? then point = arrayToPoint(point)

	x = point.x / g.scale
	planet.x = Math.floor( ( x + 180 ) / 360 )

	y = point.y / g.scale
	planet.y = Math.floor( ( y + 90 ) / 180 )

	return planet

# Get the position of *point* on *planet*
#
# @param [Point] point to convert
# @param [Point] plant to convert
# @return [Point object] the position of *point* on the planet
this.projectToPosOnPlanet = (point, planet)->
	planet ?= this.projectToPlanet(point)
	# if not point.x? and not point.y? then point = arrayToPoint(point)

	pos = {}
	pos.x = point.x/g.scale - 360*planet.x
	pos.y = point.y/g.scale - 180*planet.y

	return pos

# Get an object { pos: pos, planet: planet } with the planet on which *point* lies and the position of *point* on this planet
# This is the opposite of posOnPlanetToProject
# 
# @param [Point] point to convert
# @return [{ pos: Point, planet: Planet }] the planet on which *point* lies and the position of *point* on the planet
this.projectToPlanetJson = (point)->
	planet = projectToPlanet(point)
	pos = projectToPosOnPlanet(point, planet)
	return { pos: pos, planet: planet }

# Get the position in project coordinate system of *point* on *planet*
# This is the opposite of projectToPlanetJson
#
# @param [Point] point to convert
# @param [Point] planet to convert
# @return [Paper point] the position of *point* on *planet*
this.posOnPlanetToProject = (point, planet)->
	if not point.x? and not point.y? then point = arrayToPoint(point)
	x = planet.x*360+point.x
	y = planet.y*180+point.y
	x *= g.scale
	y *= g.scale
	return new Point(x,y)

# @return [Paper point] point extracted from *array*
this.arrayToPoint = (array) ->
	return new Point(array)

# @return [Array of Number] array extracted from *point*
this.pointToArray = (point) ->
	return [point.x, point.y]

# @return [Point] object converted from paper point
this.pointToObj = (point) ->
	return { x: point.x, y: point.y }

# @return [String] a string corresponding to the view position on a grid of g.scale wide cells
this.getChatRoom = ()->
	return 'x: ' + Math.round(view.center.x / g.scale) + ', y: ' + Math.round(view.center.y / g.scale)

# @return [Paper point] the top left corner of the view [0,0] in project coordinates
this.getTopLeftCorner = ()->
	return view.viewToProject(new Point(0,0))

# @return [Paper point] the point between *p1* and *p2*
this.midPoint = (p1, p2) ->
	return new Point( (p1.x+p2.x)*0.5, (p1.y+p2.y)*0.5 )

# @return [Rectangle] *rectangle* in project coordinates
this.viewToProjectRectangle = (rectangle)->
	return new Rectangle(view.viewToProject(rectangle.topLeft), view.viewToProject(rectangle.bottomRight))

# @return [Rectangle] *rectangle* in view coordinates
this.projectToViewRectangle = (rectangle)->
	return new Rectangle(view.projectToView(rectangle.topLeft), view.projectToView(rectangle.bottomRight))

# @return [Paper point] topLeft point of the bottom right planet in project coordinates (this will be the origin of the limits)
this.getLimit = ()->
	planet = projectToPlanet(getTopLeftCorner())
	return posOnPlanetToProject( new Point(-180,-90), new Point(planet.x+1, planet.y+1) )

# get a GeoJson valid box in planet coordinates from *rectangle* 
# @param rectangle [Paper Rectangle] the rectangle to convert
# @return [{ points:Array<Array<2 Numbers>>, planet: Object, tl: Point, br: Point }]
this.boxFromRectangle = (rectangle)->
	# remove margin to ignore intersections of paths which are close to the edges

	planet = pointToObj( projectToPlanet(rectangle.topLeft) )

	tlOnPlanet = projectToPosOnPlanet(rectangle.topLeft, planet)
	brOnPlanet = projectToPosOnPlanet(rectangle.bottomRight, planet)

	points = []
	points.push(pointToArray(tlOnPlanet))
	points.push(pointToArray(projectToPosOnPlanet(rectangle.topRight, planet)))
	points.push(pointToArray(brOnPlanet))
	points.push(pointToArray(projectToPosOnPlanet(rectangle.bottomLeft, planet)))
	points.push(pointToArray(tlOnPlanet))

	return { points:points, planet: pointToObj(planet), tl: tlOnPlanet, br: brOnPlanet }
