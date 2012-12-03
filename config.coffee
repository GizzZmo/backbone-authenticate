exports.config =
  # See http://brunch.readthedocs.org/en/latest/config.html for documentation.
  modules:
    wrapper: false
    definition: false
  paths:
    app: 'src'
    public: 'build'
  files:
    javascripts:
      joinTo:
        'hyperbone.yutani.js': /^src/
        'test/test.js': /^test/
      order:
        before: [
          'src/yutani.coffee'
        ]
