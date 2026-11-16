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
    # Piso -1.000.000 del nivel 5 visible en la tabla.
    assert_match(/1\.000\.000/, @response.body)
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
end
