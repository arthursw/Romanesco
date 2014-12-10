# This is called with the results from from FB.getLoginStatus().
statusChangeCallback = (response) ->
	console.log "statusChangeCallback"
	console.log response
	
	# The response object is returned with a status field that lets the
	# app know the current login status of the person.
	# Full docs on the response object can be found in the documentation
	# for FB.getLoginStatus().
	if response.status is "connected"
		
		# Logged into your app and Facebook.
		g.loggedIntoFacebook = true
		# testAPI()
	else if response.status is "not_authorized"
		
		# The person is logged into Facebook, but not your app.

		console.log "Please log into this app."

	else
		
		# The person is not logged into Facebook, so we're not sure if
		# they are logged into this app or not.
		console.log "Please log into Facebook."
		g.loggedIntoFacebook = false


	return

# This function is called when someone finishes with the Login
# Button.  See the onlogin handler attached to it in the sample
# code below.
checkLoginState = ->
	FB.getLoginStatus (response) ->
		statusChangeCallback response
		return

	return
# enable cookies to allow the server to access 
# the session
# parse social plugins on this page
# use version 2.0

# Now that we've initialized the JavaScript SDK, we call 
# FB.getLoginStatus().  This function gets the state of the
# person visiting this page and can return one of three states to
# the callback you provide.  They can be:
#
# 1. Logged into your app ('connected')
# 2. Logged into Facebook, but not your app ('not_authorized')
# 3. Not logged into Facebook and can't tell if they are logged into
#    your app or not.
#
# These three cases are handled in the callback function.

# Load the SDK asynchronously

# Here we run a very simple test of the Graph API after login is
# successful.  See statusChangeCallback() for when this call is made.
testAPI = ->
	console.log "Welcome!  Fetching your information.... "
	FB.api "/me", (response) ->
		console.log "Successful login for: " + response.name
		document.getElementById("status").innerHTML = "Thanks for logging in, " + response.name + "!"
		return

	# FB.ui( { method: 'feed' } )

	# FB.ui(
	# 	method: "feed"
	# 	name: "The Facebook SDK for Javascript"
	# 	caption: "Bringing Facebook to the desktop and mobile web"
	# 	description: ("A small JavaScript library that allows you to harness " + "the power of Facebook, bringing the user's identity, " + "social graph and distribution power to your site.")
	# 	link: "https://developers.facebook.com/docs/reference/javascript/"
	# 	picture: "http://www.fbrell.com/public/f8.jpg"
	# , (response) ->
	# 	if response and response.post_id
	# 		alert "Post was published."
	# 	else
	# 		alert "Post was not published."
	# 	return
	# )

	return

# initialize facebook
window.fbAsyncInit = ->
	FB.init
		appId: "401623863314694"
		cookie: true
		xfbml: true
		version: "v2.0"

	FB.getLoginStatus (response) ->
		statusChangeCallback response
		return


	return

((d, s, id) ->
	js = undefined
	fjs = d.getElementsByTagName(s)[0]
	return  if d.getElementById(id)
	js = d.createElement(s)
	js.id = id
	js.src = "//connect.facebook.net/en_US/sdk.js"
	fjs.parentNode.insertBefore js, fjs
	return
) document, "script", "facebook-jssdk"