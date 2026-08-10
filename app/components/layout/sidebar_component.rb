module Layout
  class SidebarComponent < ApplicationComponent
    attr_reader :overlap_count, :request_path

    def initialize(request_path:, overlap_count: 0)
      @overlap_count = overlap_count
      @request_path = request_path
    end

    def active?(path)
      return request_path == '/' if path == '/'

      request_path.start_with?(path.split('?').first)
    end

    def link_classes(path)
      base = 'flex items-center justify-between gap-2 rounded-lg px-3 py-2 text-sm transition-colors'

      if active?(path)
        "#{base} bg-slate-900 font-medium text-white dark:bg-slate-100 dark:text-slate-900"
      else
        "#{base} text-slate-600 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800"
      end
    end

    def sections
      [
        { label: 'Overview', path: helpers.root_path },
        { label: 'User servers', path: helpers.servers_path(scope: 'user') },
        { label: 'Projects', path: helpers.projects_path },
        { badge: overlap_count, label: 'Overlaps', path: helpers.overlaps_path },
        { label: 'Backups', path: helpers.backups_path },
        { label: 'Raw JSON', path: helpers.raw_config_path(scope: 'user') }
      ]
    end
  end
end
