_svgdiff() {
  local current previous options
  COMPREPLY=()
  current=${COMP_WORDS[COMP_CWORD]}
  previous=${COMP_WORDS[COMP_CWORD-1]:-}
  options='--width --height --perceptual-background --flip-pixels-per-degree --flip-error-threshold --before-resource --after-resource --output --html --agent-json --help --version'

  case "$previous" in
    --width|--height|--perceptual-background|--flip-pixels-per-degree|--flip-error-threshold)
      return
      ;;
    --output|--html)
      COMPREPLY=($(compgen -f -- "$current"))
      return
      ;;
    --before-resource|--after-resource)
      return
      ;;
  esac

  if (( COMP_CWORD >= 2 )) &&
    [[ "${COMP_WORDS[COMP_CWORD-2]}" == "--before-resource" ||
       "${COMP_WORDS[COMP_CWORD-2]}" == "--after-resource" ]]; then
    COMPREPLY=($(compgen -W 'image/png image/jpeg' -- "$current"))
    return
  fi
  if (( COMP_CWORD >= 3 )) &&
    [[ "${COMP_WORDS[COMP_CWORD-3]}" == "--before-resource" ||
       "${COMP_WORDS[COMP_CWORD-3]}" == "--after-resource" ]]; then
    COMPREPLY=($(compgen -f -- "$current"))
    return
  fi

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
