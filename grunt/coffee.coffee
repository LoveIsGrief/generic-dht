module.exports = {
  dist:
    options:
      bare: true
    files: [
      {
        expand: true
        cwd: "src/"
        src: [
          "*.coffee"
          "**/*.coffee"
        ]
        dest: "src/"
        ext: ".js"
      }
    ]
}
