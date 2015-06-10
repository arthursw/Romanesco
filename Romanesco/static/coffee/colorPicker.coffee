position = view.center



width = 200
height = 200

sliderWidth = 20
sliderSize = new Size(sliderWidth, height)
rainbowSize = new Size(width, height)

g.colorPicker?.remove()
colorPicker = new Group()
g.colorPicker = colorPicker
colorPicker.context = view.element.getContext('2d')

color = new Color(1,0,0)

saturatedColor = color.clone()
saturatedColor.saturation = 1
saturatedColor.lightness = 0.5

rainbow = new Group()
rainbowSaturation = new Path.Rectangle(position, rainbowSize)
rainbowSaturation.fillColor =
	origin: rainbow.bounds.topLeft
	destination: rainbow.bounds.topRight
	gradient:
		stops: ['white', saturatedColor]

rainbow.rainbowSaturation = rainbowSaturation
rainbow.addChild(rainbowSaturation)

rainbowValue = new Path.Rectangle(position, rainbowSize)
rainbowValue.fillColor =
	origin: rainbow.bounds.topLeft
	destination: rainbow.bounds.bottomLeft
	gradient:
		stops: [new Color(0,0,0,0), new Color(0,0,0,1)]

rainbowValue.rainbow = rainbow

rainbow.addChild(rainbowValue)


rainbowHandle = new Path.Circle(position, 5)
rainbowHandle.strokeColor = 'black'
rainbow.handle = rainbowHandle
rainbowHandle.rainbow = rainbow

rainbow.addChild(rainbowHandle)

colorPicker.addChild(rainbow)

hueValues = []

i=0

while i<360
	hueValues.push(new Color(hue: i, saturation: color.saturation, lightness:color.lightness ))
	i += 36


hue = new Path.Rectangle(position, sliderSize)
hue.position.x = rainbow.bounds.right
hue.fillColor =
	origin: hue.bounds.topLeft
	destination: hue.bounds.bottomLeft
	gradient:
		stops: hueValues

saturationStart = color.clone()
saturationStart.saturation = 0
saturationEnd = color.clone()
saturationEnd.saturation = 1
saturation = new Path.Rectangle(hue.bounds.topRight, sliderSize)
saturation.fillColor =
	origin: saturation.bounds.topLeft
	destination: hue.bounds.bottomLeft
	gradient:
		stops: [saturationStart, saturationEnd]

lightnessStart = color.clone()
lightnessStart.lightness = 0
lightnessMid = color.clone()
lightnessMid.lightness = 0.5
lightnessEnd = color.clone()
lightnessEnd.lightness = 100
lightness = new Path.Rectangle(saturation.bounds.topRight, sliderSize)
lightness.fillColor =
	origin: lightness.bounds.topLeft
	destination: lightness.bounds.bottomLeft
	gradient:
		stops: [lightnessStart, lightnessMid, lightnessEnd]

redStart = color.clone()
redStart.red = 0
redEnd = color.clone()
redEnd.red = 1
red = new Path.Rectangle(lightness.bounds.topRight, sliderSize)
red.fillColor =
	origin: red.bounds.topLeft
	destination: red.bounds.bottomLeft
	gradient:
		stops: [redStart, redEnd]

greenStart = color.clone()
greenStart.green = 0
greenEnd = color.clone()
greenEnd.green = 1
green = new Path.Rectangle(red.bounds.topRight, sliderSize)
green.fillColor =
	origin: green.bounds.topLeft
	destination: green.bounds.bottomLeft
	gradient:
		stops: [greenStart, greenEnd]

blueStart = color.clone()
blueStart.blue = 0
blueEnd = color.clone()
blueEnd.blue = 1
blue = new Path.Rectangle(green.bounds.topRight, sliderSize)
blue.fillColor =
	origin: green.bounds.topLeft
	destination: green.bounds.bottomLeft
	gradient:
		stops: [blueStart, blueEnd]

hue.name = 'hue'
saturation.name = 'saturation'
lightness.name = 'lightness'
red.name = 'red'
green.name = 'green'
blue.name = 'blue'

colorPicker.addChild(hue)
colorPicker.addChild(saturation)
colorPicker.addChild(lightness)
colorPicker.addChild(red)
colorPicker.addChild(green)
colorPicker.addChild(blue)


addHandle = (slider)->
	group = new Group()
	group.addChild(slider)

	handle = new Path.Rectangle(slider.bounds.center, new Size(sliderWidth, 3))
	handle.position.x -= sliderWidth * 0.5
	# handle.position.y -= 3 * 0.5
	handle.fillColor = 'black'
	slider.handle = handle
	handle.slider = slider
	group.slider = slider

	group.addChild(handle)
	colorPicker.addChild(group)
	return

addHandle(hue)
addHandle(saturation)
addHandle(lightness)
addHandle(red)
addHandle(green)
addHandle(blue)

g.hue = hue
g.saturation = saturation
g.lightness = lightness
g.red = red
g.green = green
g.blue = blue
g.rainbow = rainbow

