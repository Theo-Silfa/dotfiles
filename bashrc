# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

# bash-completion
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi

# fzf key bindings (Ctrl-R, Ctrl-T, Alt-C) and fuzzy completion
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi
