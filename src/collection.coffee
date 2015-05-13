path= require 'path'
fs= require 'fs'
childProcess= require 'child_process'
EventEmitter= require('events').EventEmitter

Jasmine= require 'jasmine'
Reporter= require 'jasmine-terminal-reporter'
wanderer= require 'wanderer'

class Collection extends require './utility'
  runJasmine: (specs,options={})->
    runner= new EventEmitter

    jasmine= new Jasmine
    jasmine.addReporter new Reporter
      showColors: true
      isVerbose: options.verbose
      includeStackTrace: options.stacktrace
    jasmine.jasmine.DEFAULT_TIMEOUT_INTERVAL= options.timeout

    code= 0
    wanderer.seek specs
      .on 'data',(file)=>
        filename= path.resolve process.cwd(),file

        @deleteRequireCache require.resolve filename
        jasmine.addSpecFile filename
      .once 'end',->
        code= 1 if jasmine.specFiles.length is 0
        try
          jasmine.execute()
        catch error
          console.error error?.stack?.toString() ? error?.message ? error
          code= 1

    jasmine.addReporter
      specDone: (result)->
        code= 1 if result.status is 'failed'

      jasmineDone: ->
        runner.emit 'close',code

    runner

  coverJasmine: (specs,options={})->
    args= []
    args.push 'node'
    args.push require.resolve 'ibrik/bin/ibrik'
    args.push 'cover'
    args.push require.resolve '../jasminetea'
    args.push '--'
    args= args.concat process.argv[2...]
    args.push '-C'
    @log '$',args.join ' ' if options.debug?

    [script,args...]= args
    childProcess.spawn script,args,{stdio:'inherit',cwd:process.cwd(),env:process.env}

  runProtractor: (specs,options={})->
    runner= new EventEmitter

    exitCode= 0
    @webdriverUpdate(options).once 'close',=>
      protractor= @protractor specs,options
      protractor.stdout.on 'data',(buffer)->
        # fix #1
        exitCode= 1 if buffer.toString().match /Process exited with error code 1\n$/g
        
        process.stdout.write buffer.toString()
      protractor.stderr.on 'data',(buffer)->
        process.stderr.write buffer.toString()
      protractor.on 'error',(stack)->
        console.error error?.stack?.toString() ? error?.message ? error
        runner.emit 'close',1
      protractor.once 'exit',(code)->
        exitCode= 1 if code isnt 0
        runner.emit 'close',exitCode

    runner

  protractor: (specs,options={})->
    args= []
    args.push 'node'
    args.push require.resolve 'protractor/bin/protractor'
    args.push require.resolve '../jasminetea' # module.exprots.config
    if typeof options.e2e is 'string'
      args.push argv for argv in options.e2e.replace(new RegExp('==','g'),'--').split /\s/
    args.push '--specs'
    args.push wanderer.seekSync(specs).join ','
    
    # @log 'Arguments has been ignored',(chalk.underline(arg) for arg in options.args[1...]).join ' '
    @log '$',args.join ' ' if options.debug?

    [script,args...]= args
    childProcess.spawn script,args,env:process.env

  coverProtractor: (specs,options={})->
    runner= new EventEmitter

    @webdriverUpdate(options).once 'close',=>
      args= []
      args.push 'node'
      args.push require.resolve 'ibrik/bin/ibrik'
      args.push 'cover'
      args.push require.resolve 'protractor/bin/protractor'
      args.push '--'
      args.push require.resolve '../jasminetea'# Use Jasminetea.config
      args.push '--specs'
      args.push wanderer.seekSync(specs).join ','
      if typeof options.e2e is 'string'
        args.push argv for argv in options.e2e.replace(new RegExp('==','g'),'--').split /\s/

      @log '$',args.join ' ' if options.debug?

      [script,args...]= args
      child= childProcess.spawn script,args,{stdio:'inherit',cwd:process.cwd(),env:process.env}
      child.on 'exit',(code)->
        runner.emit 'close',code

    runner

  webdriverUpdate: (options={})->
    args= []
    args.push 'node'
    args.push require.resolve 'protractor/bin/webdriver-manager'
    args.push 'update'
    args.push '--standalone'
    @log '$',args.join ' ' if options.debug?

    [script,args...]= args
    childProcess.spawn script,args,stdio:'inherit'

  deleteRequireCache: (id)=>
    return if id.indexOf('node_modules') > -1

    files= require.cache[id]
    if files?
      @deleteRequireCache file.id for file in files.children
    delete require.cache[id]

  report: (options={})->
    exists_token= fs.existsSync path.join process.cwd(),'.coveralls.yml'
    exists_token= process.env.COVERALLS_REPO_TOKEN? if not exists_token
    if not exists_token
      @log 'Skip post a coverage report. Cause not exists COVERALLS_REPO_TOKEN'
      return @noop()

    exists_coverage= fs.existsSync path.join process.cwd(),'coverage','lcov.info'
    if not exists_coverage
      @log 'Skip post a coverage report. Cause not exists ./coverage/lcov.info'
      return @noop()

    args= []
    args.push 'cat'
    args.push path.join process.cwd(),'coverage','lcov.info'
    args.push '|'
    args.push require.resolve 'coveralls/bin/coveralls.js'
    @log '$',args.join ' ' if options.debug?

    options=
      cwd: process.cwd()
      env: process.env
      maxBuffer: 1000*1024
    childProcess.exec args.join(' '),options,(error)=>
      throw error if error?
      @log 'Posted a coverage report.'

  lint: (options={})->
    args= [require.resolve 'coffeelint/bin/coffeelint']
    args.push path.relative process.cwd(),file for file in wanderer.seekSync options.lint
    @log '$',args.join ' ' if options.debug?

    console.log ''
    @log 'Lint by',options.lint.join(' or '),'...'
    childProcess.spawn 'node',args,{stdio:'inherit',cwd:process.cwd()}

module.exports= Collection