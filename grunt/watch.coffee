module.exports = {

  sourcesAndUnitTests:
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

  integrationTests:
    files: [
      'test/integration/*.coffee'
      'test/integration/**/*.coffee'
    ]
    tasks: [
      'coffeelint:sourcesAndTests'
      'jasmine_nodejs:integration'
    ]

  configs:
    options:
      reload: true
    files: [
      'Gruntfile.coffee'
      'grunt/**.coffee'
    ]
}
