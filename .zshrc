export ZPLUG_HOME=/usr/local/opt/zplug
source $ZPLUG_HOME/init.zsh

# Load local bash/zsh compatible settings
INIT_SH_NOFUN=1
INIT_SH_NOLOG=1
DISABLE_Z_PLUGIN=1
[ -f "$HOME/.local/etc/init.sh" ] && source "$HOME/.local/etc/init.sh"

# exit for non-interactive shell
[[ $- != *i* ]] && return

# Setup dir stack
DIRSTACKSIZE=10
setopt autopushd pushdminus pushdsilent pushdtohome pushdignoredups cdablevars
alias d='dirs -v | head -10'

# Disable correction
unsetopt correct_all
unsetopt correct
DISABLE_CORRECTION="true"

# Enable 256 color to make auto-suggestions look nice
export TERM="xterm-256color"

ZSH_AUTOSUGGEST_USE_ASYNC=1

# Declare modules
zstyle ':prezto:*:*' color 'yes'
zstyle ':prezto:module:editor' key-bindings 'emacs'
zstyle ':prezto:module:git:alias' skip 'yes'
zstyle ':prezto:module:prompt' theme 'redhat'
zstyle ':prezto:module:prompt' pwd-length 'short'
zstyle ':prezto:module:terminal' auto-title 'yes'
zstyle ':prezto:module:autosuggestions' color 'yes'
zstyle ':prezto:module:python' autovenv 'yes'
zstyle ':prezto:load' pmodule \
	'environment' \
	'editor' \
	'history' \
	'git' \
	'utility' \
	'completion' \
	'history-substring-search' \
	'autosuggestions' \
	'prompt' \
    
# Initialize prezto
# antigen use prezto

# default bundles
zplug Vifon/deer
zplug zdharma/fast-syntax-highlighting, defer:2
# zplug "plugins/git", from:prezto
# zplug "modules/prompt", from:prezto
zplug zsh-users/zsh-autosuggestions, defer:2
# zplug "modules/fzf", from:prezto

# check login shell
if [[ -o login ]]; then
	[ -f "$HOME/.local/etc/login.sh" ] && source "$HOME/.local/etc/login.sh"
	[ -f "$HOME/.local/etc/login.zsh" ] && source "$HOME/.local/etc/login.zsh"
fi

# syntax color definition
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

typeset -A ZSH_HIGHLIGHT_STYLES

ZSH_HIGHLIGHT_STYLES[command]=fg=white,bold
ZSH_HIGHLIGHT_STYLES[alias]='fg=magenta,bold'

ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=009
ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=009,standout
ZSH_HIGHLIGHT_STYLES[alias]=fg=cyan,bold
ZSH_HIGHLIGHT_STYLES[builtin]=fg=cyan,bold
ZSH_HIGHLIGHT_STYLES[function]=fg=cyan,bold
ZSH_HIGHLIGHT_STYLES[command]=fg=white,bold
ZSH_HIGHLIGHT_STYLES[precommand]=fg=white,underline
ZSH_HIGHLIGHT_STYLES[commandseparator]=none
ZSH_HIGHLIGHT_STYLES[hashed-command]=fg=009
ZSH_HIGHLIGHT_STYLES[path]=fg=214,underline
ZSH_HIGHLIGHT_STYLES[globbing]=fg=063
ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=white,underline
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=none
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=none
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=063
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=063
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=009
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=009
ZSH_HIGHLIGHT_STYLES[assign]=none

# load local config
[ -f "$HOME/.local/etc/config.zsh" ] && source "$HOME/.local/etc/config.zsh"
[ -f "$HOME/.local/etc/local.zsh" ] && source "$HOME/.local/etc/local.zsh"

zplug load # --verbose

# options
unsetopt correct_all
unsetopt share_history
setopt prompt_subst
unsetopt prompt_cr prompt_sp

setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
# setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY # Don't execute immediately upon history expansion.

# setup for deer
autoload -U deer
zle -N deer
# default keymap
bindkey -s '\ee' 'vim\n'
bindkey '\eh' backward-char
bindkey '\el' forward-char
bindkey '\ej' down-line-or-history
bindkey '\ek' up-line-or-history
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


# source function.sh if it exists
[ -f "$HOME/.local/etc/function.sh" ] && . "$HOME/.local/etc/function.sh"

# Disable correction
unsetopt correct_all
unsetopt correct
DISABLE_CORRECTION="true"

# completion detail
zstyle ':completion:*:complete:-command-:*:*' ignored-patterns '*.pdf|*.exe|*.dll'
zstyle ':completion:*:*sh:*:' tag-order files


[[ -s "/Users/ming.chen/.gvm/scripts/gvm" ]] && source "/Users/ming.chen/.gvm/scripts/gvm"


if [[ `uname` == "darwin" ]] || [[ `uname` == "Darwin" ]]; then
	export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/bottles
fi

eval "$(zoxide init zsh)"

# not use default c-r or up key bindings
export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"
bindkey '^r' _atuin_search_widget

export CARGO_HTTP_MULTIPLEXING=false
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--layout=reverse --inline-info"

function vf {
	IFS=$'\n' files=($(fzf --query="$1" --multi --select-1 --exit-0 --prompt 'files:' ))
	[[ -n "$files" ]] && ${EDITOR} "${files[@]}"
}

export FZF_COMPLETION_TRIGGER='~~'

export VISUAL=nvim
export EDITOR=nvim
export LANG=zh_CN.UTF-8
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup


# export STARSHIP_CONFIG="~/.config/starship/starship.toml"
eval "$(starship init zsh)"

export GO111MODULE=on
alias taw="tmux attach -t working"
alias tas="tmux new -s working"
alias vim=nvim
alias cat=bat
alias ll="exa -al"

export DFT_BYTE_LIMIT=500000
export DFT_GRAPH_LIMIT=30000

function wk {
    if [[ -n "$TMUX" ]]
    then
        return 0
    fi
    tmux ls -F '#{session_name}' |
    fzf --bind=enter:replace-query+print-query |
    read session && tmux attach -t ${session:-default} || tmux new -s ${session:-default}
}

. "$HOME/.cargo/env"
export LC_CTYPE=en_US.UTF-8
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:en_US
export TERM="xterm-256color"


if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

SOCKS="socks5://127.0.0.1:1080"
alias proxy="export http_proxy=${SOCKS} https_proxy=${SOCKS} all_proxy=${SOCKS}"
alias unproxy='unset all_proxy http_proxy https_proxy'

export GOPATH=~/go
export PATH=$HOME/.local/bin:$GOPATH/bin:/usr/local/bin:$PATH
alias nmr='cd $HOME/work/notes/ && python3 Script/query_text.py --query_text "$@" ' 
autoload -U compinit
compinit -i
