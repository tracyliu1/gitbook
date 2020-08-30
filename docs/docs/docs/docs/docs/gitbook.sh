#!/bin/bash

gitbook build

if [ $? -eq 0 ]; then
    echo "gitbook build succeed"

	if [ $? -eq 0 ]; then
    		echo "succeed"
		cp -r _book/* docs/
		
		git add /docs
		git commit -m “update my note”
		git push origin gh-pages:gh-pages
		echo "push to GitHub"
	fi

else
    echo "failed"
fi
