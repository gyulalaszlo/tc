module.exports = ( pack )->
  @line "#include \"#{ pack.name }_types.h\""

  @lines "int main( int argc, char** argv) { return 1; }"
