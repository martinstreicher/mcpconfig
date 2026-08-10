require 'rails_helper'

RSpec.describe ServerCardComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(server: server)) }

  let(:server) do
    Mcp::Server.from_config(
      'shortcut',
      { 'command' => 'npx', 'env' => { 'SHORTCUT_API_TOKEN' => 'sct_abcdefghijklmnop', 'LOG_LEVEL' => 'debug' } },
      scope: Mcp::Scope.user
    )
  end

  it 'shows the server name and command' do
    expect(rendered.text).to include('shortcut').and include('npx')
  end

  it 'masks a value whose name looks like a credential', :aggregate_failures do
    masked = rendered.css('[data-reveal-target="masked"]').text

    expect(masked).to include('sct_').and include('•')
    expect(masked).not_to include('sct_abcdefghijklmnop')
  end

  it 'leaves an ordinary value alone' do
    expect(rendered.text).to include('debug')
  end

  it 'colour-codes the card by scope' do
    expect(rendered.css('.bg-indigo-500')).to be_present
  end
end
