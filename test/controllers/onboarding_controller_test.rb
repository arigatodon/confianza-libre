require "test_helper"
require "test_helpers/session_test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  include SessionTestHelper

  setup do
    setup_economy!
    @user = create_user(username: "newbie", email_verified: true, onboarded: false)
    sign_in_as(@user)
  end

  test "GET /bienvenida muestra el primer paso por default" do
    get onboarding_path
    assert_response :success
    assert_match "Paso 1 de", response.body
  end

  test "GET /bienvenida?step=3 muestra el paso 3" do
    get onboarding_path(step: 3)
    assert_response :success
    assert_match "Paso 3 de", response.body
  end

  test "step fuera de rango cae al 1" do
    get onboarding_path(step: 999)
    assert_response :success
    assert_match "Paso 1 de", response.body
  end

  test "POST /bienvenida/completar marca onboarding_completed_at y lleva a crear la vitrina" do
    assert_nil @user.reload.onboarding_completed_at
    post complete_onboarding_path
    assert_redirected_to onboarding_vitrina_path
    assert @user.reload.onboarding_completed_at.present?
  end

  test "POST /bienvenida/saltar también marca completed" do
    post skip_onboarding_path
    assert_redirected_to onboarding_vitrina_path
    assert @user.reload.onboarding_completed_at.present?
  end

  test "quien ya tiene vitrina pública se salta ese paso" do
    @user.update!(showcase: true)
    post skip_onboarding_path
    assert_redirected_to explore_path
  end

  test "GET /bienvenida/vitrina muestra el formulario con la vitrina marcada" do
    get onboarding_vitrina_path
    assert_response :success
    assert_select "form[action=?]", onboarding_vitrina_path
    assert_select "input[type=checkbox][name='user[showcase]'][checked]"
  end

  test "PATCH /bienvenida/vitrina publica la vitrina y lleva al perfil" do
    patch onboarding_vitrina_path, params: { user: {
      vitrina_plantilla: "oficio", headline: "Gásfiter en Ñuñoa",
      whatsapp: "+56 9 1234 5678", horario: "Lun a Vie", showcase: "1"
    } }
    assert_redirected_to profile_path(@user.username, vitrina_nueva: 1)
    @user.reload
    assert @user.showcase?
    assert_equal "oficio", @user.vitrina_plantilla
    assert_equal "+56912345678", @user.whatsapp

    follow_redirect!
    assert_match "Tu vitrina ya está en internet", response.body
  end

  test "PATCH /bienvenida/vitrina sin marcar la casilla deja el perfil privado" do
    patch onboarding_vitrina_path, params: { user: { headline: "Clases de piano", showcase: "0" } }
    assert_not @user.reload.showcase?
    assert_equal "Clases de piano", @user.headline
  end

  test "PATCH /bienvenida/vitrina con datos inválidos re-renderiza con errores" do
    patch onboarding_vitrina_path, params: { user: { headline: "Almacén", whatsapp: "abc", showcase: "1" } }
    assert_response :unprocessable_entity
    assert_not @user.reload.showcase?
  end

  test "request a /explore con onboarding pendiente redirige a /bienvenida" do
    get explore_path
    assert_redirected_to onboarding_path
  end

  test "después de completar, /explore es accesible" do
    @user.complete_onboarding!
    get explore_path
    assert_response :success
  end

  test "sin sesión no hay redirect a onboarding" do
    delete session_path
    get explore_path
    assert_response :success
  end
end
