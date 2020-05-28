.PHONY: test install

test:
	bundle exec rspec --format=doc

install:
	./install.sh
