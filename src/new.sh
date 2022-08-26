#!/bin/sh

. $source'/script'

[[ $a =~ 'a' ]] && exit 0

echo 'YOYOYO'

exit 1