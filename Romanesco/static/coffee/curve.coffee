points = []
points.push(new Point(0,0))
points.push(new Point(1,0))
points.push(new Point(0.5,1.5))
points.push(new Point(4.0,2))

for p in points
	p.x *= 100
	p.y *= -100

linearInterpolation = (a, b, t)->
	x = g.linearInterpolation(a.x, b.x, t)
	y = g.linearInterpolation(a.y, b.y, t)
	return new Point(x, y)

segments1 = (points, t)->
	s1 = linearInterpolation(points[0], points[1], t)
	s2 = linearInterpolation(points[1], points[2], t)
	s3 = linearInterpolation(points[2], points[3], t)
	return [s1, s2, s3]

segments2 = (points, t)->
	s1 = linearInterpolation(points[0], points[1], t)
	s2 = linearInterpolation(points[1], points[2], t)
	return [s1, s2]

segments3 = (points, t)->
	s1 = linearInterpolation(points[0], points[1], t)
	return s1

group = new Group()

tangent1 = new Path()
tangent1.strokeWidth = 1
tangent1.strokeColor = 'red'
tangent1.add(points[0])
tangent1.add(points[1])
group.addChild(tangent1)

tangent2 = new Path()
tangent2.strokeWidth = 1
tangent2.strokeColor = 'red'
tangent2.add(points[2])
tangent2.add(points[3])
group.addChild(tangent2)

path = new Path()
group.addChild(path)

path.strokeWidth = 1
path.strokeColor = 'black'
path.add(points[0])


nPoints = 20
for i in [0 .. nPoints]
	t = i/nPoints
	s1s = segments1(points, t)
	s2s = segments2(s1s, t)
	s3s = segments3(s2s, t)
	path.add(s3s)

group.position = view.center