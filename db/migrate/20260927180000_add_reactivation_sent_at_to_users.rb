# Marca cuándo le escribimos a un usuario para invitarlo a volver, para que
# la rake task usuarios:reactivar no le mande el mismo correo dos veces.
class AddReactivationSentAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :reactivation_sent_at, :datetime
  end
end
