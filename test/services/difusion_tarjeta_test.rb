require "test_helper"

class DifusionTarjetaTest < ActiveSupport::TestCase
  include Factories

  setup do
    setup_economy!
    @user = create_user(username: "tarjetero")
  end

  test "genera un PNG 1080x1080 sin media" do
    post = create_post(user: @user, title: "Clases de guitarra", description: "Primera clase gratis")
    png  = Difusion::Tarjeta.new(post).render

    imagen = Vips::Image.new_from_buffer(png, "")
    assert_equal 1080, imagen.width
    assert_equal 1080, imagen.height
  end

  test "genera un PNG con foto de fondo" do
    post = create_post(user: @user, title: "Vendo bici")
    foto = Vips::Image.black(400, 300).new_from_image([ 200, 100, 50 ]).cast(:uchar)
                      .copy(interpretation: :srgb)
    post.media.attach(io: StringIO.new(foto.jpegsave_buffer), filename: "f.jpg",
                      content_type: "image/jpeg")

    png    = Difusion::Tarjeta.new(post.reload).render
    imagen = Vips::Image.new_from_buffer(png, "")
    assert_equal 1080, imagen.width
  end

  test "no revienta con caracteres especiales de pango en el título" do
    post = create_post(user: @user, title: "Vendo <cosas> & más \"baratas\"")
    assert_nothing_raised { Difusion::Tarjeta.new(post).render }
  end
end
