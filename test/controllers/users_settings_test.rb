require "test_helper"

# Ajustes de perfil: el fieldset "Tu vitrina" (plantilla, portada, color,
# WhatsApp, horario, links) se renderiza y guarda de punta a punta.
class UsersSettingsTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "vitrinera")
    sign_in_as(@user)
  end

  test "el formulario de ajustes muestra los campos de la vitrina" do
    get settings_path
    assert_response :success
    assert_match "Plantilla", response.body
    assert_match "Tienda / almacén", response.body
    assert_match "WhatsApp de contacto", response.body
    assert_match "Foto de portada", response.body
    assert_match "Color de tu vitrina", response.body
  end

  test "guardar los datos de la vitrina persiste plantilla, contacto y links" do
    patch settings_path, params: { user: {
      email_address: @user.email_address,
      username: @user.username,
      vitrina_plantilla: "comida",
      accent_color: "#924c00",
      whatsapp: "+56 9 8765 4321",
      horario: "Mar a Dom · 12:00 a 23:00",
      link_instagram: "https://instagram.com/lapicada"
    } }

    @user.reload
    assert_equal "comida", @user.vitrina_plantilla
    assert_equal "#924c00", @user.accent_color
    assert_equal "+56987654321", @user.whatsapp
    assert_equal "https://instagram.com/lapicada", @user.link_instagram
    assert_equal "Menú", @user.plantilla[:seccion_posts]
  end

  test "un link con esquema javascript: se rechaza" do
    patch settings_path, params: { user: {
      email_address: @user.email_address,
      username: @user.username,
      link_web: "javascript:alert(1)"
    } }

    assert_nil @user.reload.link_web
  end
end
