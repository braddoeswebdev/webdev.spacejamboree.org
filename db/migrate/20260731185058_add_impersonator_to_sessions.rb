class AddImpersonatorToSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :sessions, :impersonator, foreign_key: { to_table: :sessions }
  end
end
