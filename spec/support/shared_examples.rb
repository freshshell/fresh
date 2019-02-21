RSpec.shared_examples 'invalid arguments' do |command|
  context 'with invalid arguments' do
    it 'errors' do
      run_fresh command: [command, 'foo', 'bar'], error: "#{ERROR_PREFIX} Invalid arguments\n"
    end
  end
end
