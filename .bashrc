alias bf='butterfish shell --model="@preset/sonar" --autosuggest-model="@preset/groq-kimi" -z 600000'

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

  butterfish prompt --model="@preset/sonar" -z 600000 "$input"
}
