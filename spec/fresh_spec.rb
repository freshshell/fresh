require 'spec_helper'

describe 'fresh' do
  describe 'local shell files' do
    it 'builds' do
      rc 'fresh aliases/git'
      rc 'fresh aliases/ruby'

      file_add fresh_local_path + 'aliases/git', "alias gs='git status'"
      file_add fresh_local_path + 'aliases/git', "alias gl='git log'"
      file_add fresh_local_path + 'aliases/ruby', "alias rake='bundle exec rake'"

      run_fresh

      expect_shell_sh_to eq <<-EOF.strip_heredoc
        # fresh: aliases/git

        alias gs='git status'
        alias gl='git log'

        # fresh: aliases/ruby

        alias rake='bundle exec rake'
      EOF
    end

    it 'builds with spaces' do
      rc "fresh 'aliases/foo bar'"

      file_add fresh_local_path + 'aliases/foo bar', 'SPACE'
      file_add fresh_local_path + 'aliases/foo', 'foo'
      file_add fresh_local_path + 'aliases/bar', 'bar'

      run_fresh

      expect_shell_sh_to eq <<-EOF.strip_heredoc
        # fresh: aliases/foo bar

        SPACE
      EOF
    end

    it 'builds with globbing' do
      rc "fresh 'aliases/file*'"

      file_add fresh_local_path + 'aliases/file1', 'file1'
      file_add fresh_local_path + 'aliases/file2', 'file2'
      file_add fresh_local_path + 'aliases/other', 'other'

      run_fresh

      expect_shell_sh_to eq <<-EOF.strip_heredoc
        # fresh: aliases/file1

        file1

        # fresh: aliases/file2

        file2
      EOF
    end

    it 'creates empty output with no freshrc file' do
      expect(File).to_not exist(shell_sh_path)

      run_fresh

      expect(File).to exist(shell_sh_path)
      expect_shell_sh_to be_default
    end

    describe 'using --ignore-missing' do
      it 'builds' do
        rc 'fresh aliases/haskell --ignore-missing'
        FileUtils.mkdir_p fresh_local_path

        run_fresh

        expect_shell_sh_to be_default
      end

      it 'does not create a file when single source is missing' do
        rc <<-EOF.strip_heredoc
          fresh tmux.conf --file --ignore-missing
          fresh ghci --file --ignore-missing
        EOF
        touch fresh_local_path + 'tmux.conf'

        run_fresh

        expect(File).to exist fresh_path + 'build/tmux.conf'
        expect(File).to_not exist fresh_path + 'build/ghci'
      end
    end

    it 'errors with missing local file' do
      rc 'fresh foo'
      touch fresh_local_path + 'bar'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Could not find "foo" source file.
        #{freshrc_path}:1: fresh foo

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end

    it 'preserves existing compiled files when failing' do
      file_add shell_sh_path, 'existing shell.sh'

      rc 'invalid'
      run_fresh error: "#{freshrc_path}: line 1: invalid: command not found\n"

      expect(File.read(shell_sh_path)).to eq "existing shell.sh\n"
    end

    describe 'using --file' do
      it 'builds generic files' do
        rc <<-EOF.strip_heredoc
          fresh lib/tmux.conf --file
          fresh lib/pryrc.rb --file=~/.pryrc --marker
          fresh config/git/colors --file=~/.gitconfig
          fresh config/git/rebase --file=~/.gitconfig
          fresh config/\*.vim --file=~/.vimrc --marker=\\"
        EOF

        file_add fresh_local_path + 'lib/tmux.conf', <<-EOF.strip_heredoc
          unbind C-b
          set -g prefix C-a
        EOF
        file_add fresh_local_path + 'lib/pryrc.rb', <<-EOF.strip_heredoc
          Pry.config.color = true
          Pry.config.history.should_save = true
        EOF
        file_add fresh_local_path + 'config/git/colors', <<-EOF.strip_heredoc
          [color]
          ui = auto
        EOF
        file_add fresh_local_path + 'config/git/rebase', <<-EOF.strip_heredoc
          [rebase]
          autosquash = true
        EOF
        file_add fresh_local_path + 'config/mappings.vim', 'map Y y$'
        file_add fresh_local_path + 'config/global.vim', 'set hidden'

        run_fresh

        expect_shell_sh_to be_default

        expect(File.read(fresh_path + 'build/tmux.conf')).to eq <<-EOF.strip_heredoc
          unbind C-b
          set -g prefix C-a
        EOF
        expect(File.read(fresh_path + 'build/pryrc')).to eq <<-EOF.strip_heredoc
          # fresh: lib/pryrc.rb

          Pry.config.color = true
          Pry.config.history.should_save = true
        EOF
        expect(File.read(fresh_path + 'build/gitconfig')).to eq <<-EOF.strip_heredoc
          [color]
          ui = auto
          [rebase]
          autosquash = true
        EOF
        expect(File.read(fresh_path + 'build/vimrc')).to eq <<-EOF.strip_heredoc
          " fresh: config/global.vim

          set hidden

          " fresh: config/mappings.vim

          map Y y$
        EOF

        %w[shell.sh tmux.conf pryrc gitconfig vimrc].each do |path|
          path = File.join fresh_path, 'build', path
          expect(File).to exist(path)

          expect(File.executable? path).to be false
          expect(File.world_readable? path).to be nil
          expect(File.writable? path).to be false
        end
      end

      it 'builds generic files with globbing' do
        rc "fresh 'file*' --file"

        file_add fresh_local_path + 'file1', 'file1'
        file_add fresh_local_path + 'file2', 'file2'
        file_add fresh_local_path + 'other', 'other'

        run_fresh

        expect(File).to exist fresh_path + 'build/file1'
        expect(File).to exist fresh_path + 'build/file2'
        expect(File).to_not exist fresh_path + 'build/other'
      end

      it 'links generic files to destination' do
        rc <<-EOF.strip_heredoc
          fresh lib/tmux.conf --file
          fresh lib/pryrc.rb --file=~/.pryrc
          fresh .gitconfig --file
          fresh bclear.vim --file=~/.vim/colors/bclear.vim
          fresh "with spaces" --file="~/a path/with spaces"
        EOF
        %w[lib/tmux.conf lib/pryrc.rb .gitconfig bclear.vim with\ spaces].each do |path|
          touch fresh_local_path + path
        end

        run_fresh

        [
          %w[tmux.conf ~/.tmux.conf],
          %w[pryrc ~/.pryrc],
          %w[gitconfig ~/.gitconfig],
          %w[vim-colors-bclear.vim ~/.vim/colors/bclear.vim],
          %w[a-path-with-spaces ~/a\ path/with\ spaces],
        ].each do |build_file, symlink_destination|
          expect(File.join(fresh_path, 'build', build_file)).to eq File.readlink(File.expand_path(symlink_destination))
        end
      end

      it 'builds and links generic files with same basename' do
        rc <<-EOF.strip_heredoc
          fresh foo --file=~/.foo/file
          fresh bar --file=~/.bar/file
        EOF
        file_add fresh_local_path + 'foo', 'foo'
        file_add fresh_local_path + 'bar', 'bar'

        run_fresh

        expect(File.read(fresh_path + 'build/foo-file')).to eq "foo\n"
        expect(File.read(fresh_path + 'build/bar-file')).to eq "bar\n"
        [
          %w[foo-file ~/.foo/file],
          %w[bar-file ~/.bar/file],
        ].each do |build_file, symlink_destination|
          expect(File.join(fresh_path, 'build', build_file)).to eq File.readlink(File.expand_path(symlink_destination))
        end
      end

      it 'does not link generic files with relative paths' do
        rc 'fresh foo-bar.zsh --file=vendor/foo/bar.zsh'
        touch fresh_local_path + 'foo-bar.zsh'

        run_fresh

        expect(File).to exist fresh_path + 'build/vendor/foo/bar.zsh'
        expect(File.symlink?('vendor/foo/bar.zsh')).to eq false
      end

      it 'does not allow relative paths above build dir' do
        rc 'fresh foo-bar.zsh --file=../foo/bar.zsh'
        touch fresh_local_path + 'foo-bar.zsh'

        run_fresh error: <<-EOF.strip_heredoc
          #{ERROR_PREFIX} Relative paths must be inside build dir.
          #{freshrc_path}:1: fresh foo-bar.zsh --file=../foo/bar.zsh

          You may need to run `fresh update` if you're adding a new line,
          or the file you're referencing may have moved or been deleted.
        EOF
      end
    end
  end

  describe 'remote files' do
    describe 'cloning' do
      it 'clones GitHub repos' do
        rc 'fresh repo/name file'
        stub_git

        run_fresh

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{Dir.pwd}
          git clone https://github.com/repo/name #{sandbox_path}/fresh/source/repo/name
        EOF
        expect(
          File.read sandbox_path + 'fresh/source/repo/name/file'
        ).to eq "test data\n"
      end

      it 'clones other repos' do
        rc <<-EOF
          fresh git://example.com/one/two.git file
          fresh http://example.com/foo file
          fresh https://example.com/bar file
          fresh git@test.example.com:baz.git file
        EOF
        stub_git

        run_fresh

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{Dir.pwd}
          git clone git://example.com/one/two.git #{sandbox_path}/fresh/source/example.com/one-two
          cd #{Dir.pwd}
          git clone http://example.com/foo #{sandbox_path}/fresh/source/example.com/foo
          cd #{Dir.pwd}
          git clone https://example.com/bar #{sandbox_path}/fresh/source/example.com/bar
          cd #{Dir.pwd}
          git clone git@test.example.com:baz.git #{sandbox_path}/fresh/source/test.example.com/baz
        EOF
      end

      it 'clones github repos with full urls' do
        rc <<-EOF
          fresh git@github.com:ssh/test.git file
          fresh git://github.com/git/test.git file
          fresh http://github.com/http/test file
          fresh https://github.com/https/test file
        EOF
        stub_git

        run_fresh

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{Dir.pwd}
          git clone git@github.com:ssh/test.git #{sandbox_path}/fresh/source/ssh/test
          cd #{Dir.pwd}
          git clone git://github.com/git/test.git #{sandbox_path}/fresh/source/git/test
          cd #{Dir.pwd}
          git clone http://github.com/http/test #{sandbox_path}/fresh/source/http/test
          cd #{Dir.pwd}
          git clone https://github.com/https/test #{sandbox_path}/fresh/source/https/test
        EOF
      end

      it 'does not clone existing repos' do
        rc 'fresh repo/name file'
        touch fresh_path + 'source/repo/name/file'
        stub_git

        run_fresh

        expect(File).to_not exist git_log_path
      end
    end

    describe 'building shell files' do
      it 'builds shell files from cloned github repos' do
        rc 'fresh repo/name file'
        file_add fresh_path + 'source/repo/name/file', 'remote content'

        run_fresh

        expect_shell_sh_to eq <<-EOF.strip_heredoc
          # fresh: repo/name file

          remote content
        EOF
      end

      it 'builds shell files from cloned other repos' do
        rc 'fresh git://example.com/foobar.git file'
        file_add fresh_path + 'source/example.com/foobar/file', 'remote content'

        run_fresh

        expect_shell_sh_to eq <<-EOF.strip_heredoc
          # fresh: git://example.com/foobar.git file

          remote content
        EOF
      end
    end

    it 'warns if using a remote source that is your local dotfiles' do
      rc <<-EOF.strip_heredoc
        fresh repo/name file1
        fresh repo/name file2
      EOF
      FileUtils.mkdir_p fresh_local_path + '.git'
      FileUtils.mkdir_p fresh_path + 'source/repo/name/.git'
      [1, 2].each do |n|
        touch fresh_path + "source/repo/name/file#{n}"
      end
      stub_git

      run_fresh success: <<-EOF.strip_heredoc
        #{NOTE_PREFIX} You seem to be sourcing your local files remotely.
        #{freshrc_path}:1: fresh repo/name file1

        You can remove "repo/name" when sourcing from your local dotfiles repo (#{fresh_local_path}).
        Use \`fresh file\` instead of \`fresh repo/name file\`.

        To disable this warning, add \`FRESH_NO_LOCAL_CHECK=true\` in your freshrc file.

        #{FRESH_SUCCESS_LINE}
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_local_path}
        git rev-parse --abbrev-ref --symbolic-full-name @{u}
        cd #{fresh_local_path}
        git config --get remote.my-remote-name.url
      EOF
    end

    it 'does not fail if local dotfiles does not have a remote' do
      rc 'fresh repo/name file'
      FileUtils.mkdir_p fresh_path + 'source/repo/name/.git'
      touch fresh_path + 'source/repo/name/file'

      FileUtils.mkdir_p fresh_local_path
      silence(:stdout) do
        expect(system 'git', 'init', fresh_local_path.to_s).to be true
      end

      run_fresh
    end

    describe 'using --ref' do
      it 'builds' do
        rc <<-EOF.strip_heredoc
          fresh repo/name 'aliases/*' --ref=abc1237
          fresh repo/name ackrc --file --ref=1234567
          fresh repo/name sedmv --bin --ref=abcdefg
        EOF
        # test with only one of aliases/* existing at HEAD
        touch fresh_path + 'source/repo/name/aliases/git.sh'
        stub_git

        run_fresh

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{fresh_path + 'source/repo/name'}
          git show abc1237:aliases/.fresh-order
          cd #{fresh_path + 'source/repo/name'}
          git ls-tree -r --name-only abc1237
          cd #{fresh_path + 'source/repo/name'}
          git show abc1237:aliases/git.sh
          cd #{fresh_path + 'source/repo/name'}
          git show abc1237:aliases/ruby.sh
          cd #{fresh_path + 'source/repo/name'}
          git ls-tree -r --name-only 1234567
          cd #{fresh_path + 'source/repo/name'}
          git show 1234567:ackrc
          cd #{fresh_path + 'source/repo/name'}
          git ls-tree -r --name-only abcdefg
          cd #{fresh_path + 'source/repo/name'}
          git show abcdefg:sedmv
        EOF

        expect_shell_sh_to eq <<-EOF.strip_heredoc
          # fresh: repo/name aliases/git.sh @ abc1237

          test data for abc1237:aliases/git.sh

          # fresh: repo/name aliases/ruby.sh @ abc1237

          test data for abc1237:aliases/ruby.sh
        EOF

        expect(File.read(fresh_path + 'build/ackrc')).
          to eq "test data for 1234567:ackrc\n"
        expect(File.read(fresh_path + 'build/bin/sedmv')).
          to eq "test data for abcdefg:sedmv\n"
      end

      it 'errors if source file missing at ref' do
        rc 'fresh repo/name bad-file --ref=abc1237'
        FileUtils.mkdir_p fresh_path + 'source/repo/name'
        stub_git

        run_fresh error: <<-EOF.strip_heredoc
          #{ERROR_PREFIX} Could not find "bad-file" source file.
          #{freshrc_path}:1: fresh repo/name bad-file --ref=abc1237

          You may need to run `fresh update` if you're adding a new line,
          or the file you're referencing may have moved or been deleted.
          Have a look at the repo: <#{format_url 'https://github.com/repo/name'}>
        EOF

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{fresh_path}/source/repo/name
          git ls-tree -r --name-only abc1237
        EOF
      end

      context 'with --ignore-missing' do
        it 'does not error if source file missing at ref with --ignore-missing' do
          rc 'fresh repo/name bad-file --ref=abc1237 --ignore-missing'
          FileUtils.mkdir_p fresh_path + 'source/repo/name'
          stub_git

          run_fresh

          expect(git_log).to eq <<-EOF.strip_heredoc
            cd #{fresh_path}/source/repo/name
            git ls-tree -r --name-only abc1237
          EOF
        end

        it 'builds files with ref and ignore missing' do
          rc <<-EOF.strip_heredoc
            fresh repo/name ackrc --file --ref=abc1237 --ignore-missing
            fresh repo/name missing --file --ref=abc1237 --ignore-missing
          EOF
          FileUtils.mkdir_p fresh_path + 'source/repo/name'
          stub_git

          run_fresh

          expect(git_log).to eq <<-EOF.strip_heredoc
            cd #{fresh_path + 'source/repo/name'}
            git ls-tree -r --name-only abc1237
            cd #{fresh_path + 'source/repo/name'}
            git show abc1237:ackrc
            cd #{fresh_path + 'source/repo/name'}
            git ls-tree -r --name-only abc1237
          EOF
          expect(File).to exist fresh_path + 'build/ackrc'
          expect(File).to_not exist fresh_path + 'missing'
        end
      end
    end
  end

  describe 'ignoring subdirectories when globbing' do
    it 'from working tree' do
      rc "fresh 'recursive-test/*'"
      %w[abc/def foo bar].each do |path|
        touch [fresh_local_path, 'recursive-test', path]
      end

      run_fresh

      expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
        # fresh: recursive-test/bar
        # fresh: recursive-test/foo
      EOF
    end

    it 'with ref' do
      rc "fresh repo/name 'recursive-test/*' --ref=abc1237"
      stub_git

      run_fresh

      expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
          # fresh: repo/name recursive-test/bar @ abc1237
          # fresh: repo/name recursive-test/foo @ abc1237
      EOF
    end
  end

  describe 'hidden files when globbing' do
    context 'from working tree' do
      before do
        %w[abc .def .fresh-order].each do |path|
          touch [fresh_local_path, 'hidden-test', path]
        end
      end

      it 'ignores hidden files' do
        rc "fresh 'hidden-test/*'"

        run_fresh

        expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
          # fresh: hidden-test/abc
        EOF
      end

      it 'includes hidden files when explicitly referenced from working tree' do
        rc "fresh 'hidden-test/.*'"

        run_fresh

        expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
          # fresh: hidden-test/.def
        EOF
      end
    end

    context 'with ref' do
      before do
        stub_git
      end

      it 'ignores hidden files' do
        rc "fresh repo/name 'hidden-test/*' --ref=abc1237"

        run_fresh

        expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
          # fresh: repo/name hidden-test/foo @ abc1237
        EOF
      end

      it 'includes hidden files when explicitly referenced with ref' do
        rc "fresh repo/name 'hidden-test/.*' --ref=abc1237"

        run_fresh

        expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
          # fresh: repo/name hidden-test/.bar @ abc1237
        EOF
      end
    end
  end

  describe 'ordering with .fresh-order when globbing' do
    it 'from working tree' do
      rc "fresh 'order-test/*'"
      %w[a b c d e].each do |path|
        touch [fresh_local_path, 'order-test', path]
      end
      file_add fresh_local_path + 'order-test/.fresh-order', <<-EOF.strip_heredoc
        d
        f
        b
      EOF

      run_fresh

      expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
        # fresh: order-test/d
        # fresh: order-test/b
        # fresh: order-test/a
        # fresh: order-test/c
        # fresh: order-test/e
      EOF
    end

    it 'with ref' do
      rc "fresh repo/name 'order-test/*' --ref=abc1237"
      FileUtils.mkdir_p fresh_path + 'source/repo/name'
      stub_git

      run_fresh

      expect(File.read(shell_sh_path).lines.grep(/^# fresh/).join).to eq <<-EOF.strip_heredoc
        # fresh: repo/name order-test/d @ abc1237
        # fresh: repo/name order-test/b @ abc1237
        # fresh: repo/name order-test/a @ abc1237
        # fresh: repo/name order-test/c @ abc1237
        # fresh: repo/name order-test/e @ abc1237
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_path + 'source/repo/name'}
        git show abc1237:order-test/.fresh-order
        cd #{fresh_path + 'source/repo/name'}
        git ls-tree -r --name-only abc1237
        cd #{fresh_path + 'source/repo/name'}
        git show abc1237:order-test/d
        cd #{fresh_path + 'source/repo/name'}
        git show abc1237:order-test/b
        cd #{fresh_path + 'source/repo/name'}
        git show abc1237:order-test/a
        cd #{fresh_path + 'source/repo/name'}
        git show abc1237:order-test/c
        cd #{fresh_path + 'source/repo/name'}
        git show abc1237:order-test/e
      EOF
    end
  end
end
