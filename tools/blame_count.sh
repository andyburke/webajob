#!/bin/sh

find . -type f -not -regex '.*\.svn.*' -exec svn blame {} \; 2>&1 | grep -v 'Skipping binary' | grep -v 'has no URL' | cut -c10-17 | sed -e 's/ burke/aburke/' | sort | uniq -c | sort -n
