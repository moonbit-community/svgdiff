# Shell Completions

Install completion for the shell you use:

```sh
sh scripts/install-completions.sh bash
sh scripts/install-completions.sh zsh
sh scripts/install-completions.sh fish
```

The defaults are `~/.local/share/bash-completion/completions/svgdiff`, `~/.zfunc/_svgdiff`, and `~/.config/fish/completions/svgdiff.fish`. Use `--dest DIR` for a shell or package-manager-specific location. Bash and Fish discover their conventional user directories through their completion frameworks. For Zsh, add the directory before `compinit` when it is not already in `fpath`:

```zsh
fpath=(~/.zfunc $fpath)
autoload -Uz compinit && compinit
```

The definitions complete both SVG operands, the explicit stdin marker, output paths, and every current long option. `scripts/test-completions.sh` checks option synchronization against executable `--help`, available shell parsers, Bash behavior, and deterministic installation.
