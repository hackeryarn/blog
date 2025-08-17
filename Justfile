init:
	git submodule update --recursive --remote

deploy:
    ./script/deploy

serve:
    ./script/server    
