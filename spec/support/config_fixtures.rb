# Builds a disposable config tree for each example and points the app at it.
module ConfigFixtures
  def project_config_path(project_path)
    Pathname.new(project_path).join('.mcp.json')
  end

  def read_user_config
    JSON.parse(user_config_path.read)
  end

  def stdio_server(command: 'npx', args: [], env: {})
    { 'type' => 'stdio', 'command' => command, 'args' => args, 'env' => env }.compact_blank
  end

  def tmp_root
    @tmp_root
  end

  def user_config_path
    Pathname.new(Rails.application.config.mcp.user_config_path)
  end

  def with_isolated_config
    @tmp_root = Pathname.new(Dir.mktmpdir('mcp-config-spec'))
    original = Rails.application.config.mcp.dup

    Rails.application.config.mcp.backup_path = @tmp_root.join('backups')
    Rails.application.config.mcp.user_config_path = @tmp_root.join('claude.json')

    write_user_config({})
    yield
  ensure
    Rails.application.config.mcp.backup_path = original.backup_path
    Rails.application.config.mcp.user_config_path = original.user_config_path
    FileUtils.rm_rf(@tmp_root)
  end

  def write_project_config(project_path, data)
    path = project_config_path(project_path)
    path.dirname.mkpath
    path.write(JSON.pretty_generate(data))

    path
  end

  def write_project_directory(name)
    path = tmp_root.join('projects', name)
    path.mkpath

    path
  end

  def write_user_config(data)
    user_config_path.dirname.mkpath
    user_config_path.write(JSON.pretty_generate(data))

    user_config_path
  end
end
