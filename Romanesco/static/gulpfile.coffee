# Load all required libraries.
gulp 		= require 'gulp'
gutil 		= require 'gulp-util'
cache 	= require 'gulp-cached'
coffee 		= require 'gulp-coffee'
coffeelint 	= require 'gulp-coffeelint'
# watchless 	= require 'gulp-watch-less'
less 		= require 'gulp-less'

sources =
	coffee: 'coffee/*.coffee'
	less: 'less/*.less'

# Compile coffeescript
gulp.task 'coffee', ->
	coffeeStream = coffee( bare: true ).on('error', gutil.log)
	gulp.src sources.coffee
		.pipe cache 'building'
		.pipe coffeeStream
		.pipe gulp.dest './js/'

# Lint coffeescript
gulp.task 'lint', ->
	coffeeStream = coffee( bare: true ).on('error', gutil.log)
	gulp.src sources.coffee
		.pipe cache 'linting'
		.pipe coffeelint()
		.pipe coffeelint.reporter()

# Compile less
gulp.task 'less', ->
	gulp.src sources.less
		# .pipe watchless(sources.less)
		.pipe less()
		.pipe gulp.dest './css/'

# Watch sources to launch tasks
gulp.task 'watch', ->
	gulp.watch sources.coffee, ['coffee', 'lint']
	gulp.watch sources.less, ['less']

# Default task call every tasks created so far.
gulp.task 'default', ['watch']