placeHandle = (slider, value)->
	slider.handle.position.y = slider.bounds.top + value * slider.bounds.height
	return

placeHandle(hue, color.hue/360)
placeHandle(saturation, color.saturation)
placeHandle(lightness, color.lightness)

placeHandle(red, color.red)
placeHandle(green, color.green)
placeHandle(blue, color.blue)


updateColorPicker = (color)->

	console.log 'color: ' + color.toCSS()

	console.log 'hue: ' + color.hue
	console.log 'saturation: ' + color.saturation
	console.log 'lightness: ' + color.lightness
	console.log 'brightness: ' + color.brightness

	saturatedColor = color.clone()
	# saturatedColor.saturation = 1
	# saturatedColor.brightness = 0.5
	g.rainbow.rainbowSaturation.fillColor.gradient.stops = ['white', saturatedColor]

	hueValues = []
	i = 0
	while i<360
		hueValues.push(new Color(hue: i, saturation: color.saturation, lightness: color.lightness))
		i += 36

	g.hue.fillColor.gradient.stops = hueValues

	saturationStart = color.clone()
	saturationStart.saturation = 0
	saturationEnd = color.clone()
	saturationEnd.saturation = 1
	g.saturation.fillColor.gradient.stops = [saturationStart, saturationEnd]

	lightnessStart = color.clone()
	lightnessStart.lightness = 0
	lightnessMid = color.clone()
	lightnessMid.lightness = 0.5
	lightnessEnd = color.clone()
	lightnessEnd.lightness = 100
	g.lightness.fillColor.gradient.stops = [lightnessStart, lightnessMid, lightnessEnd]

	redStart = color.clone()
	redStart.red = 0
	redEnd = color.clone()
	redEnd.red = 1
	g.red.fillColor.gradient.stops = [redStart, redEnd]

	greenStart = color.clone()
	greenStart.green = 0
	greenEnd = color.clone()
	greenEnd.green = 1
	g.green.fillColor.gradient.stops = [greenStart, greenEnd]

	blueStart = color.clone()
	blueStart.blue = 0
	blueEnd = color.clone()
	blueEnd.blue = 1
	g.blue.fillColor.gradient.stops = [blueStart, blueEnd]

	bounds = g.rainbow.bounds
	g.rainbow.handle.position = bounds.bottomLeft.add(color.saturation*bounds.width, -color.brightness*bounds.height)


	placeHandle(hue, color.hue/360)
	placeHandle(saturation, color.saturation)
	placeHandle(lightness, color.lightness)

	placeHandle(red, color.red)
	placeHandle(green, color.green)
	placeHandle(blue, color.blue)

	return

initializeSlider = (slider, color)->

	slider.moveHandle = (slider, event)->
		slider.handle.position.y = event.point.y
		value = ( event.point.y - slider.bounds.top ) / slider.bounds.height
		if slider.name == 'hue'
			value *= 360
		console.log slider.name + ': ' + value
		color[slider.name] = value
		updateColorPicker(color)
		return

	slider.mouseDown = (slider, event)->
		slider.dragging = true
		slider.moveHandle(slider, event)
		g.colorPicker.currentSlider = slider
		return

	slider.mouseMove = (slider, event)->
		if slider.dragging
			slider.moveHandle(slider, event)
			g.colorPicker.currentSlider = slider
		return

	slider.parent.on 'mousedown', (event)->
		this.slider.mouseDown(this.slider, event)
		return

	slider.parent.on 'mousemove', (event)->
		this.slider.mouseMove(this.slider, event)
		return

	return

$(window).mouseup (event)->
	g.colorPicker.currentSlider.dragging = false
	return

rainbow.moveRainbowHandle = (rainbow, event)->
	# viewPoint = view.projectToView(event.point)
	# data = g.colorPicker.context.getImageData(0, 0, view.size.width, view.size.height).data
	# index = (viewPoint.y * view.element.width + viewPoint.x) * 4
	# color = new Color(data[index + 0], data[index + 1], data[index + 2], data[index + 3])
	bounds = rainbow.rainbowValue.bounds
	color.saturation = ( event.point.x - bounds.left ) / bounds.width
	color.lightness = 1.0 - ( ( event.point.y - bounds.top ) / bounds.height )
	updateColorPicker(color)
	return

rainbow.mouseDown = (rainbow, event)->
	rainbow.dragging = true
	rainbow.handle.position = event.point
	rainbow.moveRainbowHandle(rainbow, event)
	g.colorPicker.currentSlider = rainbow
	return

rainbow.mouseMove = (rainbow, event)->
	if rainbow.dragging
		rainbow.moveRainbowHandle(rainbow, event)
		g.colorPicker.currentSlider = rainbow
	return

rainbow.on 'mousedown', (event)->
	this.mouseDown(this, event)
	return

rainbow.on 'mousemove', (event)->
	this.mouseMove(this, event)
	return

initializeSlider(hue, color)
initializeSlider(saturation, color)
initializeSlider(lightness, color)
initializeSlider(red, color)
initializeSlider(green, color)
initializeSlider(blue, color)


