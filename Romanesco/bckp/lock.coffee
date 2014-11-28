
# this.askForLink = (name='', message='', url='', update=false)->

# 	modalJ = $('#urlModal')
# 	modalJ.find('input.name').val(name)
# 	modalJ.find('input.url').val(url)
# 	modalJ.find('input.message').val(message)
# 	if update?
# 		modalJ.find('.modal-title').text("Modify your link")
# 		modalJ.find('.btn-primary').text("Modify")
# 	else
# 		modalJ.find("modal-title").text("Add a link to a website")
# 		modalJ.find('.btn-primary').text("Add")
# 	modalJ.modal('show')
# 	modalJ.on('shown.bs.modal', (event)-> modalJ.find('input.name').focus() )
# 	submit = () ->
# 		url = modalJ.find("input.url").val()
# 		if url.indexOf("http://") != 0 && url.indexOf("https://") != 0
# 			url = "http://" + url
# 		name = modalJ.find("input.name").val()
# 		message = modalJ.find("input.message").val()
# 		g.tools['link'].select()
# 		if not update?
# 			saveDiv(tl, br, 'link', message, name, url)
# 		else
# 			g.selectedDiv.update(message, name, url)
# 		modalJ.modal('hide')
# 	modalJ.find('.submit-shortcut').keypress( (event) -> 
# 		if event.which == 13
# 			event.preventDefault()
# 			submit()
# 	)
# 	modalJ.find('.btn-primary').click( (event)-> submit()	)

# this.askForLock = (message='', update=null)->

# 	modalJ = $('#lockModal')
# 	modalJ.find('.message').val(message)
# 	if update?
# 		modalJ.find('.modal-title').text("Modify your area")
# 		modalJ.find('.btn-primary').text("Modify")
# 	else
# 		modalJ.find("modal-title").text("Lock an area")
# 		modalJ.find('.btn-primary').text("Lock")
# 	modalJ.modal('show')
# 	modalJ.on('shown.bs.modal', (event)-> modalJ.find('.message').focus() )
# 	submit = () ->
# 		message = modalJ.find(".message").val()
# 		g.tools['lock'].select()
# 		if not update?
# 			saveDiv(tl, br, 'lock', message)
# 		else
# 			g.selectedDiv.update(message)
# #			updateBox(tl, br, message, "", "", update.pk)
# 		modalJ.modal('hide')
# 	modalJ.find('.submit-shortcut').keypress( (event) -> 
# 		if event.which == 13
# 			event.preventDefault()
# 			submit()
# 	)
# 	modalJ.find('.btn-primary').click( (event)-> submit() )


# this.addLink = (tl, br, url, name, message, owner, pk=null, modified=false)->
# 	linkJ = null
# 	if modified
# 		for lock in g.locks
# 			if lock.attr("data-pk") == pk
# 				linkJ = lock
# 		if linkJ==null
# 			return
# 	else
# 		#check if link already exist (possible if overlaps two planets)
# 		for lock in g.locks
# 			lockOffset = lock.offset()
# 			cx = tl.x+g.canvasJ.offset().left
# 			cy = tl.y+g.canvasJ.offset().top
# 			if lockOffset.left == cx && lockOffset.y == cy
# 				return
# 		linkJ = g.templatesJ.find(".link").clone().prependTo(g.stageJ)
# 		linkJ = g.stageJ.find(".link:first")
# 	linkJ.attr('data-title',name+' by '+owner)
# 	linkJ.attr('data-owner',owner)
# 	linkJ.attr('data-name',name)
# 	linkJ.attr('href',url)
# 	linkJ.attr('data-content',message)
# 	linkJ.popover(placement:'auto top', trigger:'hover')
# 	if modified
# 		return
# 	linkJ.offset( {left: tl.x+g.canvasJ.offset().left, top: tl.y+g.canvasJ.offset().top})
# 	linkJ.width(br.x-tl.x)
# 	linkJ.height(br.y-tl.y)
# 	linkJ.attr("data-pk",pk)
# 	if owner==g.me
# 		updateBtn = g.templatesJ.find("button.updateBtn").clone().prependTo(linkJ)
# 		updateBtn.click( (event)->
# 			event.preventDefault()
# 			linkJ = $(this).parent(".link")
# 			pk = linkJ.attr("data-pk")
# 			owner = linkJ.attr("data-owner")
# 			message = linkJ.attr("data-content")
# 			name = linkJ.attr("data-name")
# 			url = linkJ.attr("href")
# 			update = {pk:pk, name:name, owner:owner, message:message, url:url}
# 			askForLink(new Point(tl.x, tl.y), new Point(br.x, br.y), update)
# 		)
# 	g.locks.push(linkJ)

# this.addLock = (tl, br, message, owner, pk=null, modified=false)->
# 	lockJ = null
# 	if modified
# 		for lock in g.locks
# 			if lock.attr("data-pk") == pk
# 				lockJ = lock
# 		if lockJ==null
# 			return
# 	else
# 		lockJ = g.templatesJ.find(".lock").clone().prependTo(g.stageJ)
# 		lockJ = g.stageJ.find(".lock:first")
# 	lockJ.attr('data-title','This area was locked by ' + owner)
# 	lockJ.attr('data-content',message)
# 	popover = lockJ.popover(placement:'auto top', trigger:'hover')
# 	if modified
# 		return
# 	# popover.on('show.bs.popover', ()->
# 	# 	screenRect = new Rectangle( 0, 0, g.canvasJ.width(), g.canvasJ.height() )
# 	# 	lockJoffset = lockJ.offset()
# 	# 	center = new Point( lockJoffset.left, lockJoffset.top )
# 	# 	thisJ = $(this).find("")
# 	# 	popoverRect = new Rectangle( center.x-thisJ.width()*0.5, center.y-thisJ.height()*0.5 )
# 	# 	if screenRect.contains(popoverRect)
# 	# 		thisJ.find(".arrow").css(display:'none')
# 	# 		thisJ.offset(left: popoverRect.x, top: popoverRect.y)
# 	# )

# 	lockJ.offset( {left: tl.x+g.canvasJ.offset().left, top: tl.y+g.canvasJ.offset().top})
# 	lockJ.width(br.x-tl.x)
# 	lockJ.height(br.y-tl.y)
# 	lockJ.attr("data-pk",pk)
# 	if owner==g.me
# 		updateBtn = g.templatesJ.find("button.updateBtn").clone().prependTo(lockJ)
# 		updateBtn.click( (event)->
# 			event.preventDefault()
# 			lockJ = $(this).parent(".lock")
# 			pk = lockJ.attr("data-pk")
# 			owner = lockJ.attr("data-owner")
# 			message = lockJ.attr("data-content")
# 			update = {pk:pk, owner:owner, message:message}
# 			askForLock(new Point(tl.x, tl.y), new Point(br.x, br.y), update)
# 		)
# 	g.locks.push(lockJ)
