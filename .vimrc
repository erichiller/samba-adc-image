" Setting some decent VIM settings for programming

set showmatch                   " automatically show matching brackets. works like it does in bbedit.
set vb                          " turn on the "visual bell" - which is much quieter than the "audio blink"
set ruler                       " show the cursor position all the time
set laststatus=2                " make the last line (status) two lines deep so you can always see status
set backspace=indent,eol,start  " make that backspace key work the way it should
set nocompatible                " vi compatible is LAME
set background=dark             " Use colours that work well on a dark background (Console is usually black)
set showmode                    " show the current mode
syntax on                       " turn syntax highlighting on by default
set hlsearch                    " highlight search terms

" EDH ---- force tabs, not spaces ----
colorscheme desert              " good general purpose colorscheme
set autoindent                  " set auto-indenting on for programming; filetype plugin should
                                " override this for smartindent / cindent depending on filetype
                                " see: http://vim.wikia.com/wiki/Indenting_source_code
set noexpandtab
set tabstop=4                   " EDH - standard 4 space=tab
set shiftwidth=4                " Number of spaces to use for each step of (auto)indent.

filetype plugin indent on       " Enable file type detection. to automatically do language-dependent indenting.

set number                      " Show line numbers.
set history=150                 " keep 50 lines of command line history
set showcmd                     " display incomplete commands
set incsearch                   " do incremental searching


" Show EOL type and last modified timestamp, right after the filename
set statusline=%<%F%h%m%r\ %y\ (%{strftime(\"%H:%M\ %d/%m/%Y\",getftime(expand(\"%:p\")))})%=%l,%c%V\ %P

" Set up .md as markdown as well
au BufNewFile,BufFilePre,BufRead *.md set filetype=markdown


"------------------------------------------------------------------------------
" Only do this part when compiled with support for autocommands.
if has("autocmd")

    "Set UTF-8 as the default encoding for commit messages
    autocmd BufReadPre COMMIT_EDITMSG,git-rebase-todo setlocal fileencodings=utf-8

    "Remember the positions in files with some git-specific exceptions"
    autocmd BufReadPost *
      \ if line("'\"") > 0 && line("'\"") <= line("$")
      \           && expand("%") !~ "COMMIT_EDITMSG"
      \           && expand("%") !~ "ADD_EDIT.patch"
      \           && expand("%") !~ "addp-hunk-edit.diff"
      \           && expand("%") !~ "git-rebase-todo" |
      \   exe "normal g`\"" |
      \ endif

      autocmd BufNewFile,BufRead *.patch set filetype=diff
      autocmd BufNewFile,BufRead *.diff set filetype=diff

      autocmd Syntax diff
      \ highlight WhiteSpaceEOL ctermbg=red |
      \ match WhiteSpaceEOL /\(^+.*\)\@<=\s\+$/

      autocmd Syntax gitcommit setlocal textwidth=74
endif " has("autocmd")
