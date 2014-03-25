winston = require('winston');

_program = null

# Add the common TC options to the command line
exports.addCommonOptions = (program)->
  _program = program
  program
    .option( '-R, --root [dir]', 'The root of the package tree', 'examples' )
    .option('-v, --verbose', 'More status messages.')

# Validate the package list
exports.checkPackageList = checkPackageList = (pkgs, options)->
  if !pkgs.length
    winston.error('Packages argument required required')
    process.exit(1)

# Check for erros and display them in the CLI if necessary
exports.errorChecks = runWithErrorChecks = (err, result)->
  winston.info "Result:", result
  if err
    winston.error err.toString()
    winston.error()
    winston.error("(LINES FROM async.js OMITTED. USE -v TO SHOW THEM)");
    winston.error()

    for line,i  in err.stack.split /\n/
      if /async\.js/.test line
        winston.error "  -> #{line}" if _program.verbose
      else
        winston.error line


    process.exit(1)
