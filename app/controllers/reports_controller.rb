class ReportsController < ApplicationController
  def new
    @reportable = find_reportable
    return redirect_to(root_path, alert: "No se puede reportar eso.") unless @reportable

    @report = Report.new(reportable: @reportable)
  end

  def create
    reportable = find_reportable
    return redirect_to(root_path, alert: "No se puede reportar eso.") unless reportable

    # Idempotencia liviana: si el mismo reporter ya tiene un reporte open
    # contra este reportable, lo reutilizamos en lugar de duplicar.
    existing = Report.where(
      reporter:        Current.session.user,
      reportable:      reportable,
      status:          :open
    ).first

    @report = existing || Report.new(reporter: Current.session.user, reportable: reportable)
    @report.assign_attributes(report_params)

    if @report.save
      redirect_to back_path_for(reportable),
                  notice: "Reporte enviado. Lo revisará un moderador."
    else
      redirect_to back_path_for(reportable),
                  alert: @report.errors.full_messages.to_sentence
    end
  end

  private

  def find_reportable
    type = params[:reportable_type].presence || params.dig(:report, :reportable_type)
    id   = params[:reportable_id].presence   || params.dig(:report, :reportable_id)
    return nil unless Report::REPORTABLE_TYPES.include?(type) && id.present?
    type.constantize.find_by(id: id)
  end

  def report_params
    permitted = params.require(:report).permit(:reason, :body, :reportable_type, :reportable_id)
    permitted.slice(:reason, :body)
  end

  def back_path_for(reportable)
    case reportable
    when Post    then post_path(reportable)
    when Comment then post_path(reportable.post)
    when Message then interaction_path(reportable.interaction)
    when User    then profile_path(reportable.username || reportable.id)
    else root_path
    end
  end
end
