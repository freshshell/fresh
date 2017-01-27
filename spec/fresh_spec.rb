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

      expect_shell_sh.to eq <<-EOF.strip_heredoc
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

      expect_shell_sh.to eq <<-EOF.strip_heredoc
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

      expect_shell_sh.to eq <<-EOF.strip_heredoc
        # fresh: aliases/file1

        file1

        # fresh: aliases/file2

        file2
      EOF
    end

    it 'creates empty output with no freshrc file' do
      expect(shell_sh_path).to_not exist

      run_fresh

      expect(shell_sh_path).to exist
      expect_shell_sh.to eq ''
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

    describe 'using --ignore-missing' do
      it 'builds' do
        rc 'fresh aliases/haskell --ignore-missing'
        FileUtils.mkdir_p fresh_local_path

        run_fresh

        expect_shell_sh.to eq ''
      end

      it 'does not create a file when single source is missing' do
        rc <<-EOF.strip_heredoc
          fresh tmux.conf --file --ignore-missing
          fresh ghci --file --ignore-missing
        EOF
        touch fresh_local_path + 'tmux.conf'

        run_fresh

        expect(fresh_path + 'build/tmux.conf').to exist
        expect(fresh_path + 'build/ghci').to_not exist
      end
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

        expect_shell_sh.to eq ''

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
          path = fresh_path + 'build' + path
          expect(path).to exist
          expect(path).to_not be_executable
          expect(path).to_not be_world_readable
          expect(path).to_not be_writable
        end
      end

      it 'builds generic files with globbing' do
        rc "fresh 'file*' --file"

        file_add fresh_local_path + 'file1', 'file1'
        file_add fresh_local_path + 'file2', 'file2'
        file_add fresh_local_path + 'other', 'other'

        run_fresh

        expect(fresh_path + 'build/file1').to exist
        expect(fresh_path + 'build/file2').to exist
        expect(fresh_path + 'build/other').to_not exist
      end

      it 'links generic files to destination' do
        rc <<-EOF.strip_heredoc
          fresh lib/tmux.conf --file
          fresh lib/pryrc.rb --file=~/.pryrc
          fresh .gitconfig --file
          fresh bclear.vim --file=~/.vim/colors/bclear.vim
          fresh "with spaces (and parentheses)" --file="~/a path/with spaces (and parentheses)"
        EOF
        %w[lib/tmux.conf lib/pryrc.rb .gitconfig bclear.vim with\ spaces\ (and\ parentheses)].each do |path|
          touch fresh_local_path + path
        end

        run_fresh

        [
          %w[tmux.conf ~/.tmux.conf],
          %w[pryrc ~/.pryrc],
          %w[gitconfig ~/.gitconfig],
          %w[vim-colors-bclear.vim ~/.vim/colors/bclear.vim],
          %w[a-path-with-spaces-and-parentheses ~/a\ path/with\ spaces\ (and\ parentheses)],
        ].each do |build_file, symlink_destination|
          expect_readlink(symlink_destination).to eq (fresh_path + 'build' + build_file).to_s
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
          expect_readlink(symlink_destination).to eq (fresh_path + 'build' + build_file).to_s
        end
      end

      it 'does not link generic files with relative paths' do
        rc 'fresh foo-bar.zsh --file=vendor/foo/bar.zsh'
        touch fresh_local_path + 'foo-bar.zsh'

        run_fresh

        expect(fresh_path + 'build/vendor/foo/bar.zsh').to exist
        expect_pathname('vendor/foo/bar.zsh').to_not be_symlink
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

      describe 'directories of generic files' do
        let(:files_in_build_directory) do
          Dir[fresh_path + 'build/**/*'].
            reject { |path| File.directory? path }.
            map { |path| path.sub Regexp.new((fresh_path + 'build/').to_s), '' }.sort
        end

        describe 'with local files in nested folders' do
          before do
            touch fresh_local_path + 'foo/bar/file1'
            touch fresh_local_path + 'foo/bar/file2'
            touch fresh_local_path + 'foo/file3'
            touch fresh_local_path + 'foobar/file4'
            touch fresh_local_path + 'foobar/file5'
          end

          it 'builds files' do
            rc 'fresh foo --file=vendor/misc/foo/'
            rc 'fresh foo/bar --file=vendor/other/'

            run_fresh

            expect(files_in_build_directory).to eq %w[
              shell.sh
              vendor/misc/foo/bar/file1
              vendor/misc/foo/bar/file2
              vendor/misc/foo/file3
              vendor/other/file1
              vendor/other/file2
            ]
          end

          it 'links files' do
            rc 'fresh foo --file=~/.foo/'
            rc 'fresh foo/bar --file=~/.nested/target/'

            run_fresh

            expect(files_in_build_directory).to eq %w[
              foo/bar/file1
              foo/bar/file2
              foo/file3
              nested-target/file1
              nested-target/file2
              shell.sh
            ]

            expect_readlink('~/.foo').to eq (fresh_path + 'build/foo').to_s
            expect_readlink('~/.nested/target').to eq (fresh_path + 'build/nested-target').to_s

            # can traverse symlink
            expect_pathname('~/.foo/bar/file1').to exist
            expect_pathname('~/.nested/target/file1').to exist
          end
        end

        it 'builds with ref' do
          rc 'fresh repo/name recursive-test --ref=abc1237 --file=vendor/test/'
          FileUtils.mkdir_p fresh_path + 'source/repo/name'
          stub_git

          run_fresh

          expect(git_log).to eq <<-EOF.strip_heredoc
            cd #{fresh_path + 'source/repo/name'}
            git ls-tree -r --name-only abc1237
            cd #{fresh_path + 'source/repo/name'}
            git show abc1237:recursive-test/abc/def
            cd #{fresh_path + 'source/repo/name'}
            git show abc1237:recursive-test/bar
            cd #{fresh_path + 'source/repo/name'}
            git show abc1237:recursive-test/foo
          EOF

          expect(files_in_build_directory).to eq %w[
            shell.sh
            vendor/test/abc/def
            vendor/test/bar
            vendor/test/foo
          ]
        end
      end
    end

    describe 'using --bin' do
      it 'builds bin files' do
        rc 'fresh scripts/sedmv --bin'
        rc 'fresh pidof.sh --bin=~/bin/pidof'
        file_add fresh_local_path + 'scripts/sedmv', 'foo'
        file_add fresh_local_path + 'pidof.sh', 'bar'

        run_fresh

        expect(File.read(fresh_path + 'build/bin/sedmv')).to eq "foo\n"
        expect(File.read(fresh_path + 'build/bin/pidof')).to eq "bar\n"

        [
          fresh_path + 'build/bin/sedmv',
          fresh_path + 'build/bin/pidof',
        ].each do |path|
          expect(path).to be_executable
          expect(path).to_not be_writable
        end
      end

      it 'builds bin files with globbing' do
        rc "fresh 'file*' --bin"
        %w[file1 file2 other].each { |path| file_add fresh_local_path + path, path }

        run_fresh

        expect(fresh_path + 'build/bin/file1').to exist
        expect(fresh_path + 'build/bin/file2').to exist
        expect(fresh_path + 'build/bin/other').to_not exist
      end

      it 'links bin files to destination' do
        rc <<-EOF.strip_heredoc
          fresh scripts/sedmv --bin
          fresh pidof.sh --bin=~/bin/pidof
          fresh gemdiff --bin=~/bin/scripts/gemdiff
        EOF

        %w[scripts/sedmv pidof.sh gemdiff].each do |path|
          touch fresh_local_path + path
        end

        run_fresh

        expect_readlink('~/bin/sedmv').to eq (fresh_path + 'build/bin/sedmv').to_s
        expect_readlink('~/bin/pidof').to eq (fresh_path + 'build/bin/pidof').to_s
        expect_readlink('~/bin/scripts/gemdiff').to eq (fresh_path + 'build/bin/gemdiff').to_s
      end

      it 'warns if concatenating bin files' do
        rc <<-EOF.strip_heredoc
          FRESH_NO_BIN_CONFLICT_CHECK=true
          fresh gemdiff --bin
          fresh scripts/gemdiff --bin
          unset FRESH_NO_BIN_CONFLICT_CHECK
          fresh sedmv --bin
          fresh scripts/sedmv --bin
        EOF
        %w[scripts/sedmv sedmv scripts/gemdiff gemdiff].each do |path|
          touch fresh_local_path + path
        end

        run_fresh success: <<-EOF.strip_heredoc
          #{NOTE_PREFIX} Multiple sources concatenated into a single bin file.
          #{freshrc_path}:6: fresh scripts/sedmv --bin

          Typically bin files should not be concatenated together into one file.
          "bin/sedmv" may not function as expected.

          To disable this warning, add \`FRESH_NO_BIN_CONFLICT_CHECK=true\` in your freshrc file.

          #{FRESH_SUCCESS_LINE}
        EOF

        expect_readlink('~/bin/sedmv').to eq (fresh_path + 'build/bin/sedmv').to_s
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

        expect(git_log_path).to_not exist
      end
    end

    describe 'building shell files' do
      it 'builds shell files from cloned github repos' do
        rc 'fresh repo/name file'
        file_add fresh_path + 'source/repo/name/file', 'remote content'

        run_fresh

        expect_shell_sh.to eq <<-EOF.strip_heredoc
          # fresh: repo/name file

          remote content
        EOF
      end

      it 'builds shell files from cloned other repos' do
        rc 'fresh git://example.com/foobar.git file'
        file_add fresh_path + 'source/example.com/foobar/file', 'remote content'

        run_fresh

        expect_shell_sh.to eq <<-EOF.strip_heredoc
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

        expect_shell_sh.to eq <<-EOF.strip_heredoc
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
          expect(fresh_path + 'build/ackrc').to exist
          expect(fresh_path + 'missing').to_not exist
        end
      end

      it 'errors if no ref is specified' do
        rc 'fresh foo --file --ref'

        run_fresh error: <<-EOF.strip_heredoc
          #{ERROR_PREFIX} You must specify a Git reference.
          #{freshrc_path}:1: fresh foo --file --ref

          You may need to run `fresh update` if you're adding a new line,
          or the file you're referencing may have moved or been deleted.
        EOF
      end
    end

    describe 'whole repos' do
      before do
        stub_git
      end

      it 'links directory of generic files for whole repo' do
        rc 'fresh repo/name . --file=~/.foo/'

        file_add fresh_path + 'source/repo/name/file1', 'file1'
        file_add fresh_path + 'source/repo/name/sub/file2', 'file2'
        touch fresh_path + 'source/repo/name/.git/some-file'
        touch fresh_path + 'source/repo/name/.hidden-dir/some-file'

        run_fresh

        expect_readlink('~/.foo').to eq (fresh_path + 'build/foo').to_s

        expect(File.read(fresh_path + 'build/foo/file1')).to eq "file1\n"
        expect(File.read(fresh_path + 'build/foo/sub/file2')).to eq "file2\n"

        expect(fresh_path + 'build/foo/.git').to_not exist
        expect(fresh_path + 'build/foo/.hidden-dir').to exist

        # can traverse symlink
        expect_pathname('~/.foo/file1').to exist
        expect_pathname('~/.foo/sub/file2').to exist
      end

      it 'links directory of generic files for whole repo with ref' do
        rc 'fresh repo/name . --file=~/.foo/ --ref=abc123'

        run_fresh

        expect_readlink('~/.foo').to eq (fresh_path + 'build/foo').to_s

        expect(File.read(fresh_path + 'build/foo/ackrc')).to eq "test data for abc123:ackrc\n"
        expect(
          File.read(fresh_path + 'build/foo/recursive-test/abc/def')
        ).to eq "test data for abc123:recursive-test/abc/def\n"

        # can traverse symlink
        expect_pathname('~/.foo/ackrc').to exist
        expect_pathname('~/.foo/recursive-test/abc/def').to exist
      end

      describe 'errors if trying to use whole repo with invalid arguments' do
        it 'runs with good arguments' do
          rc 'fresh repo/name . --file=~/.good/'
          run_fresh
        end

        it 'errors with an invalid path to --file' do
          rc 'fresh repo/name . --file=~/.bad-path'
          run_fresh error_title: <<-EOF.strip_heredoc
            #{ERROR_PREFIX} Whole repositories require destination to be a directory.
          EOF
        end

        it 'errors when missing path to --file' do
          rc 'fresh repo/name . --file'
          run_fresh error_title: <<-EOF.strip_heredoc
            #{ERROR_PREFIX} Whole repositories require destination to be a directory.
          EOF
        end

        it 'errors when missing --file' do
          rc 'fresh repo/name .'
          run_fresh error_title: <<-EOF.strip_heredoc
            #{ERROR_PREFIX} Whole repositories can only be sourced in file mode.
          EOF
        end

        it 'errors when missing repo' do
          rc 'fresh . --file=~/.bad-local/'
          run_fresh error_title: <<-EOF.strip_heredoc
            #{ERROR_PREFIX} Cannot source whole of local dotfiles.
          EOF
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

      expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
        # fresh: recursive-test/bar
        # fresh: recursive-test/foo
      EOF
    end

    it 'with ref' do
      rc "fresh repo/name 'recursive-test/*' --ref=abc1237"
      stub_git

      run_fresh

      expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
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

        expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
          # fresh: hidden-test/abc
        EOF
      end

      it 'includes hidden files when explicitly referenced from working tree' do
        rc "fresh 'hidden-test/.*'"

        run_fresh

        expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
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

        expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
          # fresh: repo/name hidden-test/foo @ abc1237
        EOF
      end

      it 'includes hidden files when explicitly referenced with ref' do
        rc "fresh repo/name 'hidden-test/.*' --ref=abc1237"

        run_fresh

        expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
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

      expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
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

      expect(shell_sh_marker_lines).to eq <<-EOF.strip_heredoc
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

  describe 'using --filter' do
    it 'runs filters on files' do
      file_add fresh_local_path + 'aliases', 'foo other_username bar'
      rc "fresh aliases --filter='sed s/other_username/my_username/ | tr _ -'"

      run_fresh

      expect_shell_sh.to eq <<-EOF.strip_heredoc
        # fresh: aliases # sed s/other_username/my_username/ | tr _ -

        foo my-username bar
      EOF
    end

    it 'runs filters on files locked to a ref' do
      FileUtils.mkdir_p fresh_local_path
      rc "fresh aliases/git.sh --ref=abc1237 --filter='sed s/test/TEST/'"
      stub_git

      run_fresh

      expect_shell_sh.to eq <<-EOF.strip_heredoc
        # fresh: aliases/git.sh @ abc1237 # sed s/test/TEST/

        TEST data for abc1237:aliases/git.sh
      EOF
    end

    it 'runs filters that reference functions from the freshrc' do
      file_add fresh_local_path + 'aliases', 'foo other_username bar'
      rc <<-EOF.strip_heredoc
        replace_username() {
          sed s/other_username/my_username/ | tr _ -
        }

        fresh aliases --filter=replace_username
      EOF

      run_fresh

      expect_shell_sh.to eq <<-EOF.strip_heredoc
        # fresh: aliases # replace_username

        foo my-username bar
      EOF
    end

    it 'errors when no filter is specified' do
      rc 'fresh foo --filter'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} You must specify a filter program.
        #{freshrc_path}:1: fresh foo --filter

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end
  end

  it 'errors when linking bin files with relative paths' do
    touch fresh_local_path + 'foobar'

    rc 'fresh foobar --bin=foobar'
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} --bin file paths cannot be relative.
      #{freshrc_path}:1: fresh foobar --bin=foobar

      You may need to run `fresh update` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
    EOF

    rc_reset
    rc 'fresh foobar --bin=../foobar'
    run_fresh error_title: "#{ERROR_PREFIX} --bin file paths cannot be relative.\n"
  end

  it 'errors if existing symlink for bin does not point to a fresh path' do
    rc 'fresh bin/sedmv --bin'
    touch fresh_local_path + 'bin/sedmv'
    FileUtils.mkdir_p File.expand_path('~/bin')
    FileUtils.ln_s '/dev/null', File.expand_path('~/bin/sedmv')

    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} #{ENV['HOME']}/bin/sedmv already exists (pointing to /dev/null).
      #{freshrc_path}:1: fresh bin/sedmv --bin

      You may need to run \`fresh update\` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
    EOF

    expect_readlink('~/bin/sedmv').to eq '/dev/null'
  end

  context 'with a pryrc file' do
    before do
      rc 'fresh pryrc --file'
      touch fresh_local_path + 'pryrc'
    end

    it 'errors if existing symlink for file does not point to a fresh path' do
      FileUtils.ln_s '/dev/null', File.expand_path('~/.pryrc')

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} #{ENV['HOME']}/.pryrc already exists (pointing to /dev/null).
        #{freshrc_path}:1: fresh pryrc --file

        You may need to run \`fresh update\` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF

      expect_readlink('~/.pryrc').to eq '/dev/null'
    end

    it 'errors if file exists' do
      touch sandbox_path + 'home/.pryrc'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} #{ENV['HOME']}/.pryrc already exists.
        #{freshrc_path}:1: fresh pryrc --file
      EOF
    end

    it 'errors if directory is not writable' do
      FileUtils.chmod '-w', sandbox_path + 'home'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Could not create #{ENV['HOME']}/.pryrc. Do you have permission?
        #{freshrc_path}:1: fresh pryrc --file
      EOF
    end

    it 'replaces old symlinks pointing inside the fresh build directory' do
      FileUtils.ln_s fresh_path + 'build/pryrc-old-name', File.expand_path('~/.pryrc')

      run_fresh

      expect_readlink('~/.pryrc').to eq (fresh_path + 'build/pryrc').to_s
    end
  end

  it 'errors if directory cannot be created' do
    rc 'fresh foo --file=~/.config/foo'
    touch fresh_local_path + 'foo'

    FileUtils.chmod '-w', sandbox_path + 'home'

    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} Could not create #{ENV['HOME']}/.config/foo. Do you have permission?
      #{freshrc_path}:1: fresh foo --file=~/.config/foo
    EOF
  end

  it 'does not error for symlinks created by fresh' do
    rc 'fresh pryrc --file'
    rc 'fresh bin/sedmv --bin'
    touch fresh_local_path + 'pryrc'
    touch fresh_local_path + 'bin/sedmv'

    run_fresh # build symlinks
    run_fresh # run fresh again to check symlinks
  end

  it 'errors if link destination is a file' do
    touch fresh_local_path + 'gitconfig'
    touch fresh_local_path + 'sedmv'
    file_add File.expand_path('~/.gitconfig'), 'foo'
    file_add File.expand_path('~/bin/sedmv'), 'bar'

    rc 'fresh gitconfig --file'
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} #{sandbox_path}/home/.gitconfig already exists.
      #{freshrc_path}:1: fresh gitconfig --file
    EOF
    expect(File.read(File.expand_path('~/.gitconfig'))).to eq "foo\n"

    rc_reset

    rc 'fresh sedmv --bin'
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} #{sandbox_path}/home/bin/sedmv already exists.
      #{freshrc_path}:1: fresh sedmv --bin
    EOF
    expect(File.read(File.expand_path('~/bin/sedmv'))).to eq "bar\n"
  end

  it 'shows source of errors' do
    stub_git
    FileUtils.mkdir_p fresh_local_path

    rc 'fresh bad-file'
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} Could not find "bad-file" source file.
      #{freshrc_path}:1: fresh bad-file

      You may need to run \`fresh update\` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
    EOF

    rc_reset
    rc 'fresh repo/name bad-file --ref=abc123'
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} Could not find "bad-file" source file.
      #{freshrc_path}:1: fresh repo/name bad-file --ref=abc123

      You may need to run \`fresh update\` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
      Have a look at the repo: <#{format_url 'https://github.com/repo/name'}>
    EOF

    rc_reset
    rc 'fresh repo/name some-file --blah'
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} Unknown option: --blah
      #{freshrc_path}:1: fresh repo/name some-file --blah

      You may need to run \`fresh update\` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
      Have a look at the repo: <#{format_url 'https://github.com/repo/name'}>
    EOF

    rc_reset
    rc 'source ~/.freshrc.local'
    file_add sandbox_path + 'home/.freshrc.local', <<-EOF.strip_heredoc
      # local customisations

      fresh pry.rb --file=~/.pryrc # ruby
      fresh some-other-file
    EOF
    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} Could not find "pry.rb" source file.
      ~/.freshrc.local:3: fresh pry.rb --file=~/.pryrc # ruby

      You may need to run \`fresh update\` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
    EOF
  end

  describe 'update' do
    it 'updates fresh files' do
      FileUtils.mkdir_p fresh_path + 'source/repo/name/.git'
      FileUtils.mkdir_p fresh_path + 'source/other_repo/other_name/.git'
      stub_git

      run_fresh command: 'update', success: <<-EOF.strip_heredoc
        * Updating other_repo/other_name
        | Current branch master is up to date.
        * Updating repo/name
        | Current branch master is up to date.
        #{FRESH_SUCCESS_LINE}
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_path + 'source/other_repo/other_name'}
        git pull --rebase
        cd #{fresh_path + 'source/repo/name'}
        git pull --rebase
      EOF
    end

    it 'updates fresh files for a specified GitHub user' do
      FileUtils.mkdir_p fresh_path + 'source/twe4ked/dotfiles/.git'
      FileUtils.mkdir_p fresh_path + 'source/twe4ked/scripts/.git'
      FileUtils.mkdir_p fresh_path + 'source/jasoncodes/dotfiles/.git'
      stub_git

      run_fresh command: %w[update twe4ked], success: <<-EOF.strip_heredoc
        * Updating twe4ked/dotfiles
        | Current branch master is up to date.
        * Updating twe4ked/scripts
        | Current branch master is up to date.
        #{FRESH_SUCCESS_LINE}
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_path + 'source/twe4ked/dotfiles'}
        git pull --rebase
        cd #{fresh_path + 'source/twe4ked/scripts'}
        git pull --rebase
      EOF
    end

    it 'updates fresh files for a specified GitHub repo' do
      FileUtils.mkdir_p fresh_path + 'source/twe4ked/dotfiles/.git'
      FileUtils.mkdir_p fresh_path + 'source/twe4ked/dotfiles-old/.git'
      FileUtils.mkdir_p fresh_path + 'source/twe4ked/scripts/.git'
      FileUtils.mkdir_p fresh_path + 'source/jasoncodes/dotfiles/.git'
      stub_git

      run_fresh command: %w[update twe4ked/dotfiles], success: <<-EOF.strip_heredoc
        * Updating twe4ked/dotfiles
        | Current branch master is up to date.
        #{FRESH_SUCCESS_LINE}
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_path + 'source/twe4ked/dotfiles'}
        git pull --rebase
      EOF
    end

    context 'with local and fresh repo' do
      before do
        FileUtils.mkdir_p fresh_local_path + '.git'
        FileUtils.mkdir_p fresh_path + 'source/freshshell/fresh/.git'
        stub_git
      end

      it 'updates local repo with no args' do
        run_fresh command: 'update', success: <<-EOF.strip_heredoc
          * Updating local files
          | Current branch master is up to date.
          * Updating freshshell/fresh
          | Current branch master is up to date.
          #{FRESH_SUCCESS_LINE}
        EOF

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{fresh_local_path}
          git rev-parse @{u}
          cd #{fresh_local_path}
          git status --porcelain
          cd #{fresh_local_path}
          git pull --rebase
          cd #{fresh_path + 'source/freshshell/fresh'}
          git pull --rebase
        EOF
      end

      it 'only updates local repo with --local arg' do
        run_fresh command: %w[update --local], success: <<-EOF.strip_heredoc
          * Updating local files
          | Current branch master is up to date.
          #{FRESH_SUCCESS_LINE}
        EOF

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{fresh_local_path}
          git rev-parse @{u}
          cd #{fresh_local_path}
          git status --porcelain
          cd #{fresh_local_path}
          git pull --rebase
        EOF
      end

      it 'does not update local with other args' do
        run_fresh command: %w[update freshshell], success: <<-EOF.strip_heredoc
          * Updating freshshell/fresh
          | Current branch master is up to date.
          #{FRESH_SUCCESS_LINE}
        EOF

        expect(git_log).to eq <<-EOF.strip_heredoc
          cd #{fresh_path + 'source/freshshell/fresh'}
          git pull --rebase
        EOF
      end
    end

    it 'does not update local dirty local' do
      touch fresh_local_path + '.git/dirty'
      stub_git

      run_fresh command: %w[update --local], exit_status: false, success: <<-EOF.strip_heredoc
        #{NOTE_PREFIX} Not updating #{fresh_local_path} because it has uncommitted changes.
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_local_path}
        git rev-parse @{u}
        cd #{fresh_local_path}
        git status --porcelain
      EOF
    end

    it 'errors if no matching sources to update' do
      FileUtils.mkdir_p fresh_path + 'source'

      run_fresh(
        command: %w[update foobar],
        error: "#{ERROR_PREFIX} No matching sources found.\n"
      )
    end

    it 'errors if more than one argument is passed to update' do
      FileUtils.mkdir_p fresh_path + 'source'

      run_fresh command: %w[update twe4ked dotfiles], error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Invalid arguments.

        usage: fresh update <filter>

            The filter can be either a GitHub username or username/repo.
      EOF
    end

    it 'shows a github compare url when updating remote' do
      file_add fresh_path + 'source/jasoncodes/dotfiles/.git/output', <<-EOF.strip_heredoc
        From https://github.com/jasoncodes/dotfiles
           47ad84c..57b8b2b  master     -> origin/master
        First, rewinding head to replay your work on top of it...
        Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
      EOF
      stub_git

      run_fresh command: 'update', success: <<-EOF.strip_heredoc
        * Updating jasoncodes/dotfiles
        | From https://github.com/jasoncodes/dotfiles
        |    47ad84c..57b8b2b  master     -> origin/master
        | First, rewinding head to replay your work on top of it...
        | Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
        | <#{format_url 'https://github.com/jasoncodes/dotfiles/compare/47ad84c...57b8b2b'}>
        #{FRESH_SUCCESS_LINE}
      EOF
    end

    it 'shows a github compare url when updating local' do
      stub_git

      file_add fresh_local_path + '.git/output', <<-EOF.strip_heredoc
        From https://github.com/jasoncodes/dotfiles
           47ad84c..57b8b2b  master     -> origin/master
        First, rewinding head to replay your work on top of it...
        Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
      EOF

      run_fresh command: %w[update --local], success: <<-EOF.strip_heredoc
        * Updating local files
        | From https://github.com/jasoncodes/dotfiles
        |    47ad84c..57b8b2b  master     -> origin/master
        | First, rewinding head to replay your work on top of it...
        | Fast-forwarded master to 57b8b2ba7482884169a187d46be63fb8f8f4146b.
        | <#{format_url 'https://github.com/jasoncodes/dotfiles/compare/47ad84c...57b8b2b'}>
        #{FRESH_SUCCESS_LINE}
      EOF
    end

    it 'shows no url when updating other repos' do
      stub_git

      file_add fresh_path + 'source/gitorious.org/willgit-mainline/.git/output', <<-EOF.strip_heredoc
        From git://gitorious.org/willgit/mainline
           67444ba..a2322a5  master     -> origin/master
      EOF

      run_fresh command: 'update', success: <<-EOF.strip_heredoc
        * Updating gitorious.org/willgit-mainline
        | From git://gitorious.org/willgit/mainline
        |    67444ba..a2322a5  master     -> origin/master
        #{FRESH_SUCCESS_LINE}
      EOF
    end

    it 'logs update output' do
      FileUtils.mkdir_p fresh_local_path + '.git'
      FileUtils.mkdir_p fresh_path + 'source/repo/name/.git'
      FileUtils.mkdir_p fresh_path + 'source/other_repo/other_name/.git'
      stub_git

      run_fresh command: 'update', success: <<-EOF.strip_heredoc
        * Updating local files
        | Current branch master is up to date.
        * Updating other_repo/other_name
        | Current branch master is up to date.
        * Updating repo/name
        | Current branch master is up to date.
        #{FRESH_SUCCESS_LINE}
      EOF

      log_files = Dir[fresh_path + 'logs/*']

      expect(log_files.count).to eq 1
      expect(log_files.first).to match %r{#{fresh_path + 'logs/update'}-\d{4}-\d{2}-\d{2}-\d{6}\.log}
      expect(File.read(log_files.first)).to eq <<-EOF.strip_heredoc
        * Updating local files
        | Current branch master is up to date.
        * Updating other_repo/other_name
        | Current branch master is up to date.
        * Updating repo/name
        | Current branch master is up to date.
      EOF
    end

    it 'does not run build if update fails' do
      rc 'fresh aliases'
      file_add fresh_local_path + 'aliases', "alias gs='git status'"
      FileUtils.mkdir_p fresh_path + 'source/repo/name1/.git'
      FileUtils.mkdir_p fresh_path + 'source/repo/name2/.git'
      touch fresh_path + 'source/repo/name1/.git/failure'
      stub_git

      run_fresh command: 'update', exit_status: false, success: <<-EOF.strip_heredoc
          * Updating repo/name1
          | Current branch master is up to date.
        EOF
      expect(fresh_path + 'build/shell.sh').to_not exist
    end

    it 'builds after update with latest binary' do
      rc 'fresh bin/\* --bin'
      file_add fresh_local_path + 'bin/fresh', 'echo new >> "$SANDBOX_PATH/fresh.log"'
      file_add fresh_local_path + 'bin/other', 'echo bad >> "$SANDBOX_PATH/fresh.log"'

      FileUtils.mkdir_p fresh_path + 'source'
      FileUtils.mkdir_p fresh_path + 'source/freshshell/fresh/.git'
      stub_git

      run_fresh command: 'update', success: <<-EOF.strip_heredoc
        * Updating freshshell/fresh
        | Current branch master is up to date.
      EOF

      expect(File.read(sandbox_path + 'fresh.log')).to eq "new\n"
    end
  end

  describe 'environment variable config' do
    describe 'FRESH_NO_BIN_CHECK' do
      before do
        ENV.delete('FRESH_NO_BIN_CHECK')
      end

      it 'does not error if freshrc has bin/fresh' do
        rc 'fresh bin/fresh --bin'
        touch fresh_local_path + 'bin/fresh'

        run_fresh
      end

      it 'errors if freshrc is missing bin/fresh' do
        run_fresh error: <<-EOF.strip_heredoc
          #{ERROR_PREFIX} It looks you do not have fresh in your freshrc file. This could result
          in difficulties running `fresh` later. You probably want to add a line like
          the following using `fresh edit`:

            fresh freshshell/fresh bin/fresh --bin

          To disable this error, add `FRESH_NO_BIN_CHECK=true` in your freshrc file.
        EOF
      end

      it 'allows bin/fresh error to be disabled' do
        ENV['FRESH_NO_BIN_CHECK'] = 'true'
        run_fresh
      end
    end

    describe 'FRESH_BIN_PATH' do
      let(:path) do
        capture(:stdout) do
          system <<-EOF
/usr/bin/env bash -c "$(
cat <<'SH'
  export PATH=/usr/bin
  source #{shell_sh_path}
  echo "$PATH" | tr ":" "\n"
SH
)"
          EOF
        end.split("\n")
      end


      it 'defaults to $HOME/bin' do
        run_fresh

        expect(path).to eq([
          (sandbox_path + 'home/bin').to_s,
          '/usr/bin'
        ])
        expect_shell_sh.to eq ''
      end

      it 'allows default bin path to be configured' do
        rc <<-EOF
          FRESH_BIN_PATH="$HOME/Applications/bin"
          fresh bin/fresh --bin
        EOF
        file_add fresh_local_path + 'bin/fresh', 'test file'

        run_fresh

        fresh_bin_path = File.join(ENV['HOME'], 'Applications/bin/fresh')
        expect_pathname(fresh_bin_path).to exist
        expect(File.read(fresh_bin_path)).to eq "test file\n"
        expect_readlink(fresh_bin_path).to eq (fresh_path + 'build/bin/fresh').to_s
        expect(File.read(shell_sh_path)).to eq <<-EOF.strip_heredoc
          __FRESH_BIN_PATH__=$HOME/Applications/bin; [[ ! $PATH =~ (^|:)$__FRESH_BIN_PATH__(:|$) ]] && export PATH="$__FRESH_BIN_PATH__:$PATH"; unset __FRESH_BIN_PATH__
          export FRESH_PATH="#{fresh_path}"
        EOF

        expect(path).to eq([
          (sandbox_path + 'home/Applications/bin').to_s,
          '/usr/bin'
        ])
      end

      it 'does not duplicate FRESH_BIN_PATH in the PATH in subshells' do
        run_fresh

        path = capture(:stdout) do
          system <<-EOF
/usr/bin/env bash -c "$(
cat <<'SH'
  export PATH=/usr/bin
  source #{shell_sh_path}
  source #{shell_sh_path}
  echo "$PATH" | tr ":" "\n"
SH
)"
          EOF
        end.split("\n")

        expect(path).to eq([
          (sandbox_path + 'home/bin').to_s,
          '/usr/bin'
        ])
      end

      it 'unsets the __FRESH_BIN_PATH__ variable' do
        run_fresh
        out = capture(:stdout) do
          system <<-EOF
/usr/bin/env bash -c "$(
cat <<'SH'
  source #{shell_sh_path}
  echo "$__FRESH_BIN_PATH__"
SH
)"
          EOF
        end.chomp

        expect(out).to eq ''
      end
    end

    describe 'FRESH_NO_PATH_EXPORT' do
      it 'does not output a $PATH if enabled' do
        ENV['FRESH_NO_PATH_EXPORT'] = '1'
        run_fresh

        expect(File.read(shell_sh_path)).to eq <<-EOF.strip_heredoc
          export FRESH_PATH="#{fresh_path}"
        EOF
      end
    end

    it 'exposes FRESH_* environment to freshrc' do
      rc 'echo rc=$FRESH_RCFILE'
      rc 'echo path=$FRESH_PATH'
      rc 'echo local=$FRESH_LOCAL'
      rc 'echo bin=$FRESH_BIN_PATH'

      run_fresh success: <<-EOF.strip_heredoc
        rc=#{freshrc_path}
        path=#{fresh_path}
        local=#{fresh_local_path}
        bin=#{sandbox_path + 'home/bin'}
        #{FRESH_SUCCESS_LINE}
      EOF
    end
  end

  describe 'fresh_after_build' do
    it 'runs fresh after build' do
      rc "fresh_after_build() { echo test after_build; }"

      run_fresh success: <<-EOF.strip_heredoc
        test after_build
        #{FRESH_SUCCESS_LINE}
      EOF
    end
  end

  describe 'search' do
    it 'searches directory for keywords' do
      stub_curl 'foo', 'bar baz'

      run_fresh command: %w[search foo bar], success: <<-EOF.strip_heredoc
        foo
        bar baz
      EOF

      expect(curl_log).to eq <<-EOF.strip_heredoc
        curl
        -sS
        http://api.freshshell.com/directory
        --get
        --data-urlencode
        q=foo bar
      EOF
    end

    it 'shows error if no search query given' do
      stub_curl

      run_fresh(
        command: 'search',
        error: "#{ERROR_PREFIX} No search query given.\n"
      )

      expect(curl_log_path).to_not exist
    end

    it 'shows error if search has no results' do
      stub_curl

      run_fresh(
        command: %w[search blah],
        error: "#{ERROR_PREFIX} No results.\n"
      )

      expect(curl_log).to eq <<-EOF.strip_heredoc
        curl
        -sS
        http://api.freshshell.com/directory
        --get
        --data-urlencode
        q=blah
      EOF
    end

    it 'shows error if search api call fails' do
      stub_curl error: 'Could not connect.'

      run_fresh(
        command: %w[search blah],
        error: "Could not connect.\n"
      )

      expect(curl_log).to eq <<-EOF.strip_heredoc
        curl
        -sS
        http://api.freshshell.com/directory
        --get
        --data-urlencode
        q=blah
      EOF
    end
  end

  describe 'clean' do
    it 'cleans dead symlinks from home and bin' do
      rc <<-EOF
        fresh alive --file
        fresh alive --bin
        fresh dead --file
        fresh dead --bin
      EOF

      touch fresh_local_path + 'alive'
      touch fresh_local_path + 'dead'

      run_fresh

      FileUtils.rm fresh_path + 'build/dead'
      FileUtils.rm fresh_path + 'build/bin/dead'

      FileUtils.ln_s 'no_such_file', File.expand_path('~/.other')
      FileUtils.ln_s 'no_such_file', File.expand_path('~/bin/other')

      run_fresh command: 'clean', success: <<-EOF.strip_heredoc
        Removing ~/.dead
        Removing ~/bin/dead
      EOF

      expect_pathname('~/.alive').to be_symlink
      expect_pathname('~/bin/alive').to be_symlink

      expect_pathname('~/.dead').to_not be_symlink
      expect_pathname('~/bin/dead').to_not be_symlink

      expect_pathname('~/.other').to be_symlink
      expect_pathname('~/bin/other').to be_symlink
    end

    it 'cleans repositories no longer referenced by freshrc' do
      rc <<-EOF
        fresh foo/bar file
        fresh git://example.com/foobar.git file
      EOF

      %w[foo/bar foo/baz abc/def example.com/foobar].each do |path|
        mkdir fresh_path + 'source' + path + '.git'
      end

      run_fresh command: 'clean', success: <<-EOF.strip_heredoc
        Removing source abc/def
        Removing source foo/baz
      EOF

      expect(fresh_path + 'source/foo/bar/.git').to exist
      expect(fresh_path + 'source/foo/baz/.git').to_not exist
      expect(fresh_path + 'source/abc/def/.git').to_not exist
      expect(fresh_path + 'source/abc').to_not exist
    end
  end

  describe 'show' do
    it 'shows sources for fresh lines' do
      rc <<-EOF
        fresh foo/bar aliases/*
        fresh foo/bar sedmv --bin --ref=abc123
        fresh local-file
      EOF
      touch fresh_path + 'source/foo/bar/aliases/git.sh'
      touch fresh_path + 'source/foo/bar/aliases/ruby.sh'
      touch fresh_local_path + 'local-file'
      stub_git

      run_fresh command: 'show', success: <<-EOF.strip_heredoc
        fresh foo/bar aliases/\\*
        <#{format_url 'https://github.com/foo/bar/blob/1234567/aliases/git.sh'}>
        <#{format_url 'https://github.com/foo/bar/blob/1234567/aliases/ruby.sh'}>

        fresh foo/bar sedmv --bin --ref=abc123
        <#{format_url 'https://github.com/foo/bar/blob/abc123/sedmv'}>

        fresh local-file
        <#{format_url fresh_local_path + 'local-file'}>
      EOF

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{sandbox_path + 'fresh/source/foo/bar'}
        git log --pretty=%H -n 1 -- aliases/git.sh
        cd #{sandbox_path + 'fresh/source/foo/bar'}
        git log --pretty=%H -n 1 -- aliases/ruby.sh
        cd #{sandbox_path + 'fresh/source/foo/bar'}
        git ls-tree -r --name-only abc123
      EOF
    end

    it 'shows git urls for non github repos' do
      rc 'fresh git://example.com/one/two.git file'
      stub_git

      run_fresh command: 'show', success: <<-EOF.strip_heredoc
        fresh git://example.com/one/two.git file
        <#{format_url 'git://example.com/one/two.git'}>
      EOF
    end
  end

  describe 'adding lines to freshrc interactively' do
    it 'for local files' do
      rc 'fresh existing'
      touch fresh_path + 'source/user/repo/file'
      touch fresh_local_path + 'existing'
      touch fresh_local_path + 'new file'

      run_fresh(
        full_command: 'yes | fresh new\ file',
        success: <<-EOF.strip_heredoc)
          Add `fresh new\\ file` to #{freshrc_path} [Y/n]? Adding `fresh new\\ file` to #{freshrc_path}...
          #{FRESH_SUCCESS_LINE}
        EOF

      expect(File.read(freshrc_path)).to eq <<-EOF.strip_heredoc
        fresh existing
        fresh new\\ file
      EOF
    end

    it 'for new remotes' do
      rc 'fresh existing'
      touch fresh_local_path + 'existing'
      stub_git

      run_fresh(
        full_command: 'yes | fresh user/repo file',
        success: <<-EOF.strip_heredoc)
          Add `fresh user/repo file` to #{freshrc_path} [Y/n]? Adding `fresh user/repo file` to #{freshrc_path}...
          #{FRESH_SUCCESS_LINE}
        EOF

      expect(File.read(freshrc_path)).to eq <<-EOF.strip_heredoc
        fresh existing
        fresh user/repo file
      EOF
      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{Dir.pwd}
        git clone https://github.com/user/repo #{fresh_path}/source/user/repo
      EOF
    end

    it 'for new remotes by url' do
      stub_git

      run_fresh(
        full_command: 'yes | fresh https://github.com/user/repo/blob/master/file',
        success: <<-EOF.strip_heredoc)
          Add `fresh user/repo file` to #{freshrc_path} [Y/n]? Adding `fresh user/repo file` to #{freshrc_path}...
          #{FRESH_SUCCESS_LINE}
        EOF

      expect(File.read(freshrc_path)).to eq <<-EOF.strip_heredoc
        fresh user/repo file
      EOF
      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{Dir.pwd}
        git clone https://github.com/user/repo #{fresh_path}/source/user/repo
      EOF
    end

    it 'for existing remotes and updates if the file does not exist' do
      file_add fresh_path + 'source/user/repo/.git/commands', 'touch "$FRESH_PATH/source/user/repo/file"'
      stub_git

      run_fresh(
        full_command: 'yes | fresh https://github.com/user/repo/blob/master/file',
        success: <<-EOF.strip_heredoc)
          Add \`fresh user/repo file\` to #{freshrc_path} [Y/n]? Adding \`fresh user/repo file\` to #{freshrc_path}...
          * Updating user/repo
          | Current branch master is up to date.
          #{FRESH_SUCCESS_LINE}
        EOF

      expect(File.read(freshrc_path)).to eq <<-EOF.strip_heredoc
        fresh user/repo file
      EOF
      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{fresh_path + 'source/user/repo'}
        git pull --rebase
      EOF
    end

    it 'without updating existing repo if the file exists' do
      mkdir fresh_path + 'source/user/repo/.git'
      touch fresh_path + 'source/user/repo/file'
      stub_git

      run_fresh(
        full_command: 'yes | fresh user/repo file',
        success: <<-EOF.strip_heredoc)
          Add \`fresh user/repo file\` to #{freshrc_path} [Y/n]? Adding \`fresh user/repo file\` to #{freshrc_path}...
          #{FRESH_SUCCESS_LINE}
        EOF

      expect(File.read(freshrc_path)).to eq <<-EOF.strip_heredoc
        fresh user/repo file
      EOF
      expect(git_log_path).to_not exist
    end

    it 'does not add lines to freshrc if declined' do
      rc 'fresh existing'
      touch fresh_local_path + 'existing'
      touch fresh_local_path + 'new'

      run_fresh(
        full_command: 'yes n | fresh new',
        success: <<-EOF.strip_heredoc)
          Add \`fresh new\` to #{freshrc_path} [Y/n]? #{NOTE_PREFIX} Use \`fresh edit\` to manually edit your #{freshrc_path}.
        EOF

      expect(File.read(freshrc_path)).to eq <<-EOF.strip_heredoc
        fresh existing
      EOF
    end

    describe 'from github URLs' do
      def expect_fresh_add_args(input, output)
        run_fresh(
          full_command: "yes n | fresh #{input}",
          success: %r{`#{output}`}
        )
      end

      it 'auto adds --bin' do
        expect_fresh_add_args(
          'https://github.com/twe4ked/catacomb/blob/master/bin/catacomb',
          'fresh twe4ked/catacomb bin/catacomb --bin'
        )
      end

      it '--bin will not duplicate' do
        expect_fresh_add_args(
          'https://github.com/twe4ked/catacomb/blob/master/bin/catacomb --bin',
          'fresh twe4ked/catacomb bin/catacomb --bin'
        )
      end

      it 'works out --ref' do
        expect_fresh_add_args(
          'https://github.com/twe4ked/catacomb/blob/a62f448/bin/catacomb',
          'fresh twe4ked/catacomb bin/catacomb --bin --ref=a62f448'
        )
      end

      it 'auto add --file' do
        expect_fresh_add_args(
          'https://github.com/twe4ked/dotfiles/blob/master/config/pryrc',
          'fresh twe4ked/dotfiles config/pryrc --file'
        )
      end

      it '--file will not duplicate' do
        expect_fresh_add_args(
          'https://github.com/twe4ked/dotfiles/blob/master/config/pryrc --file',
          'fresh twe4ked/dotfiles config/pryrc --file'
        )
      end

      it 'auto adds --file preserves other options' do
        expect_fresh_add_args(
          'https://github.com/twe4ked/dotfiles/blob/master/config/pryrc --marker',
          'fresh twe4ked/dotfiles config/pryrc --marker --file'
        )
      end

      it "doesn't add --bin or --file to other files" do
        expect_fresh_add_args(
          'https://github.com/twe4ked/dotfiles/blob/master/shell/aliases/git.sh',
          'fresh twe4ked/dotfiles shell/aliases/git.sh'
        )
      end
    end

    describe 'confirmation prompt' do
      it 'negative' do
        touch fresh_path + 'source/user/repo/file'
        touch fresh_local_path + 'new file'

        run_fresh(
          full_command: 'echo n | fresh new\ file',
          success: <<-EOF.strip_heredoc)
            Add `fresh new\\ file` to #{freshrc_path} [Y/n]? #{NOTE_PREFIX} Use `fresh edit` to manually edit your #{freshrc_path}.
          EOF
      end

      it 'default' do
        touch fresh_path + 'source/user/repo/file'
        touch fresh_local_path + 'new file'

        run_fresh(
          full_command: 'echo | fresh new\ file',
          success: <<-EOF.strip_heredoc)
            Add `fresh new\\ file` to #{freshrc_path} [Y/n]? Adding `fresh new\\ file` to #{freshrc_path}...
            #{FRESH_SUCCESS_LINE}
          EOF
      end

      it 'invalid' do
        touch fresh_path + 'source/user/repo/file'
        touch fresh_local_path + 'new file'

        run_fresh(
          full_command: 'echo -e "blah\ny" | fresh new\ file',
          success: <<-EOF.strip_heredoc)
            Add `fresh new\\ file` to #{freshrc_path} [Y/n]? Add `fresh new\\ file` to #{freshrc_path} [Y/n]? Adding `fresh new\\ file` to #{freshrc_path}...
            #{FRESH_SUCCESS_LINE}
          EOF
      end
    end
  end

  describe 'edit' do
    before do
      ENV['EDITOR'] = 'echo'
      ENV['FRESH_RCFILE'] = File.expand_path('~/.freshrc')
    end

    it 'edits freshrc files' do
      run_fresh command: 'edit', success: "#{File.expand_path '~/.freshrc'}\n"
    end

    it 'edits linked freshrc files' do
      touch File.expand_path('~/.dotfiles/freshrc')
      FileUtils.ln_s File.expand_path('~/.dotfiles/freshrc'), File.expand_path('~/.freshrc')
      run_fresh command: 'edit', success: "#{Dir.pwd}/home/.dotfiles/freshrc\n"
    end

    it 'edits relative linked freshrc files' do
      touch File.expand_path('~/.dotfiles/freshrc')
      FileUtils.ln_s '.dotfiles/freshrc', File.expand_path('~/.freshrc')
      run_fresh command: 'edit', success: "#{Dir.pwd}/home/.dotfiles/freshrc\n"
    end
  end

  describe 'fresh-options' do
    it 'applies fresh options to multiple lines' do
      rc <<-EOF
        fresh-options --file=~/.vimrc --marker=\\"
          fresh mappings.vim --filter='tr a x'
          fresh autocmds.vim
        fresh-options

        fresh zshrc --file
      EOF

      file_add fresh_local_path + 'mappings.vim', 'mappings'
      file_add fresh_local_path + 'autocmds.vim', 'autocmds'
      file_add fresh_local_path + 'zshrc', 'zsh config'

      run_fresh

      expect(File.read(fresh_path + 'build/vimrc')).to eq <<-EOF.strip_heredoc
        " fresh: mappings.vim # tr a x

        mxppings

        " fresh: autocmds.vim

        autocmds
      EOF

      expect(File.read(fresh_path + 'build/zshrc')).to eq <<-EOF.strip_heredoc
        zsh config
      EOF
    end
  end

  describe 'subcommands' do
    it 'runs subcommands' do
      bin = sandbox_path + 'bin/fresh-foo'
      file_add bin, 'echo foobar'
      FileUtils.chmod '+x', bin

      run_fresh(
        command: 'foo',
        success: "foobar\n"
      )
    end

    it 'errors for unknown commands' do
      run_fresh(
        command: 'foo',
        error: "#{ERROR_PREFIX} Unknown command: foo\n"
      )
    end
  end

  describe 'help' do
    it 'displays the help' do
      %w[foo bar].each do |plugin|
        path = bin_path + "fresh-#{plugin}"
        touch path
        FileUtils.chmod '+x', path
      end

      run_fresh command: 'help', env: {'PATH' => "#{bin_path}:/bin:/usr/bin"}, success: <<-EOF.strip_heredoc
        Keep your dot files #{FRESH_HIGHLIGHTED}.

        The following commands will install/update configuration files
        as specified in your #{freshrc_path} file.

        See #{format_url 'http://freshshell.com/readme'} for more documentation.

        usage: fresh <command> [<args>]

        Available commands:
            install            Build shell configuration and relevant symlinks (default)
            update [<filter>]  Update from source repos and rebuild
            clean              Removes dead symlinks and source repos
            search <query>     Search the fresh directory
            edit               Open freshrc for editing
            show               Show source references for freshrc lines
            help               Show this help
            bar                Run bar plugin
            foo                Run foo plugin
      EOF
    end
  end

  describe '--marker' do
    it 'errors if --marker is empty' do
      rc 'fresh foo --file --marker='

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Marker not specified.
        #{freshrc_path}:1: fresh foo --file --marker=

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end

    it 'errors if --marker is used without --file' do
      rc 'fresh foo --marker'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} --marker is only valid with --file.
        #{freshrc_path}:1: fresh foo --marker

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end

    it 'errors if --marker is used with --bin' do
      rc 'fresh foo --bin --marker'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} --marker is only valid with --file.
        #{freshrc_path}:1: fresh foo --bin --marker

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end
  end

  it 'errors if more than one mode is specifed' do
    rc 'fresh foo --file --bin'

    run_fresh error: <<-EOF.strip_heredoc
      #{ERROR_PREFIX} Cannot have more than one mode.
      #{freshrc_path}:1: fresh foo --file --bin

      You may need to run `fresh update` if you're adding a new line,
      or the file you're referencing may have moved or been deleted.
    EOF
  end

  describe 'required args' do
    it 'requires a filename' do
      rc 'fresh'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Filename is required
        #{freshrc_path}:1: fresh

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end

    it 'errors with too many args' do
      rc 'fresh foo bar baz'

      run_fresh error: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Expected 1 or 2 args.
        #{freshrc_path}:1: fresh foo bar baz

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
        Have a look at the repo: <#{format_url 'https://github.com/foo'}>
      EOF
    end
  end

  describe 'private functions' do
    let(:log_path) { sandbox_path + 'out.log' }

    def run_private_function(command, exit_status = true)
      exit_status = system 'bash', '-c', <<-EOF
        set -e
        source bin/fresh
        #{command} > #{log_path}
      EOF
      expect(exit_status).to be exit_status
    end

    describe '_escape' do
      it 'escapes arguments' do
        run_private_function "_escape foo 'bar baz'"
        expect(File.read(log_path)).to eq "foo bar\\ baz\n"
      end
    end
  end
end
