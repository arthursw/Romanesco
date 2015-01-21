// Generated by CoffeeScript 1.7.1
(function() {
  var pathClass, _i, _len, _ref;

  _ref = this.pathClasses;
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    pathClass = _ref[_i];
    pathClass.source = "";
  }

  g.codeExample = "# The script can be either a general script or a path script.\n# A general script must begin with 'scriptName = \"yourScriptName\"'.\n# A path script must begin with \"class YourPathName extends SuperClass\".\n# SuperClass can be \"PrecisePath\", \"SpeedPath\" or \"RShape\".\n#\n# You can see the code of any path by selecting the corresponding drawing tool and click the \"Edit tool\" in the options bar\n#\n# Full documentation: \n#\n# ---- Example of a precise path ---- #\n#\n# the drawing is performed as followed: \n# - drawBegin() is called when the user presses the mouse, it must be used to initialize the drawing\n# - drawUpdate(offset) is called when the user drags the mouse, that is where the actual drawing occurs\n# - drawEnd() is called when the user releases the mouse, it can be used to perform final operations\n#\nclass NewPath extends PrecisePath\n	@rname = 'New path' 						# the name used in the sidebar (to create the tool button), must be unique\n	@rdescription = \"New path description.\" 	# the path description\n\n	drawBegin: ()->\n		# initialize the drawing group before drawing, without a child canvas (more info here)\n		@initializeDrawing(false)\n		# add a path to the drawing group\n		@path = @addPath()\n		return\n\n	# offset: position along the control path where we must update the drawing\n	drawUpdate: (offset)->\n		point = @controlPath.getPointAt(offset) 	# get the point where we must update the drawing\n		@path.add(point)							# add a point at this position\n		return\n\n	drawEnd: ()->\n		@path.simplify() 							# simplify the path\n		@path.smooth() 								# smooth the path\n		return\n\n# # ---- Full example of a complexe path ---- #\n#\n# class NewPath extends SpeedPath\n# 	@rname = 'New path' 						# the name used in the sidebar (to create the tool button), must be unique\n# 	@rdescription = \"New path description.\" 	# the path description\n#	@iconUrl = 'static/images/path.png' 		# the icon of the path\n#	@iconAlt = 'path'							# the alternative text for the image (displayed when the image cannot be loaded)\n\n# 	# parameters must return an object listing all parameters of the path\n# 	# those parameters will be accessible to the users from the options bar\n# 	# those parameters are binded to the path data: @data[parameterName]\n#	# the following parameters are reserved for romanesco: id, polygonMode, points, planet, step, smooth, speeds, showSpeeds\n# 	@parameters: ()->\n# 		parameters = super()\n# 		parameters['First folder'] = \n# 			firstParameter:\n# 				type: 'slider' 									# type is only required when adding a color (then it must be 'color')\n# 				label: 'Name of the parameter'					# label of the controller (name displayed in the options bar) (required)\n# 				default: 0 										# default value\n# 				value: 0										# value overrides default if set\n# 				step: 5 										# values will be incremented/decremented by step\n# 				min: 0 											# minimum value\n# 				max: 100 										# maximum value\n# 				simplified: 0 									# value during the simplified mode (useful to quickly draw a path, for example when a user modifies it)\n# 				defaultFunction: () -> 							# called to get a default value\n# 				addController: true 							# if true: adds the dat.gui controller to the item or the selected tool\n# 				onChange: (value)->  							# called when controller changes\n# 				onFinishChange: (value)-> 						# called when controller finishes change\n# 				setValue: (value, item)-> 						# called on set value of controller\n# 				permanent: true									# if true: the controller is never removed (always says in dat.gui)\n# 				defaultCheck: true 								# checked/activated by default or not\n# 				initializeController: (controller, item)->		# called just after controller is added to dat.gui, enables to customize the gui and add functionalities\n# 			secondParameter:\n# 				type: 'slider'\n# 				label: 'Second parameter'\n# 				value: 1\n# 				min: 0\n# 				max: 10\n# 		parameters['Second folder'] = \n# 			thirdParameter:\n# 				type: 'slider'\n# 				label: 'Third parameter'\n# 				value: 1\n# 				min: 0\n# 				max: 10\n# 		return parameters\n	\n# 	# initialize the path only once when it is loaded\n# 	# can be used to initialize animated path or to initialize the path on a video game\n# 	initialize: ()->\n# 		@setAnimated(@data.animate) 		# initialize the animation\n# 		return\n\n# 	drawBegin: ()->\n# 		# initialize the drawing group before drawing, without a child canvas (more info here)\n# 		@initializeDrawing(false)\n# 		# add a path to the drawing group\n# 		@path = @addPath()\n# 		return\n\n# 	# offset: position along the control path where we must update the drawing\n# 	drawUpdate: (offset)->\n	\n# 		one can access the path parameters in the @data property\n# 		firstParameter = @data[firstParameter]\n\n# 		point = @controlPath.getPointAt(offset) 	# get the point where we must update the drawing\n# 		@path.add(point)							# add a point at this position\n\n# 		# one can also get the normal or the tangent of the control path at this position\n# 		normal = @controlPath.getNormalAt(offset)\n# 		tangent = @controlPath.getTangentAt(offset)\n#		# do something with 'normal' and 'tangent'\n#\n# 		# when creating a speed path (using 'class NewPath extends SpeedPath'), one can access the speed value at this position\n# 		speed = @speedAt(offset)\n#		# do something with 'speed'\n#\n# 		# one can convert the point in raster coordinates to draw on the canvas (with @context)\n# 		point = @projectToRaster(point)\n# 		@context.lineTo(point.x, point.y)\n\n# 		return\n\n# 	drawEnd: ()->\n# 		@path.simplify() 							# simplify the path\n# 		@path.smooth() 								# smooth the path\n# 		return\n\n# 	# called at each frame to update the path (for animated path, @setAnimated or @registerAnimation must have been called)\n# 	onFrame: (event)=>\n# 		@path.rotation += @data.rotationSpeed 		# rotate the path by @data.rotationSpeed\n# 		return\n\n# # ---- Example of a shape ---- #\n#\n# class NewShape extends RShape\n# 	@rname = 'New shape' 						# the name used in the sidebar (to create the tool button)\n\n# 	# draw the shape (called whenever the shape must be updated)\n# 	createShape: ()->\n# 		@shape = @addPath(new Path.Rectangle(@rectangle))\n# 		return";

}).call(this);

//# sourceMappingURL=pathSources.map
