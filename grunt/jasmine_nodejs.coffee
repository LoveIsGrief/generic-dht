seed = Math.floor(Math.random()*1000)
console.log 'Seed for test order ', seed
module.exports = {
  options:
    helperNameSuffix: '.js'
    random: true
    seed: seed
    specNameSuffix: 'spec.coffee'
    stopOnFailure: true
    useHelpers: true
  unit:
    specs: [
      'test/unit/**'
    ]
    helpers: [
      'test/helpers/**'
    ]
  integration:
    specs: [
      'test/integration/**'
    ]
    helpers: [
      'test/helpers/**'
    ]
}
