require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  # User agent real que manda la app (prefijo custom + UA del WebView)
  NATIVE_UA = "Confianza Android; Hotwire Native Android; Turbo Native Android " \
              "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " \
              "Chrome/131.0.0.0 Mobile Safari/537.36".freeze

  test "GET /configurations/android_v1 es público y devuelve JSON con reglas" do
    get "/configurations/android_v1"
    assert_response :success

    config = JSON.parse(@response.body)
    assert config["rules"].is_a?(Array)
    assert config["rules"].size >= 4

    # La regla base cubre todas las rutas con el fragment web
    base = config["rules"].first
    assert_equal [ ".*" ], base["patterns"]
    assert_equal "hotwire://fragment/web", base["properties"]["uri"]

    # Formularios como modal
    modal = config["rules"].find { |r| r["patterns"].include?("/new$") }
    assert_equal "modal", modal["properties"]["context"]
  end

  test "la app nativa no recibe el chrome web pero sí el bottom nav" do
    get explore_path, headers: { "User-Agent" => NATIVE_UA }
    assert_response :success
    assert_select "header", count: 0
    assert_select "nav"
  end

  test "el navegador web sí recibe la top bar" do
    get explore_path
    assert_response :success
    assert_select "header"
  end
end
