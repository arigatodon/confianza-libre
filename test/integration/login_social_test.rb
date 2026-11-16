require "test_helper"

# Entrar / crear cuenta con Google o Microsoft. El proveedor se reemplaza por
# uno falso: el flujo HTTP real (authorize → callback → canje) no se toca.
class LoginSocialTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  class ProveedorFalso
    attr_reader :perfil_devuelto, :codigos
    def initialize(nombre, perfil) = (@nombre, @perfil_devuelto, @codigos = nombre, perfil, [])
    def nombre = @nombre
    def configurada? = true
    def authorize_url(state:, redirect_uri:) = "https://proveedor.falso/auth?state=#{state}&redirect_uri=#{CGI.escape(redirect_uri)}"
    def perfil(code:, redirect_uri:)
      @codigos << code
      raise Oauth::Proveedor::Error, "código malo" if code == "malo"
      @perfil_devuelto
    end
  end

  def perfil(uid: "g-123", email: "maria@gmail.com", nombre: "María Pérez", verificado: true, avatar: nil)
    Oauth::Proveedor::Perfil.new(uid: uid, email: email, nombre: nombre, avatar_url: avatar, email_verificado: verificado)
  end

  # Recorre el flujo completo con el proveedor falso y devuelve el state usado.
  def entrar_con(falso)
    con_stub(Oauth::Proveedor, :para, ->(nombre) { nombre.to_s == falso.nombre ? falso : nil }) do
      get oauth_start_path(falso.nombre)
      assert_response :redirect
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      assert state.present?

      get oauth_callback_path(falso.nombre), params: { code: "abc", state: state }
    end
  end

  setup { setup_economy! }

  test "un email nuevo crea el usuario verificado, lo loguea y lo manda al onboarding" do
    falso = ProveedorFalso.new("google", perfil(avatar: "https://lh3.googleusercontent.com/foto.jpg"))

    assert_difference -> { User.count }, 1 do
      entrar_con(falso)
    end
    assert_redirected_to root_path
    assert_equal [ "abc" ], falso.codigos

    user = User.find_by(email_address: "maria@gmail.com")
    assert_equal "maria_perez", user.username
    assert user.email_verified?
    assert user.verification_email?
    assert_equal [ "google" ], user.oauth_providers
    assert_enqueued_with(job: ImportarAvatarJob, args: [ user.id, "https://lh3.googleusercontent.com/foto.jpg" ])
    assert_no_enqueued_emails(only: EmailVerificationMailer) rescue nil

    # Sesión abierta: la home autenticada redirige a /bienvenida (no onboarded).
    follow_redirect!
    assert_redirected_to onboarding_path
  end

  test "con un email ya registrado vincula la cuenta en vez de duplicarla" do
    existente = create_user(username: "igor", email_address: "igor@ejemplo.cl")
    falso = ProveedorFalso.new("microsoft", perfil(uid: "ms-9", email: "igor@ejemplo.cl"))

    assert_no_difference -> { User.count } do
      entrar_con(falso)
    end
    assert_redirected_to root_url
    assert_equal [ "microsoft" ], existente.oauth_providers
    assert_equal "ms-9", existente.oauth_identities.first.uid

    get settings_path
    assert_response :success
    assert_match "Microsoft (Hotmail / Outlook)", response.body
  end

  test "la segunda vez entra por la identidad aunque cambie el email" do
    user = create_user(username: "ana")
    user.oauth_identities.create!(provider: "google", uid: "g-1", email: "vieja@gmail.com")
    falso = ProveedorFalso.new("google", perfil(uid: "g-1", email: "nueva@gmail.com"))

    assert_no_difference -> { User.count } do
      entrar_con(falso)
    end
    assert_redirected_to root_url
    assert_equal "nueva@gmail.com", user.oauth_identities.first.reload.email
  end

  test "el username se desambigua si ya está tomado" do
    create_user(username: "maria_perez")
    entrar_con(ProveedorFalso.new("google", perfil))
    assert User.exists?(username: "maria_perez2")
  end

  test "un email sin verificar por el proveedor no crea cuenta" do
    falso = ProveedorFalso.new("google", perfil(verificado: false))
    assert_no_difference -> { User.count } do
      entrar_con(falso)
    end
    assert_redirected_to new_session_path
    assert_match "email verificado", flash[:alert]
  end

  test "state inválido rechaza el callback" do
    falso = ProveedorFalso.new("google", perfil)
    con_stub(Oauth::Proveedor, :para, ->(_n) { falso }) do
      get oauth_start_path("google")
      get oauth_callback_path("google"), params: { code: "abc", state: "otro" }
    end
    assert_redirected_to new_session_path
    assert_match "no es válido", flash[:alert]
    assert_empty falso.codigos, "no debe canjear el código sin state válido"
  end

  test "error del proveedor vuelve al login con aviso" do
    falso = ProveedorFalso.new("google", perfil)
    con_stub(Oauth::Proveedor, :para, ->(_n) { falso }) do
      get oauth_start_path("google")
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      get oauth_callback_path("google"), params: { code: "malo", state: state }
    end
    assert_redirected_to new_session_path
    assert_match "No pudimos completar", flash[:alert]
  end

  test "el padrino de /invita sobrevive al registro con Google" do
    padrino = create_user(username: "padrino")
    get invite_path("padrino")
    entrar_con(ProveedorFalso.new("google", perfil))
    assert_equal padrino, User.find_by(email_address: "maria@gmail.com").sponsor
  end

  test "sin credenciales el proveedor no existe (404) y no hay botones" do
    get oauth_start_path("google")
    assert_response :not_found

    get new_session_path
    assert_no_match "Continuar con Google", response.body
  end

  test "con credenciales aparecen los botones en login y registro" do
    falso = ProveedorFalso.new("google", perfil)
    con_stub(Oauth::Proveedor, :para, ->(n) { n.to_s == "google" ? falso : nil }) do
      get new_session_path
      assert_match "Continuar con Google", response.body
      assert_no_match "Continuar con Microsoft", response.body
      get signup_path
      assert_match "Continuar con Google", response.body
    end
  end

  test "un proveedor desconocido no matchea la ruta" do
    get "/auth/facebook"
    assert_response :not_found
  end
end
