# Builds a disposable config tree for each example and points the app at it.
module ConfigFixtures
  def ignore_file_path
    Pathname.new(Rails.application.config.mcp.ignore_file)
  end

  def project_config_path(project_path)
    Pathname.new(project_path).join('.mcp.json')
  end

  def read_user_config
    JSON.parse(user_config_path.read)
  end

  def redirect_settings_to(root)
    settings.backup_path = root.join('backups')
    settings.ignore_file = root.join('ignore')
    settings.ignore_patterns = []
    settings.user_config_path = root.join('claude.json')
  end

  def restore_settings(original)
    settings.backup_path = original.backup_path
    settings.ignore_file = original.ignore_file
    settings.ignore_patterns = original.ignore_patterns
    settings.user_config_path = original.user_config_path
  end

  def settings
    Rails.application.config.mcp
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
    original = settings.dup

    redirect_settings_to(@tmp_root)
    write_user_config({})

    yield
  ensure
    restore_settings(original)
    FileUtils.rm_rf(@tmp_root)
  end

  def write_ignore_file(*lines)
    path = ignore_file_path
    path.dirname.mkpath
    path.write(lines.flatten.map { |line| "#{line}\n" }.join)

    path
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
