#!/usr/bin/env bash
# Provisions an Arch box for testing fresh
function __provision() {
	# bring arch up-to-date and install fish
	sudo pacman-db-upgrade
	sudo pacman --noconfirm --noprogressbar --sync --sysupgrade --refresh --quiet fish
	# make fish the default shell
	sudo chsh -s /usr/bin/fish "$USER"
	# install fresh from flasheater repo
	FRESH_REPO='https://github.com/flasheater/fresh' /vagrant/install.sh
	# source fresh output into fish init script
	mkdir -p ~/.config/fish
	echo 'source ~/.fresh/build/shell.sh' >> ~/.config/fish/config.fish
}
__provision "$@"
