require "test_helper"

class AchievementsControllerTest < ActionDispatch::IntegrationTest
  setup { ensure_base_categories! }

  test "muestra la página de logros al usuario autenticado" do
    sign_in_as(create_user)
    get achievements_path
    assert_response :success
    assert_select "h1", /logros/i
  end

  test "redirige al login si no hay sesión" do
    get achievements_path
    assert_response :redirect
  end
end
