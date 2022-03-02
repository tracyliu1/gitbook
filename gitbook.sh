#!/bin/bash

gitbook build

if [ $? -eq 0 ]; then
    echo "gitbook build succeed"

	currentTime=`date "+%Y-%m-%d %H:%M:%S"`

	if [ $? -eq 0 ]; then
	book sm	
	echo "build SUMMARY succeed"

	fi

	if [ $? -eq 0 ]; then
    		echo "succeed"
		
		cp -r _book/* docs 		
		
		git add README.md
		git add SUMMARY.md		
		git add docs
		git commit -m  "update_my_note  $currentTime" 
		git push origin gh-pages:gh-pages
		echo "push to GitHub"
	fi

else
    echo "failed"
fi
