# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(name: params[:session][:name])
    if user
      session[:user_id] = user.id
      flash[:notice] = "Login efetuado com sucesso!"
      redirect_to root_path
    else
      flash.now[:alert] = "Usuário não encontrado."
      render "new", status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    flash[:notice] = "Logout efetuado."
    redirect_to login_path
  end
end
