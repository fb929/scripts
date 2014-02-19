"" DO NOT EDIT
"" This file is under PUPPET control

" tabs
set paste
set tabstop=4

" navigation arrow
set nocp

" ignore registry
"set ic
" color find
set hls
" incremental search
set is

" default encode
set encoding=utf-8
" term encode (must coincide "encoding")
set termencoding=utf-8
" file encodings and sequence determination
set fileencodings=utf8,cp1251,koi8-r

" fix backspace in CentOS
set backspace=indent,eol,start

" ru map
map ё `
map й q
map ц w
map у e
map к r
map е t
map н y
map г u
map ш i
map щ o
map з p
map х [
map ъ ]
map ф a
map ы s
map в d
map а f
map п g
map р h
map о j
map л k
map д l
map ж ;
map э '
map я z
map ч x
map с c
map м v
map и b
map т n
map ь m
map б ,
map ю .
map Ё ~
map Й Q
map Ц W
map У E
map К R
map Е T
map Н Y
map Г U
map Ш I
map Щ O
map З P
map Х {
map Ъ }
map Ф A
map Ы S
map В D
map А F
map П G
map Р H
map О J
map Л K
map Д L
map Ж :
map Э "
map Я Z
map Ч X
map С C
map М V
map И B
map Т N
map Ь M
map Б <
map Ю >

"tabs
map <C-Left>	:tabprev<CR>
map <C-Right>	:tabnext<CR>
map <C-n>		:tabnew

""" HIGHLIGHT
" default syntax on
syntax on

" my highlight group
highlight ExtraWhitespace ctermbg=red guibg=red

" auto chmod
au BufWritePost * if getline(1) =~ "^#!.*/bin/"|silent !chmod a+x %

" highlight MySQL
if has("autocmd")
	autocmd BufRead *.sql set filetype=mysql
endif

" highlight config files
autocmd BufReadPost config set filetype=config

if version >= 714
	" highlight trailing spaces
	au BufNewFile,BufRead * let b:mtrailingws=matchadd('ErrorMsg', '\s\+$', -1)

	" highlight tabs between spaces
	au BufNewFile,BufRead * let b:mtabbeforesp=matchadd('ErrorMsg', '\v(\t+)\ze( +)', -1)
	au BufNewFile,BufRead * let b:mtabaftersp=matchadd('ErrorMsg', '\v( +)\zs(\t+)', -1)
	
	" highlight string longer than eighty symbol
	au BufWinEnter * let w:m1=matchadd('Search', '\%<81v.\%>77v', -1)
	au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>80v.\+', -1)
endif

" Show trailing whitespace:
match ExtraWhitespace /\s\+$/

" Show trailing whitepace and spaces before a tab:
match ExtraWhitespace /\s\+$\| \+\ze\t/

" Show tabs that are not at the start of a line:
match ExtraWhitespace /[^\t]\zs\t\+/

" Show spaces used for indenting (so you use only tabs for indenting).
match ExtraWhitespace /^\t*\zs \+/

" Save history changes
if version >= 730
	execute "silent! !install -d ~/.vim/undodir"
	set history=64
	set undolevels=128
	set undodir=~/.vim/undodir/
	set undofile
	set undolevels=1000
	set undoreload=10000
endif
