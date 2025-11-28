# exit for non-interactive shell
# Because `.zshrc` is typically only executed in interactive shells,
# non-interactive shells (such as script execution) do not need to load these configurations.
[[ $- != *i* ]] && return

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # If you're using macOS, you'll want this enabled
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi



# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

bindkey -s '\ee' 'vim\n'
bindkey '\eh' backward-char
bindkey '\el' forward-char
bindkey '\eH' backward-word
bindkey '\eL' forward-word
bindkey '\eJ' beginning-of-line
bindkey '\eK' end-of-line

bindkey -s '\eo' 'cd ..\n'
bindkey -s '\e;' 'll\n'

bindkey '\e[1;3D' backward-word
bindkey '\e[1;3C' forward-word
bindkey '\e[1;3A' beginning-of-line
bindkey '\e[1;3B' end-of-line

bindkey '\ev' deer
bindkey -s '\eu' 'ranger_cd\n'
bindkey -s '\eOS' 'vim '

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in zsh plugins with optimized loading
# Delay syntax highlighting for better performance
zinit wait lucid for \
    zsh-users/zsh-syntax-highlighting \
    zsh-users/zsh-autosuggestions

# Load completions immediately but with deferred initialization
zinit ice blockf lucid
zinit light zsh-users/zsh-completions

# fzf-tab with deferred loading
zinit ice wait lucid
zinit light Aloxaf/fzf-tab

# Add in snippets - async loading
zinit wait lucid for \
    OMZL::git.zsh \
    OMZP::git \
    OMZP::sudo \
    OMZP::command-not-found

#
# Optimized completions loading - only run compinit if needed
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zinit cdreplay -q


# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
# Disable fzf-tab for vf command
zstyle ':fzf-tab:complete:vf:*' disabled-on any

# Aliases
alias ls='ls --color'
alias vim='nvim'
alias c='clear'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"


function wk {
    if [[ -n "$TMUX" ]]
    then
        return 0
    fi
    tmux ls -F '#{session_name}' |
    fzf --bind=enter:replace-query+print-query |
    read session && tmux attach -t ${session:-default} || tmux new -s ${session:-default}
}

eval "$(starship init zsh)"
alias taw="tmux attach -t working"
alias tas="tmux new -s working"
alias v=nvim
alias cat=bat
alias ll="exa -al"

export FZF_COMPLETION_TRIGGER='~~'

function vf {
	IFS=$'\n' files=($(fzf --query="$1" --multi --select-1 --exit-0 --prompt 'files:' ))
    echo $files
	[[ -n "$files" ]] && ${EDITOR} "${files[@]}"
}

bindkey -s '\eo' 'cd ..\n'

export LC_CTYPE=en_US.UTF-8
export LANG=en_US.UTF-8
export TERM="xterm-256color"
export VISUAL=nvim
export EDITOR=nvim
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export PATH="$HOME/.local/bin:$PATH"


zinit ice depth=1
# if set, atuin not working
# zinit light jeffreytse/zsh-vi-mode

export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"
bindkey '^r' _atuin_search_widget

[[ -f ~/.secrets ]] && source ~/.secrets
