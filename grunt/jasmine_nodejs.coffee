module.exports = {
  options:
    helperNameSuffix: '.js'
    specNameSuffix: 'spec.coffee'
    useHelpers: true
  unit:
    specs: [
      'test/unit/**'
    ]
    helpers: [
      'test/helpers/**'
    ]
}
