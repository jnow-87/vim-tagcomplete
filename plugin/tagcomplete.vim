"==================================================
" File:         code_complete.vim
" Brief:        function parameter complete, code snippets, and much more.
" Author:       Mingbai <mbbill AT gmail DOT com>
" Last Change:  2007-07-20 17:39:10
" Version:      2.7
"
" Install:      1. Put code_complete.vim to plugin
"                  directory.
"               2. Use the command below to create tags
"                  file including signature field.
"                  ctags -R --c-kinds=+p --fields=+S .
"
" Usage:
"           hotkey:
"               "<tab>" (default value of g:completekey)
"               Do all the jobs with this key, see
"           example:
"               press <tab> after function name and (
"                 foo ( <tab>
"               becomes:
"                 foo ( `<first param>`,`<second param>` )
"               press <tab> after code template
"                 if <tab>
"               becomes:
"                 if( `<...>` )
"                 {
"                     `<...>`
"                 }
"
"
"           variables:
"
"               g:completekey
"                   the key used to complete function
"                   parameters and key words.
"
"               g:rs, g:re
"                   region start and stop
"               you can change them as you like.
"
"               g:user_defined_snippets
"                   file name of user defined snippets.
"
"           key words:
"               see "templates" section.
"==================================================

if v:version < 700
    finish
endif

" Variable Definations: {{{1
" options, define them as you like in vimrc:
if !exists("g:completekey")
    let g:completekey = "<tab>"   "hotkey
endif

if !exists("g:rs")
    let g:rs = "'<"    "region start
endif

if !exists("g:re")
    let g:re = ">`"    "region stop
endif

if !exists("g:user_defined_snippets")
    let g:user_defined_snippets = "$VIMRUNTIME/plugin/my_snippets.vim"
endif

" ----------------------------
let s:expanded = 0  "in case of inserting char after expand
let s:signature_list = []
let s:jumppos = -1
let s:doappend = 1
let s:completed = 0
"let s:tab_state = -1
let s:tab_state = 0 
	" state used for handling g:completekey actions
	" -1 - normal insertion
	" 0 - normal insertion (make tab after one completion)
	" 1 - ( discovered
	" 2 - completion inside ()
	" 3 - switch region inside ()

let s:compl_state = 0
	" state used for handling completion type (depending on popup menu (pum) state)
	" 0 - pum not visible
	" 1 - pum visible


" Autocommands: {{{1
"autocmd BufReadPost,BufNewFile *.[ch],*.cc call CodeCompleteStart()
autocmd BufReadPost,BufNewFile * call CodeCompleteStart()

" Menus:
"menu <silent>       &Tools.Code\ Complete\ Start          :call CodeCompleteStart()<CR>
"menu <silent>       &Tools.Code\ Complete\ Stop           :call CodeCompleteStop()<CR>

" Function Definations: {{{1

function! CodeCompleteStart()
    exec "silent! iunmap  <buffer> ".g:completekey
    exec "inoremap <buffer> ".g:completekey." <c-r>=CodeComplete()<cr><c-r>=SwitchRegion()<cr>"
endfunction

function! CodeCompleteStop()
    exec "silent! iunmap <buffer> ".g:completekey
endfunction

function! FunctionComplete(fun)
    let s:signature_list=[]
    let signature_word=[]
    let ftags=taglist("^".a:fun."$")
    if type(ftags)==type(0) || ((type(ftags)==type([])) && ftags==[])
        return ''
    endif
    for i in ftags
        if has_key(i,'kind') && has_key(i,'name') && has_key(i,'signature')
            if (i.kind=='p' || i.kind=='f') && i.name==a:fun  " p is declare, f is defination
                if match(i.signature,'(\s*void\s*)')<0 && match(i.signature,'(\s*)')<0
                    let tmp=substitute(i.signature,',',g:re.', '.g:rs,'g')   " ', ' eingefuegt
                    let tmp=substitute(tmp,'(\(.*\))',g:rs.'\1'.g:re,'g') " ');' eingefügt
                else
                    let tmp=''
                endif
                if (tmp != '') && (index(signature_word,tmp) == -1)
                    let signature_word+=[tmp]
                    let item={}
                    let item['word']=tmp
                    let item['menu']=i.filename
                    let s:signature_list+=[item]
                endif
            endif
        endif
    endfor
    if s:signature_list==[]
        return ')'
    endif
    if len(s:signature_list)==1
        return s:signature_list[0]['word']
    else
        call  complete(col('.'),s:signature_list)
        return ''
    endif
endfunction

function! ExpandTemplate(cword)
    "let cword = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
    if has_key(g:template,&ft)
        if has_key(g:template[&ft],a:cword)
            let s:jumppos = line('.')
            return "\<c-w>" . g:template[&ft][a:cword]
        endif
    endif
    if has_key(g:template['_'],a:cword)
        let s:jumppos = line('.')
        return "\<c-w>" . g:template['_'][a:cword]
    endif
    return ''
endfunction

function! CheckChar()
	let myline=getline('.')
	let mypos=getpos('.')
	let mychar=myline[mypos[2]-2]
	
	if match(mychar, "[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_]") == 0
		let s:doappend=0
		
		if &omnifunc != ''
			if pumvisible() == 1
				if s:compl_state == 1
					let s:compl_state = 0
					return "\<c-x>\<c-o>"
				else
					let s:compl_state = 1
					return "\<c-x>\<c-i>"
				endif
			else
				let s:compl_state = 1
				return "\<c-x>\<c-i>"
			endif
		endif
	
		return "\<c-x>\<c-i>"

	elseif match(mychar, "(") != 0
		return ''
	endif
	return '('
