class Message < ApplicationRecord
  belongs_to :room
  belongs_to :user

  after_create_commit { broadcast_to_room }

  private

  def broadcast_to_room
    broadcast_append_to self.room, target: "messages", partial: "messages/message", locals: { message: self, current_user: self.user }
  end
end
