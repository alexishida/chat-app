class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_user
    unless logged_in?
      flash[:alert] = "Você deve estar logado para acessar esta página."
      redirect_to login_path
    end
  end
end
