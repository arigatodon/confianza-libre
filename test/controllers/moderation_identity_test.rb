require "test_helper"

class ModerationIdentityTest < ActionDispatch::IntegrationTest
  setup do
    setup_economy!
    @user = create_user(username: "solicitante")
    @mod  = create_user(username: "modident")
    @mod.grant_moderation!

    @verification = @user.identity_verifications.new
    @verification.documents.attach(io: File.open(file_fixture("sample.png")),
                                   filename: "doc.png", content_type: "image/png")
    @verification.save!
    @doc = @verification.documents.first
  end

  test "un usuario común no puede ver la imagen del documento" do
    sign_in_as(@user) # ni siquiera el dueño: sólo moderadores
    get moderation_identity_document_path(@verification, @doc.id)
    assert_redirected_to root_path
  end

  test "un moderador L3+ ve la imagen del documento" do
    sign_in_as(@mod)
    get moderation_identity_document_path(@verification, @doc.id)
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "un moderador puede aprobar desde el panel" do
    sign_in_as(@mod)
    patch resolve_moderation_identity_path(@verification), params: { decision: "approve" }
    assert_redirected_to moderation_path
    assert @user.reload.verification_identity?
  end

  test "el panel de moderación lista las solicitudes pendientes" do
    sign_in_as(@mod)
    get moderation_path
    assert_response :success
    assert_match "@#{@user.username}", response.body
    assert_match "Verificaciones de identidad", response.body
  end
end
