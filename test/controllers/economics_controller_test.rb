require "test_helper"

class EconomicsControllerTest < ActionDispatch::IntegrationTest
  setup { setup_economy! }

  test "GET /economia es público y devuelve 200" do
    get economics_path
    assert_response :success
    assert_select "h1", /Economía de Confianza/i
  end

  test "muestra la tabla de niveles con el piso del nivel 5" do
    get economics_path
    assert_response :success
    assert_select "h2", /Niveles y cupo/i
    # Piso −2.000 del nivel 5 visible en la tabla.
    assert_match(/2\.000/, @response.body)
  end

  test "explica que el techo es común y muestra su valor vivo" do
    set_param("credit_ceiling", 7_500)
    get economics_path
    assert_match(/el mismo para todas las personas/, @response.body)
    assert_match(/7\.500\u00a0C/, @response.body) # espacio duro entre número y C
  end

  test "expone la antigüedad de 180 días requerida para nivel 5" do
    get economics_path
    assert_match(/180 días/, @response.body)
  end

  test "resalta el nivel del usuario autenticado" do
    user = create_user(username: "econ_viewer")
    sign_in_as(user)
    get economics_path
    assert_response :success
    assert_select "span", text: /tu nivel/
  end

  test "arriba un resumen en palabras; las tablas quedan en «Ver las reglas exactas»" do
    get economics_path
    assert_match "Todos parten de cero.", @response.body
    assert_match "Las reglas se votan.", @response.body
    assert_select "details summary", /Ver las reglas exactas/
    assert_select "details table", minimum: 2
  end
end
