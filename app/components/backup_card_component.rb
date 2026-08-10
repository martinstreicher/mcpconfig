class BackupCardComponent < ApplicationComponent
  attr_reader :backup, :latest

  def initialize(backup:, latest: false)
    @backup = backup
    @latest = latest
  end

  def size_label
    number_to_human_size(backup.byte_size)
  end
end
