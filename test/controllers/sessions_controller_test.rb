require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(username: "sess", email_address: "sess@test.local")
    # create_user setea password "password123" — usamos esa en los logins.
  end

  test "new renderiza" do
    get new_session_path
    assert_response :success
  end

  test "create con credenciales válidas loguea y deja cookie de sesión" do
    post session_path, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "create con password equivocada redirige al login sin cookie" do
    post session_path, params: { email_address: @user.email_address, password: "wrongwrong" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "create con digest corrupto (no bcrypt) falla como login inválido, no 500" do
    @user.update_column(:password_digest, "12341234") # texto plano, hash inválido
    post session_path, params: { email_address: @user.email_address, password: "password123" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "destroy desloguea" do
    sign_in_as(@user)
    delete session_path
    assert_redirected_to new_session_path
    assert_empty cookies[:session_id].to_s
  end
end
