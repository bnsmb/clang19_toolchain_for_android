[ "$PS1" = "\\s-\\v\\\$ " ] && PS1="[\u@\h \w]\\$ "
echo "$PS1" | grep "\[clang19" || export PS1="[clang19 toolchain] $PS1"

set -o emacs


