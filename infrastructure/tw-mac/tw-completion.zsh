#compdef tw
# Zsh completion for tw (tw-control.sh)

_tw() {
  local -a commands
  commands=(
    'status:Show TW Mac status'
    'connect:Establish persistent SSH connection'
    'disconnect:Close persistent SSH connection'
    'start-mcp:Start Desktop Commander MCP server'
    'stop-mcp:Stop Desktop Commander MCP server'
    'shell:Open interactive shell'
    'tmux:Attach to tmux session'
    'run:Run command on TW Mac'
  )

  if (( CURRENT == 2 )); then
    _describe -t commands 'tw command' commands
  elif (( CURRENT > 2 )); then
    case $words[2] in
      run)
        _normal
        ;;
    esac
  fi
}

_tw "$@"
