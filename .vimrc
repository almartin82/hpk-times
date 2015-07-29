  set textauto

  " Remove all autocommands in case this file is sourced
  autocmd!

  " Turn on vim defaults (instead of vi compatibility)
  set nocompatible
  set viminfo='32,f0,\"10,n~/viminfo

  " Set shell
  set shell=/bin/bash

  " I like being able to switch buffers without a !
  set hidden

  " Set grep
  "set grepprg=c:\bin\grep.exe\ -n

  " Set editing parameters
  set visualbell
  set showmatch
  set bs=2 "allow backspacing over everything in insert mode
  set nobackup
  set autoread

  " Set window parameters
  set laststatus=2
  set ruler
  set showcmd
  set showmode
  set nowrap
  set sidescroll=1
  set splitbelow
  set directory=~

  " Set tab & indent options
  set autoindent
  set smartindent
  set expandtab
  set smarttab
  set shiftwidth=4
  set tabstop=4
  set formatoptions=cq2
  set textwidth=78

  " Turn off folding, period
  normal zn

  " Set search options
  "set ignorecase
  set nohlsearch

  "Autocompletion
  set complete=.,w,b

  " setting wildchar expansion
  set wildchar=^I
  set suffixes=.bak,.obj,.swp

  " Set spell check options
  set nospell
  set spelllang=en_us

  " Set gui parameters
  " set guifont=Monospace\ 10
  set guifont=Deja\ Vu\ Sans\ Mono\ 11
  "set lines=54
  "set columns=120
  "set guioptions=amgr
  set guioptions=a
  set mousehide

  " Set key mappings
  mapclear
  map <PageUp> 
  map <PageDown> 
  map <Home> 0
  map <End> $
  map <C-Home> 1G
  map <C-End> G$

  map <M-[> -
  map <M-]> +
  map <M-o> :only
  map <M-r> r

  map O5C :bnext
  map O5D :bprevious
  map <M-k> <Up>
  map <M-j> <Down>

  map <M-b> :buffers
  map <C-F4> :bdelete
  " Remove white space from otherwise empty lines
  map <M-w> :%s/^[ \t]\+$//``

  " Note that the following command prints the file as it exists on disk,
  " excluding any unsaved changes in the buffer.
  "map <M-p> :!ens %
  
  " Turn on syntax highlighting.
  syntax clear
  set background=dark
  syntax on

  "turn on explorer vim
  "so <sfile>:h/macros/explorer.vim

  syn keyword myBUG contained	BUG IKDBUG
  syn keyword myType	i8 u8 i16 u16 i32 u32 i16 u64 f32 f64 tText tStatus tBoolean

  " Set colors
  hi Normal guibg=Black guifg=gray70
  hi Cursor guibg=LightGreen guifg=Black

"  hi Comment     ctermfg=green   guifg=#00a000
"  hi Constant    ctermfg=red     guifg=#ff0000
"  hi Special     ctermfg=brown   guifg=#808000
"  hi Identifier  ctermfg=cyan    guifg=#00ffff
"  hi Statement   ctermfg=yellow  guifg=#ffff00
"  hi PreProc     ctermfg=red     guifg=#ff00ff
"  hi Type        ctermfg=green   guifg=#00ff00
"  hi Todo        guibg=#808000 guifg=#ffff00
"  hi Visual      gui=reverse guibg=NONE guifg=NONE

  hi myBUG       ctermfg=brown guibg=#808000 guifg=#ffff00
"  hi myType      guibg=#808000 guifg=#ffff00
  
  hi StatusLineNC guibg=Black guifg=#808080
  hi StatusLine guibg=Black guifg=#c0c0c0

  let html_no_rendering=1

  runtime macros/matchit.vim
  runtime ftplugin/man.vim

  set wildmenu
  set wildmode=list:longest

function! ConfigureC()
  set shiftwidth=3
  set tabstop=3
endfunction
autocmd BufNewFile,BufRead *.c,*.h call ConfigureC()

function! ConfigureMail()
  set ft=mail
  set shiftwidth=2
  set tabstop=2
  set textwidth=71
  normal }j
endfunction
autocmd BufNewFile,BufRead /tmp/mutt-* call ConfigureMail()

if &diff
    function! ConfigureDiff()
        if bufnr('%') == 1
            normal J
        endif
    endfunction
    autocmd VimEnter * :call ConfigureDiff()
endif

