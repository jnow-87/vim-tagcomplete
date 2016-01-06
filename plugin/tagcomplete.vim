if exists("g:loaded_tagcomplete") || &compatible
    finish
endif

let g:loaded_tagcomplete = 1


""""
"" global variables
""""
"{{{
let g:tagcomplete_complete_key = get(g:, "tagcomplete_complete_key", "<tab>")
let g:tagcomplete_next_key = get(g:, "tagcomplete_next_key", "<c-n>")
let g:tagcomplete_prev_key = get(g:, "tagcomplete_prev_key", "<c-p>")
let g:tagcomplete_ignore_filetype = get(g:, "tagcomplete_ignore_filetype", {})
"}}}

""""
"" local variables
""""
"{{{
let s:mark_l = '´<'
let s:mark_r = '>`'

let s:tagcomplete_complete_key_shift = substitute(g:tagcomplete_complete_key, '<', "<s-", "")
"}}}

""""
"" functions
""""
"{{{
function s:init()
"{{{
	if has_key(g:tagcomplete_ignore_filetype, &filetype)
		return
	endif

	" completion mappings
    exec "inoremap <buffer> " . g:tagcomplete_complete_key . " <c-r>=<sid>compl_code()<cr>"
	exec "inoremap <expr> <buffer> " . s:tagcomplete_complete_key_shift . " pumvisible() ? '\<c-p>' : '" . g:tagcomplete_complete_key . "'"
"	exec "imap <expr> <buffer> <cr> pumvisible() ? '\<c-y>' : '\<cr>'"

	" select next function argument
	exec "inoremap <silent> <buffer> " . g:tagcomplete_next_key . " <esc>:call <sid>select_arg(0)<cr>"
	exec "vnoremap <silent> <buffer> " . g:tagcomplete_next_key . " <esc>:call <sid>select_arg(0)<cr>"
	exec "nnoremap <silent> <buffer> " . g:tagcomplete_next_key . " :call <sid>select_arg(0)<cr>"

	" select previous function argument
	exec "inoremap <silent> <buffer> " . g:tagcomplete_prev_key . " <esc>:call <sid>select_arg(1)<cr>"
	exec "vnoremap <silent> <buffer> " . g:tagcomplete_prev_key . " <esc>:call <sid>select_arg(1)<cr>"
	exec "nnoremap <silent> <buffer> " . g:tagcomplete_prev_key . " :call <sid>select_arg(1)<cr>"

	" highlight function arguments
	exec "syn region tagcomplete_arg matchgroup=None start='" . s:mark_l . "' end='" . s:mark_r . "' concealends"

	highlight default tagcomplete_arg ctermbg=33
endfunction
"}}}

function s:check_char()
"{{{
	let char = getline('.')[getpos('.')[2] - 2]
	
	if match(char, "[a-zA-Z_]") == 0
		return "\<c-n>"

	elseif char != '('
		return ''
	endif

	return '('
endfunction
"}}}

function s:select_arg(backward)
"{{{
	" get line and cursor
	let line = getline('.')
	let [ bnum, lnum, col, off ] = getpos('.')

	" search start and end pattern
	if a:backward
		let e = strridx(line, s:mark_r, col - len(s:mark_r) - 1)
		let e = (e != -1 ? e : strridx(line, s:mark_r, len(line)))
		let s = strridx(line, s:mark_l, e)
	else
		let s = stridx(line, s:mark_l, col - 1)
		let s = (s != -1 ? s : stridx(line, s:mark_l))
		let e = stridx(line, s:mark_r, s)
	endif

	" return if no valid region found
	if s == -1 || e == -1
		return
	endif

	" select region if found
	call cursor(lnum, s + 1)
	normal gh
	call cursor(lnum, e + len(s:mark_r))
endfunction
"}}}

function s:compl_signature(func_name)
"{{{
	let signature_lst = []
    let signature_word = []

    let ftags = taglist("^" . a:func_name . "$")

    if type(ftags) == type(0) || ((type(ftags) == type([])) && ftags == [])
        return ''
    endif

    for tag in ftags
        if has_key(tag, 'kind') && has_key(tag, 'name') && has_key(tag, 'signature')
			" check if tag is either declare ('p') or defination ('f')
            if (tag.kind == 'p' || tag.kind == 'f' || tag.kind == 'm') && tag.name == a:func_name  
                if match(tag.signature, '(\s*void\s*)') < 0 && match(tag.signature,'(\s*)') < 0
					let tmp = substitute(tag.signature, '(\?\([^,( ]\([^,)]\|, *\.\{3}\)*\))\?', s:mark_l . '\1' . s:mark_r, "g")
                else
                    let tmp = ''
                endif

                if (tmp != '') && (index(signature_word, tmp) == -1)
                    let signature_word += [tmp]
                    let item={}
                    let item['word'] = tmp
                    let item['menu'] = tag.filename
                    let signature_lst += [item]
                endif
            endif
        endif
    endfor

    if signature_lst == []
        return ')'
    endif

    if len(signature_lst) == 1
        return signature_lst[0]['word']
    else
        call complete(col('.'), signature_lst)
        return ''
    endif
endfunction
"}}}

function s:compl_code()
"{{{
	if pumvisible()
		return "\<c-n>"
	endif

	let char = <sid>check_char()

	if char == ''
		return "\<tab>"

	elseif char == '('
		let function_name = matchstr(getline('.')[:(col('.')-2)],'\zs\w*\ze\s*(\s*$')
    	if function_name != ''
        	let funcres = <sid>compl_signature(function_name)

	        return funcres
	    endif
	endif

	return char
endfunction
"}}}
"}}}

""""
"" autocommands
""""
"{{{
autocmd BufReadPost,BufNewFile * call <sid>init()
"}}}
