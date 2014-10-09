.PHONY: test install

test:
	./test/fresh_test.sh
	bundle exec rspec

install:
	./install.sh
