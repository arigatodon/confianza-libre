require "test_helper"

class SeoCompartirTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @padrino = create_user(username: "padrino")
  end

  test "el link de invitación prellena el sponsor_code en el signup" do
    get invite_path(code: "padrino")
    assert_response :success
    assert_select "input[name='user[sponsor_code]'][value=?]", "padrino"
  end

  test "el link de invitación admite '@' como prefijo" do
    get invite_path(code: "@padrino")
    assert_response :success
    assert_select "input[name='user[sponsor_code]'][value=?]", "padrino"
  end

  test "el sitemap incluye economía y territorios" do
    territorio = Territory.create!(name: "Comuna de Prueba", country_code: "CL")
    get sitemap_path
    assert_response :success
    assert_includes response.body, economics_url
    assert_includes response.body, territory_url(territorio)
  end

  test "páginas públicas emiten meta description y canonical propios" do
    {
      economics_path    => "créditos comunitarios",
      how_it_works_path => "Guía rápida",
      explore_path      => "mapa",
      posts_path        => "ayuda mutua"
    }.each do |path, fragmento|
      get path
      assert_response :success, "GET #{path}"
      assert_select "meta[name=description][content*=?]", fragmento
      assert_select "link[rel=canonical]", 1
    end
  end

  test "el perfil propio muestra el link de invitación y el ajeno botón de compartir" do
    sign_in_as @padrino
    get profile_path(@padrino.username)
    assert_response :success
    assert_includes response.body, invite_url(code: "padrino")

    otro = create_user(username: "vecino")
    get profile_path(otro.username)
    assert_response :success
    assert_select "[data-controller=share]"
  end
end
