require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/string/strip.rb'
require 'tmpdir'

ORIGINAL_ENV = ENV.to_hash
ERROR_PREFIX = "\e[4;31mError\e[0m:"
NOTE_PREFIX = "\033[1;33mNote\033[0m:"
FRESH_SUCCESS_LINE = "Your dot files are now \e[1;32mfresh\e[0m."

def sandbox_path
  @sandbox_path ||= Pathname.new(Dir.mktmpdir)
end

def fresh_local_path
  Pathname.new sandbox_path + 'dotfiles'
end

def fresh_path
  Pathname.new sandbox_path + 'fresh'
end

def freshrc_path
  Pathname.new sandbox_path + 'freshrc'
end

def bin_path
  Pathname.new sandbox_path + 'bin'
end

def shell_sh_path
  Pathname.new sandbox_path + 'fresh/build/shell.sh'
end

def git_log_path
  Pathname.new sandbox_path + 'git.log'
end

def curl_log_path
  Pathname.new sandbox_path + 'curl.log'
end

def git_log
  File.read git_log_path
end

def curl_log
  File.read curl_log_path
end

def run_fresh(options = {})
  @stdout = capture(:stdout) do
    @stderr = capture(:stderr) do
      @exit_status = if options[:full_command]
        system(options[:full_command])
      else
        system(*['fresh', Array(options[:command])].flatten.compact)
      end
    end
  end

  if options[:error]
    expect(@stdout).to be_empty
    expect(@stderr).to eq options[:error]
    expect(@exit_status).to be (options[:exit_status].nil? ? false : options[:exit_status])
  elsif options[:error_title]
    expect(@stdout).to be_empty
    expect(
      @stderr.lines.grep(/Error/).join
    ).to eq options[:error_title]
    expect(@exit_status).to be (options[:exit_status].nil? ? false : options[:exit_status])
  elsif options[:success]
    expect(@stderr).to be_empty
    if options[:success].is_a? Regexp
      expect(@stdout).to match options[:success]
    else
      expect(@stdout).to eq options[:success]
    end
    expect(@exit_status).to be (options[:exit_status].nil? ? true : options[:exit_status])
  else
    expect(@stderr).to be_empty
    expect(@stdout).to eq "#{FRESH_SUCCESS_LINE}\n"
    expect(@exit_status).to be (options[:exit_status].nil? ? true : options[:exit_status])
  end
end

def rc(content)
  file_add freshrc_path, content
end

def rc_reset
  FileUtils.rm freshrc_path
end

def file_add(path, content)
  path = File.join(path)
  FileUtils.mkdir_p File.dirname(path)

  if !(content =~ /\n/)
    content = "#{content}\n"
  end

  File.open(path, 'a') do |file|
    file.write(content)
  end
end

def touch(path)
  path = File.join(path)
  mkdir File.dirname(path)
  FileUtils.touch path
end

def mkdir(path)
  FileUtils.mkdir_p path
end

def stub_git
  spec_bin_path = File.join(File.dirname(__FILE__), 'support', 'bin')
  ENV['PATH'] = [spec_bin_path, ENV['PATH']].join(':')
end

def stub_curl(*args)
  error = if args.first.is_a?(Hash) && args.first[:error]
    args.first[:error]
  end

  template = <<-ERB.strip_heredoc
    #!/bin/bash -e

    echo curl >> <%= curl_log_path %>

    for ARG in "$@"; do
      echo "$ARG" >> <%= curl_log_path %>
    done

    <% if error %>
      echo "<%= error %>" >&2
      exit 1
    <% else %>
      <% args.each do |arg| %>
        echo "<%= arg %>"
      <% end %>
    <% end %>
  ERB

  curl_path = bin_path + 'curl'
  File.open(curl_path, 'a') do |file|
    file.write ERB.new(template).result(binding)
  end
  FileUtils.chmod '+x', curl_path
end

def shell_sh_marker_lines
  File.read(shell_sh_path).lines.grep(/^# fresh/).join
end

def expect_shell_sh
  expect(File.executable? shell_sh_path).to be false
  expect(File.writable? shell_sh_path).to be false

  empty_shell_sh = <<-EOF.strip_heredoc
    export PATH="\$HOME/bin:\$PATH"
    export FRESH_PATH="#{fresh_path}"
  EOF

  shell_sh_content_lines = File.read(shell_sh_path).lines

  expect(shell_sh_content_lines[0..1].join).to eq empty_shell_sh

  content = shell_sh_content_lines[3..-1]
  if content
    expect(content.join)
  else
    expect(Struct.new(:default?).new(:default? => true))
  end
end

def expect_readlink(path)
  path = File.expand_path path
  expect(File.readlink path)
end

def format_url(url)
  "\033[4;34m#{url}\033[0m"
end

RSpec.configure do |config|
  config.before do
    %w[home bin].each do |dir|
      FileUtils.mkdir_p File.join(sandbox_path, dir)
    end

    FileUtils.ln_s File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'fresh')), bin_path

    ENV['HOME'] = File.join(sandbox_path, 'home')
    ENV['PATH'] = [bin_path, ENV['PATH']].join(':')

    ENV['SANDBOX_PATH'] = sandbox_path.to_s

    ENV['FRESH_RCFILE'] = freshrc_path.to_s
    ENV['FRESH_PATH'] = fresh_path.to_s
    ENV['FRESH_LOCAL'] = fresh_local_path.to_s
    ENV['FRESH_NO_BIN_CHECK'] = 'true'

    @original_path = Dir.pwd
    Dir.chdir sandbox_path
  end

  config.after do
    ENV.replace(ORIGINAL_ENV)
    FileUtils.rm_r sandbox_path
    Dir.chdir @original_path
  end
end
