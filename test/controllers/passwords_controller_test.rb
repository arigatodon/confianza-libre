require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(username: "pwd", email_address: "pwd@test.local")
  end

  test "new renderiza" do
    get new_password_path
    assert_response :success
  end

  test "create encola el mailer para un user existente" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path
  end

  test "create para email desconocido redirige sin enviar mail" do
    assert_no_enqueued_emails do
      post passwords_path, params: { email_address: "missing@example.local" }
    end
    assert_redirected_to new_session_path
  end

  test "edit renderiza con un token válido" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit con token inválido redirige a new" do
    get edit_password_path("invalid-token")
    assert_redirected_to new_password_path
  end

  test "update cambia el password con confirmación válida" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token),
          params: { password: "newpassword123", password_confirmation: "newpassword123" }
      assert_redirected_to new_session_path
    end
  end

  test "update con passwords que no matchean redirige al edit sin cambiar" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token),
          params: { password: "newpassword123", password_confirmation: "otherpassword" }
      assert_redirected_to edit_password_path(token)
    end
  end
end
