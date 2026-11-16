require "test_helper"
require "test_helpers/session_test_helper"

class MetricasControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup { setup_economy! }

  test "un usuario común no ve el panel" do
    sign_in_as(create_user)
    get metricas_path
    assert_redirected_to root_path
  end

  test "sin sesión pide login" do
    get metricas_path
    assert_redirected_to new_session_path
  end

  test "un admin ve visitas agrupadas y el embudo" do
    PageView.create!(visited_on: Date.current, path: "/posts/abc", visitor_digest: "a")
    PageView.create!(visited_on: Date.current, path: "/posts/def", visitor_digest: "b", referrer_host: "instagram.com")
    sign_in_as(create_user(admin: true))

    get metricas_path
    assert_response :success
    assert_match "/posts/:id", response.body
    assert_match "instagram.com", response.body
    assert_match "Embudo de activación", response.body
  end
end
