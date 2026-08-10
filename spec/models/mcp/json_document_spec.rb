require 'rails_helper'

RSpec.describe Mcp::JsonDocument do
  subject(:document) { described_class.new(path) }

  let(:path) { tmp_root.join('sample.json') }

  describe '#data' do
    it 'returns an empty hash when the file is missing' do
      expect(document.data).to eq({})
    end

    it 'reports the parser message instead of raising on malformed JSON', :aggregate_failures do
      path.write('{ "broken": ')

      expect(document.data).to eq({})
      expect(document.parse_error).to be_present
      expect(document).not_to be_valid
    end
  end

  describe '#write' do
    before { path.write(JSON.pretty_generate('keep' => 'me')) }

    it 'preserves keys it was not asked to change' do
      document.write(document.data.merge('added' => true))

      expect(JSON.parse(path.read)).to eq('added' => true, 'keep' => 'me')
    end

    it 'backs up the previous contents first', :aggregate_failures do
      document.write({ 'replaced' => true })
      backup = Mcp::Backup.all.sole

      expect(backup.source_path).to eq(path)
      expect(JSON.parse(backup.contents)).to eq('keep' => 'me')
    end

    it 'keeps the file permissions it found' do
      path.chmod(0o600)
      document.write({ 'changed' => true })

      expect(path.stat.mode & 0o777).to eq(0o600)
    end

    it 'leaves no temporary files behind' do
      document.write({ 'changed' => true })

      leftovers = path.dirname.children.map { |child| child.basename.to_s }.grep(/\.tmp\z/)

      expect(leftovers).to be_empty
    end
  end

  describe 'backup retention' do
    before do
      path.write('{}')
      allow(Rails.application.config.mcp).to receive(:backup_retention).and_return(2)
    end

    it 'prunes the oldest beyond the retention limit' do
      3.times { |index| document.write({ 'generation' => index }) }

      expect(Mcp::Backup.all.size).to eq(2)
    end
  end
end
