require "test_helper"

class DifusionFacebookTest < ActiveSupport::TestCase
  def con_env(vars)
    previos = vars.transform_values { |_| nil }
    vars.each_key { |k| previos[k] = ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    previos.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "configurada? solo con ambas variables" do
    con_env("FACEBOOK_PAGE_ID" => nil, "FACEBOOK_PAGE_ACCESS_TOKEN" => nil) do
      assert_not Difusion::Facebook.configurada?
    end
    con_env("FACEBOOK_PAGE_ID" => "456", "FACEBOOK_PAGE_ACCESS_TOKEN" => nil) do
      assert_not Difusion::Facebook.configurada?
    end
    con_env("FACEBOOK_PAGE_ID" => "456", "FACEBOOK_PAGE_ACCESS_TOKEN" => "tok") do
      assert Difusion::Facebook.configurada?
    end
  end

  # Subclase que captura las llamadas a la API en vez de salir a la red.
  class FacebookFalso < Difusion::Facebook
    attr_reader :llamadas
    def initialize = @llamadas = []
    def post_form(ruta, **campos)
      @llamadas << [ ruta, campos ]
      { "id" => "456_post-11" }
    end
  end

  test "publica texto + link en el feed de la página y devuelve el id" do
    con_env("FACEBOOK_PAGE_ID" => "456", "FACEBOOK_PAGE_ACCESS_TOKEN" => "tok") do
      fb = FacebookFalso.new
      post_id = fb.publicar(
        tarjeta_png: "x", texto: "Hola",
        url: "https://confianza.world/posts/p",
        tarjeta_url: "https://confianza.world/posts/p/tarjeta.png"
      )

      assert_equal "456_post-11", post_id
      assert_equal "456/feed", fb.llamadas[0][0]
      assert_equal "Hola", fb.llamadas[0][1][:message]
      assert_equal "https://confianza.world/posts/p", fb.llamadas[0][1][:link]
    end
  end
end
