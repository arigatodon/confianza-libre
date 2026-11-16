require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @privada  = create_user(username: "vecinaprivada")
    @vitrina  = create_user(username: "vitrinera")
    @vitrina.update!(showcase: true, headline: "Costurera a domicilio")
  end

  test "sin sesión el directorio solo lista vitrinas" do
    get people_path
    assert_response :success
    assert_match "@#{@vitrina.username}", response.body
    assert_match @vitrina.headline, response.body
    assert_no_match "@#{@privada.username}", response.body
    assert_match "vitrinas públicas", response.body
  end

  test "con sesión se ven todos los vecinos" do
    sign_in_as(@privada)
    get people_path
    assert_response :success
    assert_match "@#{@vitrina.username}", response.body
    assert_match "@#{@privada.username}", response.body
  end

  test "la búsqueda también matchea por headline" do
    viewer = create_user(username: "viewerdir")
    sign_in_as(viewer)
    get people_path, params: { q: "costurera" }
    assert_match "@#{@vitrina.username}", response.body
    assert_no_match "@#{@privada.username}", response.body
  end

  test "la búsqueda de vecinos tolera acentos" do
    @vitrina.update!(headline: "Gásfiter y electricista")
    get people_path, params: { q: "gasfiter" }
    assert_response :success
    assert_match "@#{@vitrina.username}", response.body
  end
end
