require "test_helper"
require "test_helpers/session_test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "la portada anónima se sirve en HTML" do
    get root_path
    assert_response :success
    assert_select "html"
  end

  test "pedir la portada como JSON responde 406 en vez de explotar" do
    get root_path, headers: { "Accept" => "application/json" }
    assert_response :not_acceptable
  end

  test "pedir una página de marketing con extensión ajena responde 406" do
    get "/como-funciona.xml"
    assert_response :not_acceptable
  end
end

class ApiDocsPageTest < ActionDispatch::IntegrationTest
  test "la documentación de la API es pública y lista las categorías" do
    ensure_base_categories!
    get api_docs_path
    assert_response :success
    assert_match "Publica en Confianza desde tu propia web", response.body
    assert_match "/api/v1/posts", response.body
    assert_match "servicios", response.body
    assert_no_match "Cliente", response.body, "la categoría interna no se ofrece por API"
  end
end

class HomeFeedTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    # Vive en Santiago; la única publicación está en la costa (~100 km).
    @yo = create_user(latitude: -33.45, longitude: -70.66)
    @lejos = create_post(user: create_user, title: "Clases de surf en la costa")
    sign_in_as(@yo)
  end

  test "con poco cerca, el feed completa con lo reciente de la red" do
    get root_path
    assert_response :success
    assert_match "Más en Confianza", response.body
    assert_match "Clases de surf en la costa", response.body
  end

  test "invita a crear la vitrina a quien no la tiene y siempre muestra el link de invitación" do
    get root_path
    assert_match "Crear mi vitrina", response.body
    assert_match invite_url(code: @yo.username), response.body

    @yo.update!(showcase: true)
    get root_path
    assert_no_match "Crear mi vitrina", response.body
  end
end
