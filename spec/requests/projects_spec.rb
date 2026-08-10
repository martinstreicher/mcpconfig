require 'rails_helper'

RSpec.describe 'Projects' do
  let(:project) { write_project_directory('alpha') }

  before do
    write_user_config('mcpServers' => { 'postgres' => stdio_server(command: 'npx') },
                      'projects' => { project.to_s => { 'mcpServers' => { 'figma' => stdio_server(command: 'npx') } } })
    write_project_config(project, 'mcpServers' => { 'sentry' => stdio_server(command: 'bunx') })
  end

  describe 'GET /projects' do
    it 'lists projects that define servers', :aggregate_failures do
      get projects_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('alpha')
    end

    it 'can show every remembered path' do
      get projects_path(all: 1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /projects/show' do
    it 'renders both project-scoped sources', :aggregate_failures do
      get project_path(path: project.to_s)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('sentry').and include('figma')
    end

    it 'lists the user servers inherited here' do
      get project_path(path: project.to_s)

      expect(response.body).to include('postgres')
    end

    it 'renders a path that no longer exists on disk', :aggregate_failures do
      write_user_config('projects' => { '/nowhere/gone' => { 'mcpServers' => {} } })

      get project_path(path: '/nowhere/gone')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('no longer exists')
    end
  end

  describe 'POST /projects' do
    it 'starts tracking a directory' do
      fresh = write_project_directory('beta')

      post projects_path, params: { path: fresh.to_s }

      expect(read_user_config['projects']).to have_key(fresh.to_s)
    end

    it 'refuses a path that is not a directory', :aggregate_failures do
      post projects_path, params: { path: '/definitely/not/here' }

      expect(response).to redirect_to(projects_path)
      expect(flash[:alert]).to be_present
    end
  end
end
