alias bf='butterfish shell --model="@preset/sonar" --autosuggest-model="@preset/groq-kimi" -z 600000 -u "https://openrouter.ai/api/v1"'

# alias ask='butterfish prompt --model="@preset/sonar" -z 600000'
ask() {
  local input tmp editor
  editor="${VISUAL:-${EDITOR:-vi}}"

  if [ "$#" -gt 0 ]; then
    # args mode
    input="$*"
  elif [ ! -t 0 ]; then
    # piped stdin mode
    input="$(cat)"
  else
    # editor mode
    tmp="$(mktemp "${TMPDIR:-/tmp}/ask.XXXXXX")" || return 1
    "$editor" "$tmp" || { rm -f "$tmp"; return 1; }
    input="$(cat "$tmp")"
    rm -f "$tmp"
  fi

  # no-op on empty input
  [ -n "$input" ] || return 0

  butterfish prompt --model="@preset/sonar" -z 600000 "$input" -u "https://openrouter.ai/api/v1"
}

alias tss='sudo -k tailscale switch'
complete -W "eshaanissar@outlook.com eshaan@dttlc.com" tss

# Create a wrapper function
edit_clean() {
    # Bash uses FCEDIT to determine which editor 'fc' (fix command) uses
    FCEDIT="nvim --noplugin" fc
}

# Bind Ctrl-x Ctrl-v to call that function
# Note: '\C-x\C-v' is the syntax for the key sequence
bind -x '"\C-x\C-v": edit_clean'
bind -x '"\C-x,": "$EDITOR ~/.bashrc"'


export PATH="$HOME/dbx-bin/:$PATH"
alias scb='xclip -selection clipboard'
