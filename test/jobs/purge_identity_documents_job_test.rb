require "test_helper"

class PurgeIdentityDocumentsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    setup_economy!
    @user = create_user(username: "purgado")
  end

  def build_resolved(status:, reviewed_at:)
    v = @user.identity_verifications.new(status: status)
    v.documents.attach(io: File.open(file_fixture("sample.png")), filename: "d.png", content_type: "image/png")
    v.save!
    v.update_columns(reviewed_at: reviewed_at)
    v
  end

  test "purga imágenes de solicitudes resueltas hace más de 30 días" do
    vieja = build_resolved(status: :approved, reviewed_at: 31.days.ago)
    perform_enqueued_jobs { PurgeIdentityDocumentsJob.perform_now }
    assert_not vieja.reload.documents.attached?
  end

  test "no purga solicitudes resueltas hace menos de 30 días" do
    reciente = build_resolved(status: :rejected, reviewed_at: 3.days.ago)
    perform_enqueued_jobs { PurgeIdentityDocumentsJob.perform_now }
    assert reciente.reload.documents.attached?
  end

  test "no purga solicitudes pendientes" do
    pendiente = @user.identity_verifications.new(status: :pending)
    pendiente.documents.attach(io: File.open(file_fixture("sample.png")), filename: "d.png", content_type: "image/png")
    pendiente.save!
    perform_enqueued_jobs { PurgeIdentityDocumentsJob.perform_now }
    assert pendiente.reload.documents.attached?
  end
end
