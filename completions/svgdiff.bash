_svgdiff() {
  local current previous options
  COMPREPLY=()
  current=${COMP_WORDS[COMP_CWORD]}
  previous=${COMP_WORDS[COMP_CWORD-1]:-}
  options='--width --height --max-checkpoints --perceptual-background --flip-pixels-per-degree --flip-error-threshold --before-resource --after-resource --output --html --summary --agent-json --agent-projection --help --version'

  case "$previous" in
    --width|--height|--max-checkpoints|--perceptual-background|--flip-pixels-per-degree|--flip-error-threshold)
      return
      ;;
    --output|--html|--summary)
      COMPREPLY=($(compgen -f -- "$current"))
      return
      ;;
    --before-resource|--after-resource)
      return
      ;;
  esac

  if [[ "$current" == --* ]]; then
    COMPREPLY=($(compgen -W "$options" -- "$current"))
  elif (( COMP_CWORD <= 2 )); then
    COMPREPLY=($(compgen -f -- "$current"))
    if [[ -z "$current" || "$current" == "-" ]]; then
      COMPREPLY+=("-")
    fi
  fi
}

complete -F _svgdiff svgdiff
