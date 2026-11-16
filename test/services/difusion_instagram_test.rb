require "test_helper"

class DifusionInstagramTest < ActiveSupport::TestCase
  def con_env(vars)
    previos = vars.transform_values { |_| nil }
    vars.each_key { |k| previos[k] = ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    previos.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "configurada? solo con ambas variables" do
    con_env("INSTAGRAM_USER_ID" => nil, "INSTAGRAM_ACCESS_TOKEN" => nil) do
      assert_not Difusion::Instagram.configurada?
    end
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => nil) do
      assert_not Difusion::Instagram.configurada?
    end
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      assert Difusion::Instagram.configurada?
    end
  end

  test "exige la URL pública de la tarjeta" do
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      error = assert_raises(RuntimeError) do
        Difusion::Instagram.new.publicar(tarjeta_png: "x", texto: "t", url: "u", tarjeta_url: nil)
      end
      assert_match "tarjeta_url", error.message
    end
  end

  # Subclase que captura las llamadas a la API en vez de salir a la red.
  class InstagramFalso < Difusion::Instagram
    attr_reader :llamadas
    def initialize = @llamadas = []
    def post_form(ruta, **campos)
      @llamadas << [ ruta, campos ]
      ruta.end_with?("/media") ? { "id" => "creation-99" } : { "id" => "media-777" }
    end
    # El contenedor queda listo al toque: no sondear la red en tests.
    def get_field(_id, _campo) = "FINISHED"
  end

  test "publica en dos pasos (crear contenedor + media_publish) y devuelve el media id" do
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      ig = InstagramFalso.new
      media_id = ig.publicar(
        tarjeta_png: "x", texto: "Hola", url: "https://confianza.world/posts/p",
        tarjeta_url: "https://confianza.world/posts/p/tarjeta.png"
      )

      assert_equal "media-777", media_id
      assert_equal "123/media",         ig.llamadas[0][0]
      assert_equal "123/media_publish", ig.llamadas[1][0]
      assert_equal "creation-99",       ig.llamadas[1][1][:creation_id]
      assert_equal "https://confianza.world/posts/p/tarjeta.png", ig.llamadas[0][1][:image_url]
      assert_match "Hola", ig.llamadas[0][1][:caption]
    end
  end

  test "caption sin arroba ni URL, y la invitación va como comentario" do
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      ig = InstagramFalso.new
      ig.publicar(
        tarjeta_png: "x", texto: "Venta: pan · por @igor", url: "https://confianza.world/posts/p",
        tarjeta_url: "https://confianza.world/posts/p/tarjeta.png"
      )

      caption = ig.llamadas[0][1][:caption]
      assert_equal "Venta: pan · por igor", caption
      assert_no_match(/@/, caption)
      assert_no_match(%r{https?://}, caption)

      comentario = ig.llamadas[2]
      assert_equal "media-777/comments", comentario[0]
      assert_equal Difusion::Instagram::COMENTARIO_CTA, comentario[1][:message]
    end
  end

  test "etiqueta al autor cuando declaró su Instagram, sin dejar arrobas del contenido" do
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      ig = InstagramFalso.new
      ig.publicar(
        tarjeta_png: "x", texto: "Venta: pan · por @igor", url: "https://confianza.world/posts/p",
        tarjeta_url: "https://confianza.world/posts/p/tarjeta.png",
        mencion: "arigatodon"
      )

      caption = ig.llamadas[0][1][:caption]
      # El @igor de Confianza se limpia (en Instagram sería otra persona) y se
      # agrega el handle real, que sí etiqueta y notifica al autor.
      assert_equal "Venta: pan · por igor (@arigatodon)", caption
      assert_equal 1, caption.count("@")
    end
  end

  test "sin mención se comporta igual que antes" do
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      ig = InstagramFalso.new
      ig.publicar(
        tarjeta_png: "x", texto: "Venta: pan · por @igor", url: "https://confianza.world/posts/p",
        tarjeta_url: "https://confianza.world/posts/p/tarjeta.png",
        mencion: nil
      )

      assert_equal "Venta: pan · por igor", ig.llamadas[0][1][:caption]
    end
  end

  test "si el comentario falla la publicación no se cae" do
    con_env("INSTAGRAM_USER_ID" => "123", "INSTAGRAM_ACCESS_TOKEN" => "tok") do
      ig = InstagramFalso.new
      def ig.post_form(ruta, **campos)
        raise "comments caído" if ruta.end_with?("/comments")
        super
      end

      media_id = ig.publicar(
        tarjeta_png: "x", texto: "Hola", url: "https://confianza.world/posts/p",
        tarjeta_url: "https://confianza.world/posts/p/tarjeta.png"
      )
      assert_equal "media-777", media_id
    end
  end
end
