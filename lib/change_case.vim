"This is a simple procedure to change variables names from this_variable_style
"to thisVariableStyle.

"The commands below define these mappings:

"+   Find the next variable_with_underscores.

"_   Convert the next underscore on the current line.

"When required, you can yank the following lines in Vim (on the first line,
"type 2Y), then execute them (type @") to map the + and _ keys.

:nnoremap + /[a-z]\+_<CR>
:nnoremap _ f_x~

"Now you can press + to search for the next $variable_with_underscores, then
"press _ to find and delete the next underscore and toggle the case of the next
"character. Repeatedly press _ until all underscores are processed, then press
"+ to find the next variable. For example, you may type +__+_+___ to skip
"through a file.

"Type +~ for initial capitals.
