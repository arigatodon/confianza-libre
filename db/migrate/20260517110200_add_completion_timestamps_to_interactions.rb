class AddCompletionTimestampsToInteractions < ActiveRecord::Migration[8.1]
  # Cierre de interacción con doble confirmación: el status pasa a `completed`
  # sólo cuando sender Y receiver lo confirmaron. Persistimos timestamps en vez
  # de booleans para que la UI muestre cuándo confirmó cada uno.
  def change
    add_column :interactions, :sender_completed_at,   :datetime
    add_column :interactions, :receiver_completed_at, :datetime
  end
end
