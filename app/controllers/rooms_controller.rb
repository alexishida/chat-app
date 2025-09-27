class RoomsController < ApplicationController
  before_action :require_user

  def index
    @rooms = Room.all
  end

  def show
    @room = Room.find(params[:id])
    @message = Message.new(room: @room)
    @messages = @room.messages.includes(:user)
  end
end