endfunction

function! SwitchRegion()
	if s:tab_state == 1
		let s:tab_state = 2
	elseif s:tab_state == 4
		let s:tab_state = 2
	else 
		return ''
	endif

	if len(s:signature_list)>1
       	let s:signature_list=[]
       	return ''
   	endif
   
	if s:jumppos != -1
       	call cursor(s:jumppos,0)
       	let s:jumppos = -1
   	endif

	if match(getline('.'),g:rs.'.*'.g:re)!=-1 || search(g:rs.'.\{-}'.g:re)!=0
       	normal 0
       	call search(g:rs,'c',line('.'))
       	normal v
       	call search(g:re,'e',line('.'))
       	if &selection == "exclusive"
           	exec "norm " . "\<right>"
       	endif
       	return "\<c-\>\<c-n>gvo\<c-g>"
   	else
"		let s:tab_state = -1
		let s:tab_state = 0
       	if s:doappend == 1
           	if g:completekey == "<tab>"
               return "\<tab>"
           	endif
       	endif
       	return ''
   	endif
endfunction

function! CodeComplete()
   	let s:doappend = 1

	let tmp = CheckChar()

	if tmp == '('
		let s:tab_state = 1
	endif


"	if s:tab_state == 0
"		let s:tab_state = -1
"		return "\<tab>"
"	elseif s:tab_state == -1
	if s:tab_state == 0
"		let s:tab_state = 0
		if tmp == ''
			return "\<tab>"
		endif

		return tmp

	elseif s:tab_state == 1		" insert function stuff
		let function_name = matchstr(getline('.')[:(col('.')-2)],'\zs\w*\ze\s*(\s*$')
    	if function_name != ''
        	let funcres = FunctionComplete(function_name)
	        if funcres != ''
    	        let s:doappend = 0
        	endif

	        return funcres
    	else
        	let template_name = substitute(getline('.')[:(col('.')-2)],'\zs.*\W\ze\w*$','','g')
	        let tempres = ExpandTemplate(template_name)
    	    if tempres != ''
        	    let s:doappend = 0
	        endif

    	    return tempres
	    endif

	elseif s:tab_state == 2
		let s:tab_state = 3
		return tmp

	elseif s:tab_state == 3		" switch region
		let s:tab_state = 4
	endif

	return tmp
endfunction


" [Get converted file name like __THIS_FILE__ ]
function! GetFileName()
    let filename=expand("%:t")
    let filename=toupper(filename)
    let _name=substitute(filename,'\.','_',"g")
    let _name="__"._name."__"
    return _name
endfunction

" Templates: {{{1
" to add templates for new file type, see below
"
" "some new file type
" let g:template['newft'] = {}
" let g:template['newft']['keyword'] = "some abbrevation"
" let g:template['newft']['anotherkeyword'] = "another abbrevation"
" ...
"
" ---------------------------------------------
" C templates
let g:template = {}
let g:template['c'] = {}
let g:template['c']['co'] = "/*  */\<left>\<left>\<left>"
let g:template['c']['cc'] = "/**<  */\<left>\<left>\<left>"
let g:template['c']['df'] = "#define  "
let g:template['c']['ic'] = "#include  \"\"\<left>"
let g:template['c']['ii'] = "#include  <>\<left>"
let g:template['c']['ff'] = "#ifndef  \<c-r>=GetFileName()\<cr>\<CR>#define  \<c-r>=GetFileName()\<cr>".
            \repeat("\<cr>",5)."#endif  /*\<c-r>=GetFileName()\<cr>*/".repeat("\<up>",3)
let g:template['c']['for'] = "for( ".g:rs."...".g:re." ; ".g:rs."...".g:re." ; ".g:rs."...".g:re." )\<cr>{\<cr>".
            \g:rs."...".g:re."\<cr>}\<cr>"
let g:template['c']['main'] = "int main(int argc, char \*argv\[\])\<cr>{\<cr>".g:rs."...".g:re."\<cr>}"
let g:template['c']['switch'] = "switch ( ".g:rs."...".g:re." )\<cr>{\<cr>case ".g:rs."...".g:re." :\<cr>break;\<cr>case ".
            \g:rs."...".g:re." :\<cr>break;\<cr>default :\<cr>break;\<cr>}"
let g:template['c']['if'] = "if( ".g:rs."...".g:re." )\<cr>{\<cr>".g:rs."...".g:re."\<cr>}"
let g:template['c']['while'] = "while( ".g:rs."...".g:re." )\<cr>{\<cr>".g:rs."...".g:re."\<cr>}"
let g:template['c']['ife'] = "if( ".g:rs."...".g:re." )\<cr>{\<cr>".g:rs."...".g:re."\<cr>} else\<cr>{\<cr>".g:rs."...".
            \g:re."\<cr>}"

" ---------------------------------------------
" C++ templates
let g:template['cpp'] = g:template['c']

" ---------------------------------------------
" common templates
let g:template['_'] = {}
let g:template['_']['xt'] = "\<c-r>=strftime(\"%Y-%m-%d %H:%M:%S\")\<cr>"

" ---------------------------------------------
" load user defined snippets
exec "silent! runtime ".g:user_defined_snippets


" vim: set ft=vim ff=unix fdm=marker :
