require 'tmpdir'
require 'fileutils'
require 'pathname'
require 'benchmark'

ORIGINAL_ENV = ENV.to_hash
TEST_REPO_GZIP = File.expand_path(File.join(File.dirname(__FILE__), 'test_repo.gz'))

def main
  setup

  run_fresh # warm up disk cache

  File.open(freshrc_path, 'w') do |file|
    file.write <<-EOF
      fresh freshshell/fresh bin/fresh --bin
      fresh bashrc
    EOF
  end

  FileUtils.mkdir_p fresh_path + 'source/freshshell/fresh'
  Dir.chdir fresh_path + 'source/freshshell/fresh' do
    system <<-EOF
      git init --quiet
      cat #{TEST_REPO_GZIP} | gunzip | git fast-import --quiet
      git checkout --quiet master
    EOF
  end

  FileUtils.mkdir_p fresh_local_path
  FileUtils.touch fresh_local_path + 'bashrc'

  time = Benchmark.realtime do
    run_fresh
  end

  teardown

  puts "RUNTIME: #{time}"
end

def run_fresh
  system 'fresh > /dev/null'
end

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

def setup
  %w[home bin].each do |dir|
    FileUtils.mkdir_p File.join(sandbox_path, dir)
  end
  FileUtils.ln_s File.expand_path(File.join(File.dirname(__FILE__), '../../bin/fresh')), bin_path

  ENV['HOME'] = File.join(sandbox_path, 'home')
  ENV['PATH'] = [
    bin_path,
    ENV['PATH'].split(':').reject { |path| path =~ Regexp.new(ENV['USER']) }
  ].join(':')

  ENV['FRESH_RCFILE'] = freshrc_path.to_s
  ENV['FRESH_PATH'] = fresh_path.to_s
  ENV['FRESH_LOCAL'] = fresh_local_path.to_s
  ENV['FRESH_NO_BIN_CHECK'] = 'true'

  @original_path = Dir.pwd
  Dir.chdir sandbox_path
end

def teardown
  ENV.replace(ORIGINAL_ENV)
  FileUtils.rm_r sandbox_path
  Dir.chdir @original_path
end

main
