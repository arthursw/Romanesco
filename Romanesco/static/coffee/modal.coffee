define [
	'utils', 'jquery', 'bootstrap', 'paper'
], (utils) ->

	g = utils.g()

	class RModal
		@modals = []

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
			return @modalBodyJ.append("<p>#{text}</p>")

		@addTextInput: (name, placeholder=null, type=null, className=null, label=null, submitShortcut=false, id=null, required=false, errorMessage)->
			inputJ = @addTextInputA( { name: name,
			placeholder: placeholder,
			type: type,
			className: className,
			label: label,
			submitShortcut: submitShortcut,
			id: id,
			required: required,
			errorMessage: errorMessage} )
			return inputJ

		@addTextInputA: (args)->
			name = args.name
			placeholder = args.placeholder
			type = args.type
			className = args.className
			label = args.label
			submitShortcut = args.submitShortcut
			id = args.id
			required = args.required
			errorMessage = args.errorMessage

			submitShortcut = if submitShortcut then 'submit-shortcut' else ''
			inputJ = $("<input type='#{type}' class='#{className} form-control #{submitShortcut}'>")
			if placeholder? and placeholder != ''
				inputJ.attr("placeholder", placeholder)
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
			return div

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

		@createModal: (args)->
			modal = new RModal(args)
			if @modals.length>0
				zIndex = parseInt(@modals.last().modalJ.css('z-index'))
				modal.modalJ.css('z-index', zIndex + 2)
			@modals.push(modal)
			return modal

		@deleteModal: (modal)->
			modal.delete()
			@modals.remove(modal)
			return

		@getModalByTitle: (title)->
			for modal in @modals
				if modal.title == title
					return modal
			return null

		@getModalByName: (name)->
			for modal in @modals
				if modal.name == name
					return modal
			return null

		# # args: title: 'Title'
		constructor: (args)->
			@data = data: args.data
			@title = args.title
			@name = args.name
			@validation = args.validation
			@postSubmit = args.postSubmit or 'hide'
			@submitCallback = args.submit

			@extractors = [] 				# an array of function used to extract data on the added forms

			@modalJ = @constructor.modalJ.clone()

			g.templatesJ.find('.modals').append(@modalJ)

			@modalBodyJ = @modalJ.find('.modal-body')
			@modalBodyJ.empty()
			@modalJ.find(".modal-footer").show().find(".btn").show()
			@modalJ.on 'shown.bs.modal', (event)=>
				@modalJ.find('input.form-control:visible:first').focus()
				zIndex = parseInt(@modalJ.css('z-index'))
				$('body').find('.modal-backdrop:last').css('z-index', zIndex - 1)

			@modalJ.on('hidden.bs.modal', (event)=> g.RModal.deleteModal(@) )

			@modalJ.find('.btn-primary').click( (event)=> @modalSubmit() )

			@extractors = {}
			@modalJ.find("h4.modal-title").html(args.title)
			@modalJ.find(".modal-footer").show().find(".btn").show()

			return

		addText: (text)->
			@modalBodyJ.append("<p>#{text}</p>")
			return

		addTextInput: (args)->
			name = args.name
			placeholder = args.placeholder
			type = args.type
			className = args.className
			label = args.label
			submitShortcut = args.submitShortcut
			id = args.id
			required = args.required
			errorMessage = args.errorMessage
			defaultValue = args.defaultValue

			if required
				errorMessage ?= "<em>" + (label or name) + "</em> is invalid."

			submitShortcut = if submitShortcut then 'submit-shortcut' else ''
			inputJ = $("<input type='#{type}' class='#{className} form-control #{submitShortcut}'>")
			if placeholder? and placeholder != ''
				inputJ.attr("placeholder", placeholder)
			inputJ.val(defaultValue)
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

			@addCustomContent( { name: name, divJ: inputJ, extractor: extractor, args: args, required: required, errorMessage: errorMessage } )

			return inputJ

		addCheckbox: (args)->
			name = args.name
			label = args.label
			helpMessage = args.helpMessage
			defaultValue = args.defaultValue

			divJ = $("<div>")

			checkboxJ = $("<label><input type='checkbox' form-control>#{label}</label>")
			if defaultValue
				checkboxJ.find('input').attr('checked', true)
			divJ.append(checkboxJ)

			if helpMessage
				helpMessageJ = $("<p class='help-block'>#{helpMessage}</p>")
				divJ.append(helpMessageJ)

			extractor = (data, checkboxJ, name)->
				data[name] = checkboxJ.is(':checked')
				return true

			@addCustomContent( { name: name, divJ: divJ, extractor: extractor, args: checkboxJ } )

			return divJ

		addRadioGroup: (args)->
			name = args.name
			radioButtons = args.radioButtons

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

			@addCustomContent( { name: name, divJ: divJ, extractor: extractor } )

			return divJ

		addCustomContent: (args)->
			args.args ?= args.divJ
			args.divJ.attr('id', 'modal-' + args.name)
			@modalBodyJ.append(args.divJ)
			@extractors[args.name] = args
			return

		show: ()->
			@modalJ.find('.submit-shortcut').keypress (event) => 		# submit modal when enter is pressed
				if event.which == 13 	# enter key
					event.preventDefault()
					@modalSubmit()
				return
			@modalJ.modal('show')
			return

		hide: ()->
			@modalJ.modal('hide')
			return

		addProgressBar: ()->
			progressJ = $(""" <div class="progress modal-progress-bar">
				<div class="progress-bar progress-bar-striped active" role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width: 100%">
					<span class="sr-only">Loading...</span>
				</div>
			</div>""")
			@modalBodyJ.append(progressJ)
			return

		removeProgressBar: ()->
			@modalBodyJ.find('.modal-progress-bar').remove()
			return

		modalSubmit: ()->

			@modalJ.find(".error-message").remove()
			valid = true
			for name, extractor of @extractors
				valid &= extractor.extractor(@data, extractor.args, name, extractor.required)
				if not valid
					errorMessage = extractor.errorMessage
					errorMessage ?= 'The field "' + name + '"" is invalid.'
					@modalBodyJ.append("<div class='error-message'>#{errorMessage}</div>")

			if not valid or @validation? and not @validation(data) then return

			@submitCallback?(@data)
			@extractors = {}

			switch @postSubmit
				when 'hide'
					@modalJ.modal('hide')
				when 'load'
					@modalBodyJ.children().hide()
					@addProgressBar()
			return

		delete: ()->
			@modalJ.remove()
			return

	g.RModal = RModal
	return