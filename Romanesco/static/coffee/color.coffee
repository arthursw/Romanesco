define [
	'utils', 'tinycolor', 'gui', 'colorpickersliders', 'jquery', 'paper'
], (utils, tinycolor, GUI) ->

	g = utils.g()

	g.initializeColorPicker = ()->

		switch parameter.type
			when 'color' 		# create a color controller
				obj[name] = ''
				controller = datFolder.add(obj, name).name(parameter.label)
				inputJ = $(datFolder.domElement).find("div.c > input:last")
				inputJ.addClass("color-input")
				checkboxJ = $('<input type="checkbox">')
				checkboxJ.insertBefore(inputJ)
				checkboxJ[0].checked = if item? and datFolder.name != 'General' then item.data[name]? else parameter.defaultCheck

				# colorGUI = new dat.GUI({ autoPlace: false })
				# color = :
				# 	hue: 0
				# 	saturation: 0
				# 	lightness: 0
				# 	red: 0
				# 	green: 0
				# 	blue: 0

				# colorGUI.add(color, 'hue', 0, 1).onChange( (value)-> tinycolor.("hsv 0 1 1"))
				# colorGUI.add(color, 'saturation', 0, 1)
				# colorGUI.add(color, 'lightness', 0, 1)
				# colorGUI.add(color, 'red', 0, 1)
				# colorGUI.add(color, 'green', 0, 1)
				# colorGUI.add(color, 'blue', 0, 1)

				# $("body").appendChild(colorGUI.domElement)
				# colorGuiJ = $(colorGUI.domElement)
				# colorGuiJ.css( position: 'absolute', left: inputJ.offset().left, top: inputJ.offset().top )

				colorPicker = inputJ.ColorPickerSliders({
					title: parameter.label,
					placement: 'auto',
					size: 'sm',
					# hsvpanel: true
					color: tinycolor(if value? then value else parameter.default).toRgbString(),
					order: {
						hsl: 1,
						rgb: 2,
						opacity: 3,
						preview: 4
					},
					labels: {
						rgbred: 'Red',
						rgbgreen: 'Green',
						rgbblue: 'Blue',
						hslhue: 'Hue',
						hslsaturation: 'Saturation',
						hsllightness: 'Lightness',
						preview: 'Preview',
						opacity: 'Opacity'
					},
					customswatches: "different-swatches-groupname",
					swatches: false,
					# swatches: g.defaultColors,
					# hsvpanel: true,
					onchange: (container, color) ->
						colorPickerPopoverJ = $(".cp-popover-container .popover")
						gradient = colorPickerPopoverJ.find('.gradient-checkbox')[0].checked
						if gradient
							g.selectedGradientHandle.setColor(color.tiny.toRgbString())
						else
							parameter.onChange(color.tiny.toRgbString())
						checkboxJ[0].checked = true
				}).click ()->
					guiJ = $(g.gui.domElement)
					colorPickerPopoverJ = $(".cp-popover-container .popover")

					# swatchesJ = colorPickerPopoverJ.find('.cp-swatches')
					checkboxJ = $("<label><input type='checkbox' class='gradient-checkbox' form-control>Gradient</label>")
					checkboxJ.insertBefore(colorPickerPopoverJ.find('.cp-preview'))
					checkboxJ.click (event)->
						if this.checked
							g.initializeGradientTool()
						else
							g.removeGradientTool()
						return
					# swatchesJ.append(gradientSwatchesJ)

					if guiJ.parent().hasClass("dg-sidebar")
						# position = guiJ.offset().left + guiJ.outerWidth()
						# colorPickerPopoverJ.css( left: position )
						colorPickerPopoverJ.removeClass("left").addClass("right")
						# $(".cp-popover-container .arrow").hide()
					# else
					# 	position = guiJ.offset().left - colorPickerPopoverJ.width()
					# 	colorPickerPopoverJ.css( left: position )
					return

	g.initializeGradientTool = ()->
		g.gradientTool = new GradientTool()
		return

	g.removeGradientTool = ()->
		g.gradientTool.remove()
		g.gradientTool = null
		return

	return