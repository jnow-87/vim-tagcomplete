if exists("g:loaded_tagcomplete") || &compatible
    finish
endif

let g:loaded_tagcomplete = 1

" get own script ID
nmap <c-f11><c-f12><c-f13> <sid>
let s:sid = "<SNR>" . maparg("<c-f11><c-f12><c-f13>", "n", 0, 1).sid . "_"
nunmap <c-f11><c-f12><c-f13>


""""
"" global variables
""""
"{{{
let g:tagcomplete_map_complete = get(g:, "tagcomplete_map_complete", "<tab>")
let g:tagcomplete_map_select = get(g:, "tagcomplete_map_select", "<cr>")
let g:tagcomplete_map_next = get(g:, "tagcomplete_map_next", "<c-n>")
let g:tagcomplete_map_prev = get(g:, "tagcomplete_map_prev", "<c-p>")

let g:tagcomplete_ignore_filetype = get(g:, "tagcomplete_ignore_filetype", {})
"}}}

""""
"" local variables
""""
"{{{
let s:mark_l = '´<'
let s:mark_r = '>`'

let s:tagcomplete_map_complete_shift = substitute(g:tagcomplete_map_complete, '<', "<s-", "")
"}}}

""""
"" local functions
""""
"{{{
function s:init()
"{{{
	if has_key(g:tagcomplete_ignore_filetype, &filetype)
		return
	endif

	" completion mappings
	call util#map#i(g:tagcomplete_map_complete, "<c-r>=" . s:sid . "compl_code()<cr>", "<buffer> noescape noinsert")
	call util#map#i(s:tagcomplete_map_complete_shift, "pumvisible() ? '\<c-p>' : '" . g:tagcomplete_map_complete . "'", "<buffer> <expr> noescape noinsert")
	call util#map#i(g:tagcomplete_map_select, "pumvisible() ? '\<c-y>' : '\<cr>'", "<buffer> <expr> noescape noinsert")

	" select next function argument
	call util#map#nvi(g:tagcomplete_map_next, ":call " . s:sid . "select_arg('f')<cr>", "<buffer>")

	" select previous function argument
	call util#map#nvi(g:tagcomplete_map_prev, ":call " . s:sid . "select_arg('b')<cr>", "<buffer>")

	" autocmd to select first function argument of signature
	autocmd CompleteDone <buffer> call feedkeys("\<esc>") | call s:select_arg('i') | call feedkeys("i\<right>")

	" highlight function arguments
	exec "syn region tagcomplete_arg matchgroup=None start='" . s:mark_l . "' end='" . s:mark_r . "' concealends"
endfunction
"}}}

function s:check_char()
"{{{
	let char = getline('.')[getpos('.')[2] - 2]
	
	if match(char, "[a-zA-Z0-9_]") == 0
		return "\<c-n>"

	elseif char != '('
		return ''
	endif

	return '('
endfunction
"}}}

function s:select_arg(search_mode)
"{{{
	" get line and cursor
	let line = getline('.')
	let [ bnum, lnum, col, off ] = getpos('.')

	" search start and end pattern
	if a:search_mode == 'b'
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

	" when selecting an argument right after calling compl_signature()
	" the cursor is somehow moved left once through the autocommand on
	" 'CompleteDone', even though feedkeys("\<esc>") is executed before
	" calling select_arg(), to compensate for that move the selection to
	" the right by 1
	if a:search_mode == 'i'
		let e += 1
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

	let char = s:check_char()

	if char == ''
		return "\<tab>"

	elseif char == '('
		let function_name = matchstr(getline('.')[:(col('.')-2)],'\zs\w*\ze\s*(\s*$')
    	if function_name != ''
        	return s:compl_signature(function_name)
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
autocmd BufReadPost,BufNewFile * call s:init()
"}}}

""""
"" highlighting
""""
"{{{
highlight default tagcomplete_arg ctermbg=33
"}}}
