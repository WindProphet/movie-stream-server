var coffee = require('gulp-coffee');
var sourcemaps = require('gulp-sourcemaps');
var gulp = require('gulp')
 
gulp.task('coffee', function() {
  gulp.src('./src/*.coffee')
    .pipe(sourcemaps.init())
    .pipe(coffee({bare: true}))
    .pipe(sourcemaps.write())
    .pipe(gulp.dest('./lib/'));
});

gulp.task('default', ['coffee'])
