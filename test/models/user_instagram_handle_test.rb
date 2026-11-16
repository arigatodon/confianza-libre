require "test_helper"

# El handle sale del enlace que el usuario puso en su vitrina, que puede venir
# de muchas formas. Etiquetar mal en Instagram significa notificar a un
# desconocido, así que ante la duda se devuelve nil y no se etiqueta a nadie.
class UserInstagramHandleTest < ActiveSupport::TestCase
  def usuario_con(link)
    User.new(link_instagram: link)
  end

  test "extrae el handle de la URL completa" do
    assert_equal "arigatodon", usuario_con("https://instagram.com/arigatodon").instagram_handle
    assert_equal "arigatodon", usuario_con("https://www.instagram.com/arigatodon/").instagram_handle
    assert_equal "arigatodon", usuario_con("instagram.com/arigatodon?igshid=xyz").instagram_handle
  end

  test "acepta el handle escrito a mano, con o sin arroba" do
    assert_equal "arigatodon", usuario_con("@arigatodon").instagram_handle
    assert_equal "arigatodon", usuario_con("arigatodon").instagram_handle
    assert_equal "arigatodon", usuario_con("  ARIGATODON  ").instagram_handle
  end

  test "acepta puntos y guiones bajos, que Instagram permite" do
    assert_equal "lo.zarate_cl", usuario_con("https://instagram.com/lo.zarate_cl").instagram_handle
  end

  test "devuelve nil cuando no hay nada utilizable" do
    assert_nil usuario_con(nil).instagram_handle
    assert_nil usuario_con("").instagram_handle
    assert_nil usuario_con("   ").instagram_handle
    # Un enlace a otra red no es un handle de Instagram.
    assert_nil usuario_con("https://facebook.com/alguien").instagram_handle
    # Nada de espacios ni caracteres raros: etiquetaría cualquier cosa.
    assert_nil usuario_con("mi cuenta").instagram_handle
    assert_nil usuario_con("a" * 31).instagram_handle
  end
end
