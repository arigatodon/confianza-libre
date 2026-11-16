require "test_helpers/session_test_helper"
require "test_helper"

class ExploreControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "vendedora")
  end

  test "busca por texto con relevancia y tolera acentos" do
    create_post(user: @user, title: "Se ofrece gásfiter a domicilio")
    get explore_path(q: "gasfiter", radius_km: "")
    assert_response :success
    assert_match "gásfiter", response.body
  end

  test "filtra por pedidos vs ofertas" do
    oferta = create_post(user: @user, title: "Ofrezco pintura de casas", pedido: false)
    pedido = create_post(user: @user, title: "Busco quien pinte mi casa", pedido: true)

    get explore_path(market: "pedidos", radius_km: "")
    assert_match pedido.title, response.body
    assert_no_match oferta.title, response.body

    get explore_path(market: "ofertas", radius_km: "")
    assert_match oferta.title, response.body
    assert_no_match pedido.title, response.body
  end

  test "búsqueda sin resultados ofrece publicar lo que se busca" do
    get explore_path(q: "algoquenoexisteenlared", radius_km: "")
    assert_response :success
    assert_match "Publicar lo que busco", response.body
    assert_select "a[href=?]", new_post_path(post: { title: "algoquenoexisteenlared" })
  end

  test "con pocas publicaciones en el radio muestra lo más reciente del resto de la red" do
    create_post(user: @user, title: "Clases de surf en la costa")
    vecino = create_user(latitude: -33.45, longitude: -70.66)
    sign_in_as(vecino)

    get explore_path(radius_km: 5)
    assert_response :success
    assert_match "Sé el primero en tu barrio", response.body
    assert_match "Más en Confianza", response.body
    assert_match "Clases de surf en la costa", response.body
  end
end
