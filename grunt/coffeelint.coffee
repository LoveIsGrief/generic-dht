module.exports = {
  options:
    braces_spacing:
      level: 'error'
      spaces: 0
      empty_object_spaces: 0
    colon_assignment_spacing:
      spacing:
        left: 0
        right: 1
      level: 'error'
    eol_last:
      level: 'error'
    newlines_after_classes:
      value: 2
      level: 'error'
    # Force a string format and since we can't force double quotes :(
    no_unnecessary_double_quotes:
      level: 'error'
    # They are just faulty
    no_unnecessary_fat_arrows:
      level: 'ignore'
  all: [
    '**.coffee'
    '**/*.coffee'
    '!node_modules/**/*.coffee'
  ]
}
