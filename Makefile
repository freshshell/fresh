.PHONY: test install

test:
	./test/fresh_test.sh
	bundle exec rspec --format=doc

install:
	./install.sh
