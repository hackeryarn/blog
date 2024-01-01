.PHONY: init
init:
	git submodule update --recursive --remote

.PHONY: deploy
deploy:
	./script/deploy

.PHONY: server
server:
	./script/server
