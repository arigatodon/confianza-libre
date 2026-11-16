require "test_helper"

class IdentityReviewerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    setup_economy!
    @user = create_user(username: "porverificar")
    @mod  = create_user(username: "modera")
    @mod.grant_moderation!
    @verification = build_verification(@user)
  end

  def build_verification(user)
    v = user.identity_verifications.new
    v.documents.attach(io: File.open(file_fixture("sample.png")), filename: "doc.png", content_type: "image/png")
    v.save!
    v
  end

  test "aprobar sube al usuario a identity y encola el recálculo de nivel" do
    result = nil
    assert_enqueued_with(job: RecalculateUserLevelJob, args: [ @user.id ]) do
      result = IdentityReviewer.call(verification: @verification, moderator: @mod, decision: "approve")
    end
    assert result.ok?
    assert @user.reload.verification_identity?
    assert @verification.reload.approved?
    assert_equal @mod, @verification.reviewed_by
    # Notificación al usuario.
    assert @user.notifications.where(kind: "identity_review").exists?
  end

  test "rechazar exige motivo, notifica y permite reintentar" do
    result = IdentityReviewer.call(verification: @verification, moderator: @mod, decision: "reject")
    assert_not result.ok?, "sin motivo no debe resolver"

    result = IdentityReviewer.call(verification: @verification, moderator: @mod,
                                   decision: "reject", note: "La foto está borrosa")
    assert result.ok?
    assert @verification.reload.rejected?
    assert_not @user.reload.verification_identity?
    n = @user.notifications.where(kind: "identity_review").last
    assert_match "borrosa", n.body

    # Tras el rechazo puede volver a subir (no queda una pendiente bloqueando).
    assert_nothing_raised { build_verification(@user) }
  end

  test "un no-moderador no puede resolver" do
    quien = create_user(username: "cualquiera")
    result = IdentityReviewer.call(verification: @verification, moderator: quien, decision: "approve")
    assert_not result.ok?
    assert_equal :unauthorized, result.error
    assert_not @user.reload.verification_identity?
  end

  test "no se puede resolver dos veces" do
    IdentityReviewer.call(verification: @verification, moderator: @mod, decision: "approve")
    result = IdentityReviewer.call(verification: @verification.reload, moderator: @mod, decision: "reject", note: "x")
    assert_not result.ok?
    assert_equal :already_resolved, result.error
  end

  test "camino completo a L5: identidad es el último candado" do
    # Todos los requisitos numéricos de L5, pero verificación sólo :phone.
    @user.update!(verification_level: :phone, trust_score: 4.6, created_at: 200.days.ago)
    100.times do |n|
      other = create_user(username: "l5_#{n}")
      2.times do
        i = create_interaction(post: create_post(user: @user), sender: other, receiver: @user)
        i.update_columns(status: 3)
      end
    end

    # Con :phone tope L4 (L5 exige identity).
    assert_equal 4, CreditLimitCalculator.call(@user.reload)[:level]

    # Aprobar identidad y recalcular.
    IdentityReviewer.call(verification: @verification, moderator: @mod, decision: "approve")
    assert_equal 5, CreditLimitCalculator.call(@user.reload)[:level]
  end
end
