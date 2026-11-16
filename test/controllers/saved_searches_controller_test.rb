require "test_helper"

class SavedSearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "guardador")
    sign_in_as(@user)
  end

  test "guarda una búsqueda con los filtros actuales" do
    servicios = Category.find_by!(name: "Servicios")
    assert_difference -> { @user.saved_searches.count }, 1 do
      post saved_searches_path, params: { q: "gasfiter", category_id: servicios.id,
                                           market: "pedidos", radius_km: "10" }
    end
    s = @user.saved_searches.last
    assert_equal "gasfiter", s.query
    assert_equal servicios.id, s.category_id
    assert_equal "pedidos", s.market
    assert_equal 10, s.radius_km
  end

  test "puede borrar una alerta propia" do
    s = @user.saved_searches.create!(query: "algo")
    assert_difference -> { @user.saved_searches.count }, -1 do
      delete saved_search_path(s)
    end
  end

  test "no puede borrar la alerta de otro" do
    otro = create_user(username: "otro_dueno")
    ajena = otro.saved_searches.create!(query: "secreto")
    delete saved_search_path(ajena)
    assert_response :not_found
    assert SavedSearch.exists?(ajena.id)
  end

  test "no permite más de 10 alertas" do
    10.times { |n| @user.saved_searches.create!(query: "a#{n}") }
    assert_no_difference -> { @user.saved_searches.count } do
      post saved_searches_path, params: { q: "una mas" }
    end
    assert_redirected_to explore_path
  end

  test "el listado de alertas aparece en ajustes" do
    @user.saved_searches.create!(query: "gasfiter")
    get settings_path
    assert_match "Mis alertas", response.body
    assert_match "gasfiter", response.body
  end
end
