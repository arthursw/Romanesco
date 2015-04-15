class RModal

	@extractors = [] 				# an array of function used to extract data on the added forms

	# initialize the modal jQuery element
	@modalJ = $('#customModal')
	@modalBodyJ = @modalJ.find('.modal-body')
	# focus on the first visible element when the modal shows up
	@modalJ.on('shown.bs.modal', (event)=> @modalJ.find('input.form-control:visible:first').focus() )
	@modalJ.find('.btn-primary').click( (event)=> @modalSubmit() )

	@initialize: (title, @submitCallback)->
		@modalBodyJ.empty()
		@extractors = {}
		@modalJ.find("h4.modal-title").html(title)
		return

	@addTextInput: (name, placeholder=null, type=null, className=null, label=null, submitShortcut=false, id=null)->

		submitShortcut = if submitShortcut then 'submit-shortcut' else ''
		inputJ = $("<input type='#{type}' class='#{className} form-control #{submitShortcut}' placeholder='#{placeholder}'>")
		args = inputJ

		extractor = (data, inputJ, name)->
			data[name] = inputJ.val()
			return

		if label
			inputID = 'modal-' + name + '-' + Math.random().toString()
			inputJ.attr('id', inputID)
			divJ = $("<div id='#{id}' class='form-group #{className}-group'></div>")
			labelJ = $("<label for='#{inputID}'>#{label}</label>")
			divJ.append(labelJ)
			divJ.append(inputJ)
			inputJ = divJ

		@addCustomContent(name, inputJ, extractor, args)

		return inputJ

	@addCheckbox: (name, label, helpMessage=null)->
		divJ = $("<div>")

		checkboxJ = $("<label><input type='checkbox' form-control>#{label}</label>")
		divJ.append(checkboxJ)

		if helpMessage
			helpMessageJ = $("<p class='help-block'>#{helpMessage}</p>")
			divJ.append(helpMessageJ)

		extractor = (data, checkboxJ, name)->
			data[name] = checkboxJ.is(':checked')
			return

		@addCustomContent(name, divJ, extractor, checkboxJ)

		return divJ

	@addRadioGroup: (name, radioButtons)->
		divJ = $("<div>")

		for radioButton in radioButtons
			radioJ = $("<div class='radio'>")
			labelJ = $("<label>")
			checked = if radioButton.checked then 'checked' else ''
			submitShortcut = if radioButton.submitShortcut then 'class="submit-shortcut"' else ''
			inputJ = $("<input type='radio' name='#{name}' value='#{radioButton.value}' #{checked} #{submitShortcut}>")
			labelJ.append(inputJ)
			labelJ.append(radioButton.label)
			radioJ.append(labelJ)
			divJ.append(radioJ)

		extractor = (data, divJ, name)->
			data[name] = divJ.find("input[type=radio][name=#{name}]:checked")[0].value
			return

		@addCustomContent(name, divJ, extractor)

		return divJ

	@addCustomContent: (name, div, extractor, args=null)->
		args ?= div
		div.attr('id', 'modal-' + name)
		@modalBodyJ.append(div)
		@extractors[name] = { extractor: extractor, args: args, div: div }
		return

	@show: ()->
		@modalJ.find('.submit-shortcut').keypress (event) => 		# submit modal when enter is pressed
			if event.which == 13 	# enter key
				event.preventDefault()
				@modalSubmit()
			return
		@modalJ.modal('show')
		return

	@modalSubmit: ()->
		data = {}
		for name, extractor of @extractors
			extractor.extractor(data, extractor.args, name)
		@submitCallback(data)
		@modalBodyJ.empty()
		@extractors = {}
		@modalJ.modal('hide')
		return

@RModal = RModal