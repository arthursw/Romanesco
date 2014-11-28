
# coordinate systems:
# view: pos in pixels in the view: top left corner of canvas is [0,0] and bottom left is [view.size.width, view.size.height]
# project: pos in pixels in the infinite space, 0,0 is the origin of the infinite space, from [-inf,-inf] to [inf,inf]
# posOnPlanet: pos in the planet coordinate system

# When loading/saving to the database: posOnPlanet <-> project


this.projectToPlanet = (point)->
	planet = {}
	# if not point.x? and not point.y? then point = arrayToPoint(point)

	x = point.x / g.scale
	planet.x = Math.floor( ( x + 180 ) / 360 )

	y = point.y / g.scale
	planet.y = Math.floor( ( y + 90 ) / 180 )

	return planet

this.projectToPosOnPlanet = (point, planet)->
	planet ?= this.projectToPlanet(point)
	# if not point.x? and not point.y? then point = arrayToPoint(point)

	pos = {}
	pos.x = point.x/g.scale - 360*planet.x
	pos.y = point.y/g.scale - 180*planet.y

	return pos

this.projectToPlanetJson = (point)->
	planet = projectToPlanet(point)
	pos = projectToPosOnPlanet(point, planet)
	return { pos: pos, planet: planet }

this.posOnPlanetToProject = (point, planet)->
	if not point.x? and not point.y? then point = arrayToPoint(point)
	x = planet.x*360+point.x
	y = planet.y*180+point.y
	x *= g.scale
	y *= g.scale
	return new Point(x,y)

this.arrayToPoint = (array) ->
	return new Point(array[0], array[1])

this.pointToArray = (point) ->
	return [point.x, point.y]

this.pointToObj = (point) ->
	return { x: point.x, y: point.y }

this.getChatRoom = ()->
	return 'x: ' + Math.round(view.center.x / g.scale) + ', y: ' + Math.round(view.center.y / g.scale)

this.getTopLeftCorner = ()->
	return view.viewToProject(new Point(0,0))

this.midPoint = (p1, p2) ->
	return new Point( (p1.x+p2.x)*0.5, (p1.y+p2.y)*0.5 )

this.getLimit = ()->
	planet = projectToPlanet(getTopLeftCorner())
	return posOnPlanetToProject( new Point(-180,-90), new Point(planet.x+1, planet.y+1) )

this.viewToProjectRectangle = (rectangle)->
	return new Rectangle(view.viewToProject(rectangle.topLeft), view.viewToProject(rectangle.bottomRight))

this.projectToViewRectangle = (rectangle)->
	return new Rectangle(view.projectToView(rectangle.topLeft), view.projectToView(rectangle.bottomRight))
