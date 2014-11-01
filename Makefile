.PHONY: test install

test:
	bundle exec rspec --format=doc --color

install:
	./install.sh
