# This is a template file that adds the most basic top level completions.
# It is used during installation of completions via the CLI.
#
# Any invalid syntax will be replaced with valid ZSH code
# during the installation process.

function _cani {
  local line

  _arguments -C "1: :({{commands}})" \
                "*::arg:->args"

  case $line[1] in
    show)
      _arguments -C "1: :({{names}})" \
                    "*::arg:->args"

      case $line[1] in
        {{versions}}
      esac
      ;;
    use)
      _arguments -C "1: :({{features}})"
      ;;
  esac
}

compdef _cani cani
