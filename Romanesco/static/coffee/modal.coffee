define [
	'utils', 'jquery', 'bootstrap', 'paper'
], (utils) ->

	g = utils.g()

	class RModal

		@extractors = [] 				# an array of function used to extract data on the added forms

		# initialize the modal jQuery element
		@modalJ = $('#customModal')
		@modalBodyJ = @modalJ.find('.modal-body')
		# focus on the first visible element when the modal shows up
		@modalJ.on('shown.bs.modal', (event)=> @modalJ.find('input.form-control:visible:first').focus() )
		@modalJ.find('.btn-primary').click( (event)=> @modalSubmit() )

		@initialize: (title, @submitCallback, @validation=null, @hideOnSubmit=true)->
			@modalBodyJ.empty()
			@extractors = {}
			@modalJ.find("h4.modal-title").html(title)
			@modalJ.find(".modal-footer").show().find(".btn").show()
			return

		@alert: (message, title='Info')->
			@initialize(title)
			@addText(message)
			g.RModal.modalJ.find("[name='cancel']").hide()
			g.RModal.show()
			return

		@addText: (text)->
			@modalBodyJ.append("<p>#{text}</p>")
			return

		@addTextInput: (name, placeholder=null, type=null, className=null, label=null, submitShortcut=false, id=null, required=false, errorMessage)->

			submitShortcut = if submitShortcut then 'submit-shortcut' else ''
			inputJ = $("<input type='#{type}' class='#{className} form-control #{submitShortcut}' placeholder='#{placeholder}'>")
			if required
				errorMessage ?= "<em>" + (label or name) + "</em> is invalid."
				inputJ.attr('data-error', errorMessage)
			args = inputJ

			extractor = (data, inputJ, name, required=false)->
				data[name] = inputJ.val()
				return ( not required ) or ( data[name]? and data[name] != '' )

			if label
				inputID = 'modal-' + name + '-' + Math.random().toString()
				inputJ.attr('id', inputID)
				divJ = $("<div id='#{id}' class='form-group #{className}-group'></div>")
				labelJ = $("<label for='#{inputID}'>#{label}</label>")
				divJ.append(labelJ)
				divJ.append(inputJ)
				inputJ = divJ

			@addCustomContent(name, inputJ, extractor, args, required)

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
				return true

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

			extractor = (data, divJ, name, required=false)->
				choiceJ = divJ.find("input[type=radio][name=#{name}]:checked")
				data[name] = choiceJ[0]?.value
				return ( not required ) or ( data[name]? )

			@addCustomContent(name, divJ, extractor)

			return divJ

		@addCustomContent: (name, div, extractor, args=null, required=false)->
			args ?= div
			div.attr('id', 'modal-' + name)
			@modalBodyJ.append(div)
			@extractors[name] = { extractor: extractor, args: args, div: div, required: required }
			return

		@show: ()->
			@modalJ.find('.submit-shortcut').keypress (event) => 		# submit modal when enter is pressed
				if event.which == 13 	# enter key
					event.preventDefault()
					@modalSubmit()
				return
			@modalJ.modal('show')
			return

		@hide: ()->
			@modalJ.modal('hide')
			return

		@modalSubmit: ()->
			data = {}

			@modalJ.find(".error-message").remove()
			valid = true
			for name, extractor of @extractors
				valid &= extractor.extractor(data, extractor.args, name, extractor.required)
				if not valid
					errorMessage = extractor.div.find("[data-error]").attr('data-error')
					errorMessage ?= 'The field "' + name + '"" is invalid.'
					@modalBodyJ.append("<div class='error-message'>#{errorMessage}</div>")

			if not valid or @validation? and not @validation(data) then return

			@submitCallback?(data)
			@extractors = {}
			if @hideOnSubmit
				@modalBodyJ.empty()
				@modalJ.modal('hide')
			return

	g.RModal = RModal
	return