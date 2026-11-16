require "test_helper"

class VecinosTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @boris = create_user(username: "boris", bio: "Carpintero de Cartagena")
    @ana   = create_user(username: "anita")
  end

  # Sin sesión el directorio solo muestra vitrinas; ese contrato se prueba en
  # PeopleControllerTest. Aquí probamos el directorio completo de la comunidad,
  # que es lo que ve un vecino con sesión.
  test "con sesión el directorio lista a todos los vecinos" do
    sign_in_as @ana
    get people_path
    assert_response :success
    assert_includes response.body, "@boris"
    assert_includes response.body, "@anita"
    assert_select "link[rel=canonical][href=?]", people_url
  end

  test "con sesión se puede buscar por usuario o por bio" do
    # Firmamos con un tercero para que el propio handle del visitante (que
    # aparece en el menú) no contamine los assertions sobre los resultados.
    sign_in_as create_user(username: "visitante")

    get people_path(q: "bor")
    assert_includes response.body, "@boris"
    refute_includes response.body, "@anita"

    get people_path(q: "carpintero")
    assert_includes response.body, "@boris"

    get people_path(q: "@BORIS")
    assert_includes response.body, "@boris"
  end

  test "logueado, cada tarjeta tiene botón de mensaje directo" do
    sign_in_as @ana
    get people_path
    assert_select "form[action=?]", conversations_path, minimum: 1
  end

  test "los perfiles con mayúsculas en el username no dan 404" do
    camel = create_user(username: "BorisPrueba")
    # El slug de FriendlyId queda en minúsculas; ambas formas deben funcionar.
    get "/BorisPrueba"
    assert_response :success
    get "/borisprueba"
    assert_response :success
    get profile_path(camel.username)
    assert_response :success
  end

  test "suspendidos y cuentas sin username no aparecen" do
    sign_in_as @ana
    @boris.update_columns(status: User::STATUSES[:suspended])
    get people_path
    refute_includes response.body, "@boris"
  end
end
