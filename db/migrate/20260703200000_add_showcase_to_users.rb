class AddShowcaseToUsers < ActiveRecord::Migration[8.1]
  def change
    # Vitrina pública: el perfil completo visible para cualquiera (incluso sin
    # cuenta) e indexable — para quien ofrece servicios/productos y quiere ser
    # encontrado. Apagada, el perfil completo es solo para usuarios con sesión.
    add_column :users, :showcase, :boolean, default: false, null: false
    add_column :users, :headline, :string
    add_index  :users, :showcase, where: "showcase"
  end
end
