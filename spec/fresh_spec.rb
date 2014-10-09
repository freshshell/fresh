require 'spec_helper'

describe 'fresh' do
  describe 'local shell files' do
    it 'builds' do
      add_to_file freshrc_path, 'fresh aliases/git'
      add_to_file freshrc_path, 'fresh aliases/ruby'

      add_to_file [fresh_local_path, 'aliases', 'git'], "alias gs='git status'"
      add_to_file [fresh_local_path, 'aliases', 'git'], "alias gl='git log'"
      add_to_file [fresh_local_path, 'aliases', 'ruby'], "alias rake='bundle exec rake'"

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
      add_to_file freshrc_path, "fresh 'aliases/foo bar'"

      add_to_file [fresh_local_path, 'aliases', 'foo bar'], 'SPACE'
      add_to_file [fresh_local_path, 'aliases', 'foo'], 'foo'
      add_to_file [fresh_local_path, 'aliases', 'bar'], 'bar'

      run_fresh

      expect_shell_sh_to eq <<-EOF.strip_heredoc
        # fresh: aliases/foo bar

        SPACE
      EOF
    end

    it 'builds with globbing' do
      add_to_file freshrc_path, "fresh 'aliases/file*'"

      add_to_file [fresh_local_path, 'aliases', 'file1'], 'file1'
      add_to_file [fresh_local_path, 'aliases', 'file2'], 'file2'
      add_to_file [fresh_local_path, 'aliases', 'other'], 'other'

      run_fresh

      expect_shell_sh_to eq <<-EOF.strip_heredoc
        # fresh: aliases/file1

        file1

        # fresh: aliases/file2

        file2
      EOF
    end

    it 'creates empty output with no freshrc file' do
      expect(File.exists?(shell_sh_path)).to be false

      run_fresh

      expect(File.exists?(shell_sh_path)).to be true
      expect_shell_sh_to be_default
    end

    it 'builds local shell files with --ignore-missing' do
      add_to_file freshrc_path, 'fresh aliases/haskell --ignore-missing'
      FileUtils.mkdir_p fresh_local_path

      run_fresh

      expect_shell_sh_to be_default
    end

    it 'errors with missing local file' do
      add_to_file freshrc_path, 'fresh foo'
      FileUtils.mkdir_p fresh_local_path
      FileUtils.touch File.join(fresh_local_path, 'bar')

      run_fresh stderr: <<-EOF.strip_heredoc
        #{ERROR_PREFIX} Could not find "foo" source file.
        #{freshrc_path}:1: fresh foo

        You may need to run `fresh update` if you're adding a new line,
        or the file you're referencing may have moved or been deleted.
      EOF
    end

    it 'preserves existing compiled files when failing' do
      add_to_file shell_sh_path, 'existing shell.sh'

      add_to_file freshrc_path, 'invalid'
      run_fresh stderr: "#{freshrc_path}: line 1: invalid: command not found\n"

      expect(File.read(shell_sh_path)).to eq "existing shell.sh\n"
    end
  end

  describe 'remote files' do
    it 'clones GitHub repos' do
      add_to_file freshrc_path, 'fresh repo/name file'
      stub_git

      run_fresh

      expect(git_log).to eq <<-EOF.strip_heredoc
        cd #{Dir.pwd}
        git clone https://github.com/repo/name #{sandbox_path}/fresh/source/repo/name
      EOF
      expect(
        File.read(File.join(sandbox_path, 'fresh', 'source', 'repo', 'name', 'file'))
      ).to eq "test data\n"
    end
  end
end
