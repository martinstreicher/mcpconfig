# The ignore list: the project directories left out of every listing.
#
# Editing happens a pattern at a time rather than through a textarea of the whole
# file, so a stray keystroke cannot wipe a list someone built up by hand. The file
# itself stays hand-editable for anyone who would rather work there.
class IgnoresController < ApplicationController
  def create
    pattern = params[:pattern].to_s.strip

    if pattern.blank?
      redirect_back_or_to ignores_path, alert: 'Nothing to ignore: the pattern was empty.'
    elsif ignore_list.add(pattern)
      redirect_back_or_to ignores_path, notice: "Ignoring #{pattern}."
    else
      redirect_back_or_to ignores_path, notice: "#{pattern} was already on the list."
    end
  end

  # Two different asks arrive here. Deleting a pattern means "take this line out",
  # which is all it can mean — a wildcard names no single directory. Deleting a
  # path means "show this project again", which may need an exception line rather
  # than a deletion, because the pattern that caught it can be holding others.
  def destroy
    path = params[:path].to_s.strip

    return unignore(path) if path.present?

    pattern = params[:pattern].to_s.strip

    if ignore_list.remove(pattern)
      redirect_back_or_to ignores_path, notice: "Removed #{pattern}."
    else
      redirect_back_or_to ignores_path, alert: "#{pattern} is not in the ignore file."
    end
  end

  def index
    @ignore_list = ignore_list
    @ignored_projects = workspace.ignored_projects
    @visible_count = workspace.projects.size
  end

  private

  def ignore_list
    workspace.ignore_list
  end

  def unignore(path)
    if ignore_list.unignore(path)
      redirect_back_or_to ignores_path, notice: "#{File.basename(path)} is listed again."
    else
      redirect_back_or_to ignores_path, alert: "#{File.basename(path)} was not being ignored."
    end
  end
end
