require "test_helper"
require "test_helpers/session_test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    setup_economy!
  end

  test "GET /sitemap.xml accesible sin sesión" do
    get sitemap_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match "<urlset", response.body
    assert_match "<loc>http", response.body
  end

  test "incluye posts publicados visibles" do
    user = create_user(username: "seller")
    post = create_post(user: user)
    get sitemap_path
    assert_response :success
    assert_match post_url(post), response.body
  end

  test "incluye perfiles vitrina y excluye los privados" do
    vitrina = create_user(username: "carolina")
    vitrina.update!(showcase: true)
    privada = create_user(username: "reservada")
    get sitemap_path
    assert_response :success
    assert_match "/carolina", response.body
    assert_no_match "/reservada", response.body
  end
end
