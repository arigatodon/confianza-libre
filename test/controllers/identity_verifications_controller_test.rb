require "test_helper"

class IdentityVerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "subidor")
  end

  def png = fixture_file_upload("sample.png", "image/png")

  test "un usuario con email verificado puede subir su documento" do
    sign_in_as(@user)
    assert_difference -> { @user.identity_verifications.count }, 1 do
      post identity_verification_path, params: { identity_verification: { documents: [ png ] } }
    end
    assert_redirected_to settings_path
    assert @user.identity_verifications.last.pending?
  end

  test "no puede subir sin email verificado" do
    sin_email = create_user(username: "sinmail", email_verified: false)
    sign_in_as(sin_email)
    assert_no_difference -> { IdentityVerification.count } do
      post identity_verification_path, params: { identity_verification: { documents: [ png ] } }
    end
    assert_redirected_to settings_path
  end

  test "no puede subir una segunda solicitud mientras hay una pendiente" do
    sign_in_as(@user)
    post identity_verification_path, params: { identity_verification: { documents: [ png ] } }
    assert_no_difference -> { @user.identity_verifications.count } do
      post identity_verification_path, params: { identity_verification: { documents: [ png ] } }
    end
  end

  test "la página de ajustes muestra el estado de la solicitud" do
    sign_in_as(@user)
    post identity_verification_path, params: { identity_verification: { documents: [ png ] } }
    get settings_path
    assert_match "en revisión", response.body
  end
end
