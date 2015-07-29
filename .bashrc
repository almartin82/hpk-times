export EDITOR=/usr/bin/vim
export VISUAL=/usr/bin/vim
export LESS="-eiMXR"
export PAGER="less"
export PATH=${PATH}:${HOME}/bin


# GET EMACS TO WORK because we're running with basic vi
export EMACS_DIR=/app/.apt/usr/share/emacs/24.3
export EMACSDATA=/app/.apt/usr/share/emacs/24.3/etc
export EMACSLOADPATH=/app/.apt/usr/share/emacs/24.3/lisp/


# set prompt
if [[ ${SSH_CLIENT} ]] ; then
	PS1="\[\e[1;36m\][\u@\h]\[\e[m\]:\[\e[0;31m\]\w\[\e[m\e[1;37m\] >> \[\e[m\]"
else
	PS1="\[\e[1;36m\][\u]\[\e[m\]:\[\e[0;31m\]\w\[\e[m\e[1;37m\] >> \[\e[m\]"
fi

if [[ `uname` == "Linux" ]]
then
    alias ls="ls --color=auto -F"
else
    alias ls="ls -F"
fi

# set the line editor mode to be like emacs (ie. not stupid)
set -o emacs

# standard aliases
# bash shell and unix aliases
alias vim="vim.basic"
alias c='clear'
alias l='ls -1AF' #with classifiers
alias ll='ls -l' #details
alias lall='ls -la'
alias ldir="ls -AF1 | grep '\$'" #directories
alias lt='ls -Alt' #mod time
alias lsize='ls -A1sSrh' #by size

alias more='less'
alias g="grep --color=auto -E --exclude='*.svn*' --exclude='*.git' --exclude='*~' --exclude='\.*'"
alias gq="g -lr"

alias resource="source ~/.bash_profile"
alias ack="ack-grep"

if [[ -d ~/lib/xdiff ]] 
then
        alias dx='diff -wrt -I "^#" -X ~/lib/xdiff.regexp' 
        alias dq='diff -wqrt -I "^#" -X ~/lib/xdiff.regexp' 
else
        alias dx='diff -wrt -I "^#"'
        alias dq='diff -wqrt -I "^#"' 
fi

# source the alias file too - this is not distributed and can be 
# specfic to the workstation
if [ -f "$HOME/.bash_alias" ]; then
    . "$HOME/.bash_alias"
fi

