require 'rails_helper'

RSpec.describe OverlapCardComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(overlap: overlap)) }

  let(:project) { write_project_directory('alpha') }

  let(:overlap) do
    write_user_config('mcpServers' => { 'shortcut' => user_definition },
                      'projects' => { project.to_s => {} })
    write_project_config(project, 'mcpServers' => { 'shortcut' => project_definition })

    Mcp::Workspace.current.overlap_report.overlaps.sole
  end

  let(:project_definition) { stdio_server(command: 'bunx') }
  let(:user_definition)    { stdio_server(command: 'npx') }

  def removal_forms
    rendered.css('form[method="post"]').select { |form| form.css('input[name="_method"][value="delete"]').any? }
  end

  it 'offers a Remove for every definition, not just the one in effect', :aggregate_failures do
    expect(removal_forms.size).to eq(2)
    expect(rendered.text).to include('Remove')
  end

  it 'points each Remove at that definition in its own scope', :aggregate_failures do
    actions = removal_forms.pluck('action')

    expect(actions).to include(a_string_matching(/scope=project/))
    expect(actions).to include(a_string_matching(/scope=user/))
    expect(actions).to all(include('shortcut'))
  end

  it 'carries the project path on the project-scoped removal' do
    project_action = removal_forms.pluck('action').find { |action| action.include?('scope=project') }

    expect(CGI.unescape(project_action)).to include(project.to_s)
  end

  describe 'what the confirmation promises' do
    it 'tells a shadowed definition that nothing about what runs will change' do
      confirmations = removal_forms.pluck('data-turbo-confirm')

      expect(confirmations).to include(a_string_matching(/already wins, so what runs does not change/))
    end

    it 'tells the winning definition which one takes over' do
      confirmations = removal_forms.pluck('data-turbo-confirm')

      expect(confirmations).to include(a_string_matching(/user one takes over, so npx runs instead/))
    end
  end

  describe 'an identical duplicate' do
    let(:project_definition) { stdio_server(command: 'npx') }

    it 'still offers a Remove on each copy', :aggregate_failures do
      expect(overlap).to be_duplicate
      expect(removal_forms.size).to eq(2)
    end
  end
end
