class ModerationController < ApplicationController
  before_action :require_moderator

  def index
    @open_reports = Report.open_only.recent
                          .includes(:reporter, :reportable, :territory)
                          .limit(50)
    @recent_resolved = Report.where.not(status: :open).recent
                             .includes(:reporter, :resolved_by, :reportable, :territory)
                             .limit(20)

    @open_disputes = Dispute.unresolved.oldest_first
                            .includes(interaction: [ :sender, :receiver ])
                            .limit(50)

    @pending_identity = IdentityVerification.pending.recent
                            .includes(:user, documents_attachments: :blob)
                            .limit(50)
  end

  def show
    @report = Report.includes(:reporter, :reportable, :resolved_by, :territory).find(params[:id])
  end

  def show_dispute
    @dispute = Dispute.includes(interaction: [ :sender, :receiver, :messages ]).find(params[:id])
  end

  def resolve
    @report = Report.find(params[:id])
    action = params[:resolution].to_s
    note   = params[:note].to_s

    result = ReportResolver.call(
      report:    @report,
      moderator: Current.session.user,
      action:    action,
      note:      note
    )

    if result.ok?
      msg = "Reporte resuelto: #{@report.status_label_es}."
      msg += " +#{result.reward_amount}C del fondo territorial." if result.reward_amount.to_i.positive?
      redirect_to moderation_path, notice: msg
    else
      redirect_to moderation_report_path(@report),
                  alert: "No se pudo resolver: #{result.error}#{" (#{result.meta[:message]})" if result.meta&.dig(:message)}"
    end
  end

  def resolve_dispute
    @dispute = Dispute.find(params[:id])
    verdict  = params[:verdict].to_s
    note     = params[:note].to_s
    amount   = params[:amount]

    result = DisputeResolver.call(
      dispute:   @dispute,
      moderator: Current.session.user,
      verdict:   verdict,
      note:      note,
      amount:    amount
    )

    if result.ok?
      redirect_to moderation_path, notice: "Disputa resuelta: #{@dispute.verdict_label_es}."
    else
      redirect_to moderation_dispute_path(@dispute),
                  alert: "No se pudo resolver: #{result.error}#{" (#{result.meta[:message]})" if result.meta&.dig(:message)}"
    end
  end

  def resolve_identity
    verification = IdentityVerification.find(params[:id])
    result = IdentityReviewer.call(
      verification: verification,
      moderator:    Current.session.user,
      decision:     params[:decision].to_s,
      note:         params[:note].to_s
    )

    if result.ok?
      estado = verification.approved? ? "aprobada" : "rechazada"
      redirect_to moderation_path, notice: "Verificación de identidad #{estado}."
    else
      redirect_to moderation_path, alert: "No se pudo resolver: #{result.error}"
    end
  end

  # Sirve la imagen del documento SÓLO a moderadores (nunca por URL pública de
  # ActiveStorage). El streaming evita exponer la URL firmada del blob.
  def identity_document
    verification = IdentityVerification.find(params[:id])
    document = verification.documents.find { |d| d.id.to_s == params[:doc_id].to_s }
    return head :not_found if document.nil?

    send_data document.download, type: document.content_type,
              disposition: "inline", filename: document.filename.to_s
  end

  private

  def require_moderator
    return if Current.session&.user&.moderator?
    redirect_to root_path, alert: "Solo los moderadores (L3+) pueden ver esta página."
  end
end
