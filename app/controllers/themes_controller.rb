class ThemesController < ApplicationController
  def update
    choice = params[:theme].to_s
    cookies[:theme] = { httponly: false, same_site: :lax, value: choice } if Theme.valid?(choice)

    redirect_back fallback_location: root_path
  end
end
