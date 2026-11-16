require "test_helper"

class EmailVerificationTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    # Para este suite usamos un user NO verificado (pasamos el flag explícito
    # del factory; el default es verificado para no romper otros tests).
    @user = create_user(username: "verifier", email_address: "verifier@test.local", email_verified: false)
  end

  test "después del registro, el user nace sin email verificado" do
    refute @user.email_verified?
    assert_nil @user.email_verified_at
    assert_equal "unverified", @user.verification_level
  end

  test "after_create_commit encola el mailer de verificación" do
    assert_enqueued_emails 1 do
      User.create!(
        username: "fresh", email_address: "fresh@test.local",
        password: "password123", password_confirmation: "password123"
      )
    end
  end

  test "GET /verificar-email/:token con token válido marca el email como verificado" do
    token = @user.generate_token_for(:email_verification)
    get email_verification_path(token)

    assert_redirected_to root_path
    @user.reload
    assert @user.email_verified?
    assert_equal "email", @user.verification_level
  end

  test "token inválido redirige sin cambios" do
    get email_verification_path("invalido-token")
    assert_redirected_to root_path
    refute @user.reload.email_verified?
  end

  test "token de un email viejo deja de servir cuando cambia el email_address" do
    token = @user.generate_token_for(:email_verification)
    @user.update!(email_address: "moved@test.local")

    get email_verification_path(token)
    refute @user.reload.email_verified?
  end

  test "verificar el mismo token dos veces no rompe" do
    token = @user.generate_token_for(:email_verification)
    get email_verification_path(token)
    assert @user.reload.email_verified?

    get email_verification_path(token)
    assert_redirected_to root_path
    # Sigue verificado, sin error.
    assert @user.reload.email_verified?
  end

  test "soft gate: sender sin email verificado no puede crear Interaction" do
    other = create_user(username: "otherv", email_address: "otherv@test.local")
    post_v = create_post(user: other)

    sign_in_as(@user)
    assert_no_difference -> { Interaction.count } do
      post post_interactions_path(post_v), params: { interaction: { agreed_credits: 10 } }
    end
    assert_redirected_to post_v
    follow_redirect!
    assert_match /Verifica tu email/, response.body
  end

  test "sender con email verificado sí puede crear Interaction" do
    @user.mark_email_verified!
    other = create_user(username: "otherw", email_address: "otherw@test.local")
    post_v = create_post(user: other)

    sign_in_as(@user)
    assert_difference -> { Interaction.count }, 1 do
      post post_interactions_path(post_v), params: { interaction: { agreed_credits: 10 } }
    end
  end

  test "mark_email_verified! encola RecalculateUserLevelJob" do
    assert_enqueued_with(job: RecalculateUserLevelJob, args: [ @user.id ]) do
      @user.mark_email_verified!
    end
  end

  test "POST /verificar-email reenvía el mail al user autenticado no verificado" do
    sign_in_as(@user)
    assert_enqueued_email_with EmailVerificationMailer, :confirm, args: [ @user ] do
      post resend_email_verification_path
    end
    assert_redirected_to root_path
  end
end