au BufNewFile,BufRead *.tt2  setf html
au BufNewFile,BufRead pipeline.conf  setf perl
"set mouse=a

map t" viwbi"ea"
map t{ viwbi{ea}
map t( viwbi(ea)
map t[ viwbi[ea]

function! ConfigureTabXML()
  set shiftwidth=2
  set tabstop=2
  set softtabstop=2
endfunction

au BufNewFile,BufRead *.tt2,*.html,*.php,*.xml call ConfigureTabXML()
filetype plugin on

function! ConfigureJavaScript()
  set shiftwidth=4
  set tabstop=4
  set softtabstop=4
endfunction

au BufNewFile,BufRead *.js,*.css call ConfigureJavaScript()

function! ConfigureLisp()
    set shiftwidth=1
endfunction

au BufNewFile,BufRead *.lisp,*.lsp call ConfigureLisp()

map ,sp :call SchemaP()<CR>

function SchemaP()
perl << EOF
    my ($row) = $curwin->Cursor;
    my ($contents) = $curbuf->Get($row);

    my ($class) = $contents =~ /(GSC::\w+)->/;
    my $foo = `schema -p-no-class -c ^$class\$`;
    
    $curbuf->Append($row, $foo);

EOF
endfunction

"set list listchars=trail:_
set list
set lcs=tab:__,trail:.
set pastetoggle=<F11>

let g:LargeFile=80

function! DoDot() range
    let s:lines = getline(a:firstline, a:lastline)
    call writefile(s:lines, "/tmp/tmpdot.dot")
    call system("dot -Tjpg -o /tmp/tmpdot.jpg /tmp/tmpdot.dot")
    call system("sleep 1")
    call system("firefox /tmp/tmpdot.jpg")
    call system("sleep 1")
    call system("rm /tmp/tmpdot.*")
    unlet s:lines
endfunction
map ,dd va{V:call DoDot()<CR>

let g:proj_flags="msSt"

function! ToggleSpellCheck()
    if &spell == 1
        setlocal nospell
    else
        setlocal spell
    endif
endfunction
nmap <C-K> :call ToggleSpellCheck()<CR>

function AlignBlock() range
    if col(".") > 1
        echo "You can only align in Visual Mode"
        return
    endif
    let l:lines = getline(a:firstline, a:lastline)
    let l:lineNumber = a:firstline
    let l:column = col("'<")
    for l:line in l:lines
        if l:column > 1
            let l:lastSpaceColumn = strridx(l:line[0:l:column-1], " ")
            if l:lastSpaceColumn > -1 && l:lastSpaceColumn < l:column-1
                let l:index = l:lastSpaceColumn
                while l:index < l:column-1
                    let l:line = l:line[0:l:lastSpaceColumn] . ' ' . l:line[l:lastSpaceColumn + 1:len(l:line)]
                    let l:index = l:index + 1
                endwhile
            endif
        endif
        let l:newline = substitute(line, "\\(.\\{" . (l:column - 1) . "\\}\\)\\s*", "\\1", "")
        call setline(l:lineNumber, l:newline)
        let l:lineNumber = l:lineNumber + 1
    endfor
    call cursor(line("."), l:column)
endfunction

vmap \a :call AlignBlock()<CR>

function! PerlTidyAll()
    exe "%!perltidy"
endfunction
function! PerlTidyRange() range
    exe a:firstline . "," . a:lastline . "!perltidy"
endfunction
nmap <C-P> :call PerlTidyAll()<CR>
vmap <C-P> :call PerlTidyRange()<CR>

nmap <C-j><C-x> vggoG"ry:call Send_to_Screen(@r)<CR>

set ofu=syntaxcomplete#Complete
"nmap <F8> :w !diff -w -B -u -p % - >/tmp/%.diff<CR>:sp /tmp/%.diff<CR>

function DiffCurrent()
    let l:filename = bufname(".")
    execute "diffthis"
    execute "new"
    execute "r " . l:filename
    normal kdd
    execute "diffthis"
    normal 
endfunction

nmap <F8> :call DiffCurrent()<CR>

command! -nargs=? -range Align <line1>,<line2>call AlignSection('<args>')
vnoremap <Leader>a :Align 
function! AlignSection(regex) range
  let extra = 1
  let sep = empty(a:regex) ? '=' : a:regex
  let maxpos = 0
  let section = getline(a:firstline, a:lastline)
  for line in section
    let pos = match(line, ' *'.sep)
    if maxpos < pos
      let maxpos = pos
    endif
  endfor
  call map(section, 'AlignLine(v:val, sep, maxpos, extra)')
  call setline(a:firstline, section)
endfunction

function! AlignLine(line, sep, maxpos, extra)
  let m = matchlist(a:line, '\(.\{-}\) \{-}\('.a:sep.'.*\)')
  if empty(m)
    return a:line
  endif
  let spaces = repeat(' ', a:maxpos - strlen(m[1]) + a:extra)
  return m[1] . spaces . m[2]
endfunction

set foldlevel=100000

" Set macros
function FToggleComment()
   let fToggleCommentString = getline(".")
   if b:current_syntax == "cpp" || b:current_syntax == "java"
      if (match(fToggleCommentString, "^\\s*\/\/ ") == -1)
         let fToggleCommentString = substitute(fToggleCommentString, "^\\(\\s*\\)\\([^ ]\\)", "\\1\/\/ \\2", "")
      else
         let fToggleCommentString = substitute(fToggleCommentString, "^\\(\\s*\\)\/\/ ", "\\1", "")
      endif
   endif
   if b:current_syntax == "perl" || b:current_syntax == "rbm"
      if (match(fToggleCommentString, "^\\s*\# ") == -1)
         let fToggleCommentString = substitute(fToggleCommentString, "^\\(\\s*\\)\\([^ ]\\)", "\\1\# \\2", "")
      else
         let fToggleCommentString = substitute(fToggleCommentString, "^\\(\\s*\\)\# ", "\\1", "")
      endif
   endif
   if b:current_syntax == "lisp"
      if (match(fToggleCommentString, "^; ") == -1)
         let fToggleCommentString = substitute(fToggleCommentString, "^", "; ", "")
      else
         let fToggleCommentString = substitute(fToggleCommentString, "^; ", "", "")
      endif
   endif
   if b:current_syntax == "erlang"
      if (match(fToggleCommentString, "^\\s*\% ") == -1)
         let fToggleCommentString = substitute(fToggleCommentString, "^\\(\\s*\\)\\([^ ]\\)", "\\1\% \\2", "")
      else
         let fToggleCommentString = substitute(fToggleCommentString, "^\\(\\s*\\)\% ", "\\1", "")
      endif
   endif
   call setline(line("."), fToggleCommentString)
   unlet fToggleCommentString
endfunction

map  :call FToggleComment()
vmap  :call FToggleComment()

function HandleLimsEnv()
  let s:line1 = getline(1)
  if s:line1 =~ "^#!"
    " A script that starts with "#!".

    " Check for a line like "#!/usr/bin/lims-env VAR=val bash".  Turn it into
    " "#!/usr/bin/bash" to make matching easier.
    if s:line1 =~ '^#!\s*\S*\<lims-env\s'
      let s:line1 = substitute(s:line1, '\S\+=\S\+', '', 'g')
      let s:line1 = substitute(s:line1, '\<lims-env\s\+', '', '')
    endif

    " Get the program name.
    " Only accept spaces in PC style paths: "#!c:/program files/perl [args]".
    " If the word env is used, use the first word after the space:
    " "#!/usr/bin/env perl [path/args]"
    " If there is no path use the first word: "#!perl [path/args]".
    " Otherwise get the last word after a slash: "#!/usr/bin/perl [path/args]".
    if s:line1 =~ '^#!\s*\a:[/\\]'
      let s:name = substitute(s:line1, '^#!.*[/\\]\(\i\+\).*', '\1', '')
    elseif s:line1 =~ '^#!.*\<env\>'
      let s:name = substitute(s:line1, '^#!.*\<env\>\s\+\(\i\+\).*', '\1', '')
    elseif s:line1 =~ '^#!\s*[^/\\ ]*\>\([^/\\]\|$\)'
      let s:name = substitute(s:line1, '^#!\s*\([^/\\ ]*\>\).*', '\1', '')
    else
      let s:name = substitute(s:line1, '^#!\s*\S*[/\\]\(\i\+\).*', '\1', '')
    endif

    if s:name =~ 'perl'
      set ft=perl
    endif
  endif
endfunction

function HandleLimsEnvE()
  if getline(1) =~ '^#!\s*\S*\<lims-env\s\+perl'
    set ft=perl
  endif
endfunction

au BufRead * call HandleLimsEnvE()
