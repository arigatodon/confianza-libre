require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "vecinapriv", bio: "Mi bio personal que no es para la web abierta")
  end

  test "sin sesión, un perfil sin vitrina muestra la tarjeta mínima con noindex" do
    get profile_path(@user.username)
    assert_response :success

    assert_no_match @user.bio, response.body
    assert_match "participa en privado", response.body
    assert_match "noindex", response.body
    assert_match "@#{@user.username}", response.body
  end

  test "con sesión se ve el perfil completo" do
    viewer = create_user(username: "viewerx")
    sign_in_as(viewer)

    get profile_path(@user.username)
    assert_response :success
    assert_match @user.bio, response.body
    assert_no_match "participa en privado", response.body
  end

  test "una vitrina se ve completa sin sesión y sin noindex" do
    @user.update!(showcase: true, headline: "Gásfiter con 10 años de oficio")

    get profile_path(@user.username)
    assert_response :success
    assert_match @user.bio, response.body
    assert_match @user.headline, response.body
    assert_no_match "noindex", response.body
    assert_no_match "participa en privado", response.body
  end

  test "las publicaciones del perfil se ven igual sin sesión (ya son públicas)" do
    post = create_post(user: @user, title: "Vendo bicicleta usada")
    get profile_path(@user.username)
    assert_match post.title, response.body
  end

  test "la vitrina con plantilla muestra el título de sección y el botón de WhatsApp" do
    @user.update!(showcase: true, vitrina_plantilla: "tienda",
                  whatsapp: "+56912345678", horario: "Lun a Sáb · 9:00 a 19:00")

    get profile_path(@user.username)
    assert_response :success
    assert_match "Catálogo", response.body
    assert_match "wa.me/56912345678", response.body
    assert_match "Pedir por WhatsApp", response.body
    assert_match "Lun a Sáb", response.body
  end

  test "sin datos de vitrina no aparece bloque de contacto" do
    get profile_path(@user.username)
    # El share genérico usa wa.me/?text= (sin número); el contacto directo
    # de la vitrina es wa.me/<número> — eso es lo que no debe estar.
    assert_no_match %r{wa\.me/\d}, response.body
  end

  test "el QR de la vitrina responde un PNG válido" do
    get profile_qr_path(@user.username)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b), "el cuerpo debe ser un PNG"
  end
end
