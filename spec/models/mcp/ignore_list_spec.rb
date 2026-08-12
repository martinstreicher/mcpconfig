require 'rails_helper'

RSpec.describe Mcp::IgnoreList do
  subject(:list) { described_class.new }

  def ignoring(*lines)
    write_ignore_file(*lines)

    described_class.new
  end

  describe 'with no file at all' do
    it 'ignores nothing', :aggregate_failures do
      expect(list).not_to be_any
      expect(list.ignore?('/Users/someone/code/app')).to be(false)
      expect(list.patterns).to be_empty
    end
  end

  describe 'a bare name, which .gitignore matches at any depth' do
    subject(:list) { ignoring('node_modules') }

    it 'matches the directory wherever it sits', :aggregate_failures do
      expect(list.ignore?('/Users/me/code/node_modules')).to be(true)
      expect(list.ignore?('/opt/node_modules')).to be(true)
      expect(list.ignore?('/node_modules')).to be(true)
    end

    it 'matches everything beneath it, the way ignoring a directory does' do
      expect(list.ignore?('/Users/me/code/node_modules/pkg/nested')).to be(true)
    end

    it 'does not match a name that merely contains it', :aggregate_failures do
      expect(list.ignore?('/Users/me/code/node_modules_old')).to be(false)
      expect(list.ignore?('/Users/me/my_node_modules')).to be(false)
    end
  end

  describe 'an absolute pattern' do
    subject(:list) { ignoring('/Users/me/scratch') }

    it 'matches only that path and its contents', :aggregate_failures do
      expect(list.ignore?('/Users/me/scratch')).to be(true)
      expect(list.ignore?('/Users/me/scratch/thing')).to be(true)
      expect(list.ignore?('/Users/you/scratch')).to be(false)
    end

    it 'does not match the same name somewhere else' do
      expect(list.ignore?('/tmp/Users/me/scratch')).to be(false)
    end
  end

  describe 'a path-shaped pattern with no leading slash' do
    subject(:list) { ignoring('code/vendor') }

    it 'matches at the end of a path, on a segment boundary', :aggregate_failures do
      expect(list.ignore?('/Users/me/code/vendor')).to be(true)
      expect(list.ignore?('/srv/code/vendor')).to be(true)
      expect(list.ignore?('/Users/me/code/vendor/gems')).to be(true)
    end

    it 'does not match a partial segment' do
      expect(list.ignore?('/Users/me/mycode/vendor')).to be(false)
    end
  end

  describe 'a leading ~' do
    subject(:list) { ignoring('~/scratch') }

    it 'expands to the home directory', :aggregate_failures do
      expect(list.ignore?(File.join(Dir.home, 'scratch'))).to be(true)
      expect(list.ignore?(File.join(Dir.home, 'scratch', 'inner'))).to be(true)
      expect(list.ignore?('/elsewhere/scratch')).to be(false)
    end
  end

  describe 'wildcards' do
    it 'keeps * inside a single directory name', :aggregate_failures do
      list = ignoring('/Users/me/tmp*')

      expect(list.ignore?('/Users/me/tmp')).to be(true)
      expect(list.ignore?('/Users/me/tmpdir')).to be(true)
      expect(list.ignore?('/Users/me/other/tmpdir')).to be(false)
    end

    it 'lets * stand in for one name in the middle of a path', :aggregate_failures do
      list = ignoring('/Users/me/code/*/vendor')

      expect(list.ignore?('/Users/me/code/app/vendor')).to be(true)
      expect(list.ignore?('/Users/me/code/app/deep/vendor')).to be(false)
    end

    it 'lets ** cross directory names', :aggregate_failures do
      list = ignoring('/Users/me/code/**/vendor')

      expect(list.ignore?('/Users/me/code/app/vendor')).to be(true)
      expect(list.ignore?('/Users/me/code/app/deep/vendor')).to be(true)
      expect(list.ignore?('/Users/me/code/vendor')).to be(true)
    end

    it 'takes a trailing ** as everything below', :aggregate_failures do
      list = ignoring('/Users/me/experiments/**')

      expect(list.ignore?('/Users/me/experiments/one')).to be(true)
      expect(list.ignore?('/Users/me/experiments/one/two')).to be(true)
      expect(list.ignore?('/Users/me/other')).to be(false)
    end

    it 'matches exactly one character with ?', :aggregate_failures do
      list = ignoring('/Users/me/scratch?')

      expect(list.ignore?('/Users/me/scratch1')).to be(true)
      expect(list.ignore?('/Users/me/scratch')).to be(false)
      expect(list.ignore?('/Users/me/scratch12')).to be(false)
    end

    it 'reads a bracket expression', :aggregate_failures do
      list = ignoring('/Users/me/scratch[12]')

      expect(list.ignore?('/Users/me/scratch1')).to be(true)
      expect(list.ignore?('/Users/me/scratch2')).to be(true)
      expect(list.ignore?('/Users/me/scratch3')).to be(false)
    end

    it 'reads a negated bracket expression', :aggregate_failures do
      list = ignoring('/Users/me/scratch[!12]')

      expect(list.ignore?('/Users/me/scratch3')).to be(true)
      expect(list.ignore?('/Users/me/scratch1')).to be(false)
    end
  end

  describe 'comments and blank lines' do
    subject(:list) { ignoring('# a comment', '', '   ', 'node_modules', '  # indented comment') }

    it 'carry no rules', :aggregate_failures do
      expect(list.patterns).to eq(%w[node_modules])
      expect(list.ignore?('/Users/me/node_modules')).to be(true)
    end

    it 'does not treat a comment as a path' do
      expect(list.ignore?('/Users/me/# a comment')).to be(false)
    end
  end

  describe 'a leading ! putting something back' do
    it 'lets a later line override an earlier one', :aggregate_failures do
      list = ignoring('~/code/*', '!~/code/keeper')

      expect(list.ignore?(File.join(Dir.home, 'code', 'other'))).to be(true)
      expect(list.ignore?(File.join(Dir.home, 'code', 'keeper'))).to be(false)
    end

    it 'gives the last match the final say, even when that re-ignores', :aggregate_failures do
      list = ignoring('~/code/*', '!~/code/keeper', '~/code/keeper')

      expect(list.ignore?(File.join(Dir.home, 'code', 'keeper'))).to be(true)
    end

    it 'is a literal ! when escaped' do
      list = ignoring('\!weird')

      expect(list.ignore?('/Users/me/!weird')).to be(true)
    end
  end

  describe 'the departures from git this app makes on purpose' do
    it 'ignores case, because a path differing only in case is the same directory' do
      list = ignoring('~/Scratch')

      expect(list.ignore?(File.join(Dir.home, 'scratch'))).to be(true)
    end

    it 'accepts a trailing slash, since every entry is a directory anyway' do
      list = ignoring('/Users/me/scratch/')

      expect(list.ignore?('/Users/me/scratch')).to be(true)
    end
  end

  describe 'a bracket that never closes' do
    subject(:list) { ignoring('/Users/me/[') }

    it 'is taken as the character itself', :aggregate_failures do
      expect(list.ignore?('/Users/me/[')).to be(true)
      expect(list.ignore?('/Users/me/anything')).to be(false)
    end
  end

  describe 'a pattern that cannot be compiled' do
    # An empty range is one of the few things fnmatch tolerates and Regexp will
    # not, which makes it the way to reach the fallback.
    subject(:list) { ignoring('/Users/me/scratch[z-a]', 'node_modules') }

    it 'matches nothing rather than taking the rest of the list down with it', :aggregate_failures do
      expect(list.ignore?('/Users/me/scratch1')).to be(false)
      expect(list.ignore?('/Users/me/scratch[z-a]')).to be(false)
      expect(list.ignore?('/Users/me/node_modules')).to be(true)
    end
  end

  describe 'patterns from the environment' do
    subject(:list) { described_class.new(extra_patterns: ['~/from-env']) }

    it 'apply alongside the file, and are reported separately', :aggregate_failures do
      write_ignore_file('~/from-file')
      list = described_class.new(extra_patterns: ['~/from-env'])

      expect(list.ignore?(File.join(Dir.home, 'from-env'))).to be(true)
      expect(list.ignore?(File.join(Dir.home, 'from-file'))).to be(true)
      expect(list.environment_patterns).to eq(%w[~/from-env])
      expect(list.file_patterns).to eq(%w[~/from-file])
    end
  end

  describe '#keep and #ignored' do
    subject(:list) { ignoring('~/scratch') }

    let(:paths) { [File.join(Dir.home, 'scratch'), '/Users/me/app'] }

    it 'split the paths between them', :aggregate_failures do
      expect(list.keep(paths)).to eq(['/Users/me/app'])
      expect(list.ignored(paths)).to eq([File.join(Dir.home, 'scratch')])
    end
  end

  describe '#add' do
    it 'creates the file with a syntax header the first time', :aggregate_failures do
      expect(list.add('/Users/me/scratch')).to be(true)
      expect(list.file_patterns).to eq(['/Users/me/scratch'])
      expect(ignore_file_path.read).to include('.gitignore syntax').and include('/Users/me/scratch')
    end

    it 'appends without disturbing the comments already there', :aggregate_failures do
      list = ignoring('# mine', 'node_modules')
      list.add('~/scratch')

      expect(ignore_file_path.read.split("\n")).to eq(['# mine', 'node_modules', '~/scratch'])
    end

    it 'refuses a duplicate and a blank', :aggregate_failures do
      list = ignoring('node_modules')

      expect(list.add('node_modules')).to be(false)
      expect(list.add('  ')).to be(false)
    end

    it 'takes effect immediately, without a reload' do
      list.add('~/scratch')

      expect(list.ignore?(File.join(Dir.home, 'scratch'))).to be(true)
    end
  end

  describe '#remove' do
    it 'takes the line out and leaves the rest', :aggregate_failures do
      list = ignoring('# mine', 'node_modules', '~/scratch')

      expect(list.remove('node_modules')).to be(true)
      expect(ignore_file_path.read.split("\n")).to eq(['# mine', '~/scratch'])
      expect(list.ignore?('/Users/me/node_modules')).to be(false)
    end

    it 'reports a line that was never there' do
      expect(ignoring('node_modules').remove('~/scratch')).to be(false)
    end
  end

  describe '#unignore' do
    it 'drops the line when the path was named outright', :aggregate_failures do
      list = ignoring('/Users/me/scratch', 'node_modules')

      expect(list.unignore('/Users/me/scratch')).to be(true)
      expect(list.file_patterns).to eq(%w[node_modules])
    end

    it 'drops a ~ line whose expansion is the path', :aggregate_failures do
      list = ignoring('~/scratch')

      expect(list.unignore(File.join(Dir.home, 'scratch'))).to be(true)
      expect(list.file_patterns).to be_empty
    end

    it 'adds an exception when a wildcard is what caught it', :aggregate_failures do
      list = ignoring('~/code/*')
      keeper = File.join(Dir.home, 'code', 'keeper')

      expect(list.unignore(keeper)).to be(true)
      expect(list.file_patterns).to eq(['~/code/*', "!#{keeper}"])
      expect(list.ignore?(keeper)).to be(false)
      expect(list.ignore?(File.join(Dir.home, 'code', 'other'))).to be(true)
    end

    it 'reports a path that was not being ignored' do
      expect(ignoring('node_modules').unignore('/Users/me/app')).to be(false)
    end
  end
end
