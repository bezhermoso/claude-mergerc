#!/usr/bin/env zsh
# See functions/claude-mergerc
#
# Check if ./functions is in fpath, if not, add it
if [[ ${zsh_loaded_plugins[-1]} != */kalc && -z ${fpath[(r)${0:h}/functions]} ]]; then
    fpath+=( "${0:h}/functions" )
fi

autoload claude-mergerc
