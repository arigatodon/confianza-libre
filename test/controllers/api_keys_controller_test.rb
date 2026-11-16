require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(username: "integradora")
    sign_in_as(@user)
  end

  test "ajustes muestra la sección de API y el formulario" do
    get settings_path
    assert_response :success
    assert_match "Publicar desde tu web", response.body
    assert_match "Crear clave", response.body
  end

  test "crear una clave la muestra una sola vez" do
    assert_difference -> { @user.api_keys.count }, 1 do
      post api_keys_path, params: { api_key: { name: "Sitio Netlify" } }
    end
    assert_redirected_to settings_path(anchor: "api")

    follow_redirect!
    assert_match "cw_", response.body
    assert_match "Sitio Netlify", response.body

    # En la siguiente visita ya solo aparece el prefijo enmascarado.
    get settings_path
    assert_match @user.api_keys.first.masked, response.body
    assert_no_match(/cw_[A-Za-z0-9]{40}/, response.body)
  end

  test "revocar deja la clave inactiva" do
    key, _ = ApiKey.generate_for(@user)
    delete api_key_path(key)
    assert_redirected_to settings_path(anchor: "api")
    assert_not key.reload.active?
  end

  test "no se puede revocar la clave de otro usuario" do
    otra = create_user
    key, _ = ApiKey.generate_for(otra)
    delete api_key_path(key)
    assert_response :not_found
    assert key.reload.active?
  end

  test "sin email verificado no hay formulario" do
    sign_out
    sin_verificar = create_user(email_verified: false)
    sign_in_as(sin_verificar)
    get settings_path
    assert_match "Verifica tu email para poder crear claves", response.body
  end
end
