module.exports = {

  sourcesAndTests:
    files: [
      'src/*.coffee'
      'src/**/*.coffee'
      'test/unit/*.coffee'
      'test/unit/**/*.coffee'
    ]
    tasks: [
      'coffeelint:sourcesAndTests'
      'jasmine_nodejs:unit'
    ]

  configs:
    options:
      reload: true
    files: [
      'Gruntfile.coffee'
      'grunt/**.coffee'
    ]
}
