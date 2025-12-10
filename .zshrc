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
# Optimized completions loading - only run compinit once per day
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C  # 跳过安全检查，直接用缓存
fi


zinit wait'0a' lucid atload'zinit cdreplay -q' for zdharma-continuum/null


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
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
else
    eval "$(fzf --zsh)"
fi

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
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git 2>/dev/null || find . -type f 2>/dev/null | grep -v '\.git' || echo ''"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

function vf {
	IFS=$'\n' files=($(fzf --query="$1" --multi --select-1 --exit-0 --prompt 'files:' ))
    echo $files
	[[ -n "$files" ]] && ${EDITOR} "${files[@]}"
}

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

# asdf shims path (required for asdf 0.18+)
# # asdf shims path (required for asdf 0.18+)
if [[ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi
if [[ -f "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/golang/set-env.zsh" ]]; then
  . "${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/golang/set-env.zsh"
fi

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
. ${ASDF_DATA_DIR:-$HOME/.asdf}/plugins/golang/set-env.zsh

export ATUIN_NOBIND="true"
eval "$(atuin init zsh)"
bindkey '^r' _atuin_search_widget

[[ -f ~/.secrets ]] && source ~/.secrets

[[ -f ~/.local/bin/z.lua/z.lua ]] && eval "$(lua ~/.local/bin/z.lua/z.lua --init zsh enhanced once echo fzf)"
# Enable keybindings only for non-dumb terminals
# Ghostty/Tmux may set TERM=dumb which disables escape sequences
# 终端键绑定配置（仅在非 dumb 终端下生效）
if [[ "$TERM" != "dumb" ]]; then
    # Alt+j: 跳转到行首
    bindkey '\ej' beginning-of-line
    # Alt+k: 跳转到行尾
    bindkey '\ek' end-of-line
    # Alt+e: 执行 vim 命令
    bindkey -s '\ee' 'vim\n'
    # Alt+h: 光标左移一个字符
    bindkey '\eh' backward-char
    # Alt+l: 光标右移一个字符
    bindkey '\el' forward-char
    # Alt+Shift+h: 光标左移一个单词
    bindkey '\eH' backward-word
    # Alt+Shift+l: 光标右移一个单词
    bindkey '\eL' forward-word
    # Alt+j: 跳转到行首（重复绑定）
    bindkey '\ej' beginning-of-line
    # Alt+Shift+k: 跳转到行尾
    bindkey '\eK' end-of-line

    # Alt+o: 返回上级目录
    bindkey -s '\eo' 'cd ..\n'
    # Alt+;: 执行 ll 命令（列出文件详情）
    bindkey -s '\e;' 'll\n'

    # Alt+左箭头: 光标左移一个单词
    bindkey '\e[1;3D' backward-word
    # Alt+右箭头: 光标右移一个单词
    bindkey '\e[1;3C' forward-word
    # Alt+上箭头: 跳转到行首
    bindkey '\e[1;3A' beginning-of-line
    # Alt+下箭头: 跳转到行尾
    bindkey '\e[1;3B' end-of-line

    # Alt+v: 启动 deer 文件管理器
    bindkey '\ev' deer
    # Alt+u: 启动 ranger 文件管理器
    bindkey -s '\eu' 'ranger_cd\n'
    # F4 (某些终端): 执行 vim 命令（带空格待输入文件名）
    bindkey -s '\eOS' 'vim '
fi

