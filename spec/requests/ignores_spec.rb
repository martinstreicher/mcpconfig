require 'rails_helper'

RSpec.describe 'Ignored projects' do
  let(:kept)    { write_project_directory('keeper') }
  let(:skipped) { write_project_directory('scratch') }

  before do
    write_project_config(kept, 'mcpServers' => { 'postgres' => stdio_server })
    write_project_config(skipped, 'mcpServers' => { 'redis' => stdio_server })

    write_user_config('projects' => { kept.to_s => {}, skipped.to_s => {} })
  end

  describe 'GET /ignored' do
    it 'lists the patterns and what they are hiding', :aggregate_failures do
      write_ignore_file(skipped.to_s)

      get ignores_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(skipped.to_s)
    end

    it 'says so when nothing is ignored' do
      get ignores_path

      expect(response.body).to include('Nothing is being ignored')
    end
  end

  describe 'POST /ignored' do
    it 'hides the project from every listing without touching its config', :aggregate_failures do
      post ignores_path, params: { pattern: skipped.to_s }

      expect(Mcp::IgnoreList.current.file_patterns).to eq([skipped.to_s])
      expect(project_config_path(skipped).read).to include('redis')

      get projects_path(all: 1)

      expect(response.body).to include('keeper')
      expect(response.body).not_to include('>scratch<')
    end

    it 'accepts a wildcard pattern' do
      post ignores_path, params: { pattern: "#{tmp_root.join('projects')}/*" }

      expect(Mcp::IgnoreList.current.keep([kept.to_s, skipped.to_s])).to be_empty
    end

    it 'refuses an empty pattern', :aggregate_failures do
      post ignores_path, params: { pattern: '  ' }

      expect(flash[:alert]).to include('empty')
      expect(Mcp::IgnoreList.current).not_to be_any
    end

    it 'says the pattern was already there rather than writing it twice', :aggregate_failures do
      write_ignore_file(skipped.to_s)

      post ignores_path, params: { pattern: skipped.to_s }

      expect(flash[:notice]).to include('already')
      expect(Mcp::IgnoreList.current.file_patterns).to eq([skipped.to_s])
    end
  end

  describe 'DELETE /ignored' do
    it 'removes a pattern by its text', :aggregate_failures do
      write_ignore_file('node_modules', skipped.to_s)

      delete ignores_path, params: { pattern: 'node_modules' }

      expect(Mcp::IgnoreList.current.file_patterns).to eq([skipped.to_s])
      expect(flash[:notice]).to include('Removed')
    end

    it 'reports a pattern the file does not hold' do
      delete ignores_path, params: { pattern: 'node_modules' }

      expect(flash[:alert]).to include('not in the ignore file')
    end

    it 'shows a project again by dropping the line that named it', :aggregate_failures do
      write_ignore_file(skipped.to_s)

      delete ignores_path, params: { path: skipped.to_s }

      expect(Mcp::IgnoreList.current.file_patterns).to be_empty
      expect(flash[:notice]).to include('listed again')
    end

    it 'shows a project again by adding an exception when a wildcard hid it', :aggregate_failures do
      write_ignore_file("#{tmp_root.join('projects')}/*")

      delete ignores_path, params: { path: skipped.to_s }

      list = Mcp::IgnoreList.current

      expect(list.ignore?(skipped.to_s)).to be(false)
      expect(list.ignore?(kept.to_s)).to be(true)
    end

    it 'reports a path that was not being ignored' do
      delete ignores_path, params: { path: skipped.to_s }

      expect(flash[:alert]).to include('was not being ignored')
    end
  end

  describe 'the reach of an ignored project' do
    before { write_ignore_file(skipped.to_s) }

    it 'is gone from the dashboard and the project count', :aggregate_failures do
      get root_path

      expect(response.body).to include('keeper')
      expect(response.body).not_to include('>scratch<')
    end

    it 'is gone from the overlap report and the local server list', :aggregate_failures do
      workspace = Mcp::Workspace.current

      expect(workspace.projects.map(&:path)).to eq([kept.to_s])
      expect(workspace.ignored_projects.map(&:path)).to eq([skipped.to_s])
      expect(workspace.stats[:projects]).to eq(1)
    end

    it 'is still reachable by its own URL, so a bookmark does not break' do
      get project_path(path: skipped.to_s)

      expect(response).to have_http_status(:ok)
    end
  end
end
