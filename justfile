# Freeside Workspace Master Orchestrator
set dotenv-load := false

# Import sub-modules
mod bootstrap 'bootstrap/justfile'
mod sys 'just/sys.just'
mod git 'just/git.just'
mod straylight 'just/straylight.just'
mod pkg 'just/pkg.just'

# Global entry points and backward-compatible aliases
alias setup := sys::setup
alias clean := sys::clean
alias build-sandbox := sys::build-sandbox
alias build-straylight := straylight::build
alias build-package := pkg::build
alias build-package-group := pkg::build-group

# Standard convenience wrappers
alias status := git::status
alias diff := git::diff
alias build := pkg::build
