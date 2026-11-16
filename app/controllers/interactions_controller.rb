class InteractionsController < ApplicationController
  before_action :set_post,         only: :create
  before_action :set_interaction,  only: [ :show, :accept, :counter, :start, :confirm, :cancel, :dispute, :respond_dispute ]
  before_action :require_participant!, only: [ :accept, :counter, :start, :confirm, :cancel, :dispute, :respond_dispute ]

  def index
    user = Current.session.user
    base = Interaction.includes(:post, :sender, :receiver).order(updated_at: :desc)

    @filter = params[:status].presence_in(Interaction::STATUSES.keys.map(&:to_s))

    @sent     = scoped_by_filter(base.where(sender_id:   user.id))
    @received = scoped_by_filter(base.where(receiver_id: user.id))
  end

  def show
    @reviews = @interaction.reviews.includes(:reviewer, :reviewed_user).order(created_at: :asc)
  end

  def create
    unless Current.session.user.email_verified?
      return redirect_to(@post,
        alert: "Verifica tu email antes de iniciar una interacción. Te mandamos un link al registrarte.")
    end

    @interaction = @post.interactions.build(
      sender:         Current.session.user,
      receiver:       @post.user,
      agreed_credits: params.dig(:interaction, :agreed_credits).to_i
    )

    if @interaction.save
      redirect_to @interaction, notice: "Interacción iniciada."
    else
      redirect_to @post, alert: @interaction.errors.full_messages.to_sentence
    end
  end

  def accept
    unless @interaction.awaiting_response_from == Current.session.user
      return forbid("Tienes que esperar la respuesta de la otra parte.")
    end
    transition!(to: :accepted, ok_notice: "Aceptaste #{@interaction.agreed_credits} C. Marquen cuando estén listos para iniciar.")
  end

  def counter
    unless @interaction.awaiting_response_from == Current.session.user
      return forbid("Tienes que esperar la contrapropuesta de la otra parte.")
    end

    new_amount = params.dig(:interaction, :agreed_credits).to_i
    if new_amount < 0
      return redirect_to(@interaction, alert: "El monto no puede ser negativo.")
    end

    new_status = @interaction.requested? ? :negotiating : :requested
    if @interaction.update(agreed_credits: new_amount, status: new_status)
      redirect_to @interaction, notice: "Contrapropusiste #{new_amount} C. Le toca responder a la otra parte."
    else
      redirect_to @interaction, alert: @interaction.errors.full_messages.to_sentence
    end
  end

  def start
    transition!(from: :accepted, to: :in_progress, ok_notice: "Marcaste la interacción como en progreso.")
  end

  def cancel
    unless %w[requested negotiating accepted in_progress].include?(@interaction.status)
      return forbid("No se puede cancelar en este estado.")
    end
    transition!(to: :canceled, ok_notice: "Interacción cancelada.")
  end

  def dispute
    unless Dispute::DISPUTABLE_STATUSES.include?(@interaction.status)
      return forbid("Solo se puede abrir disputa con la interacción aceptada o en curso.")
    end
    if @interaction.dispute.present?
      return forbid("Esta interacción ya tiene una disputa abierta.")
    end

    dispute = @interaction.build_dispute(
      opener:   Current.session.user,
      argument: params.dig(:dispute, :argument)
    )

    if dispute.save
      @interaction.update!(status: :disputed)
      redirect_to @interaction, notice: "Disputa abierta. La revisará un moderador."
    else
      redirect_to @interaction, alert: dispute.errors.full_messages.to_sentence
    end
  end

  def respond_dispute
    dispute = @interaction.dispute
    return forbid("Esta interacción no tiene una disputa abierta.") unless dispute&.open?
    unless dispute.counterpart == Current.session.user
      return forbid("Solo la contraparte de la disputa puede responder.")
    end

    if dispute.update(response: params.dig(:dispute, :response), responded_at: Time.current, status: :responded)
      redirect_to @interaction, notice: "Respondiste la disputa. La revisará un moderador."
    else
      redirect_to @interaction, alert: dispute.errors.full_messages.to_sentence
    end
  end

  def confirm
    return forbid("Sólo se puede confirmar en progreso.") unless @interaction.in_progress?

    field = @interaction.confirmation_field_for(Current.session.user)
    return forbid("No participaste de esta interacción.") unless field
    if @interaction.confirmed_by?(Current.session.user)
      return redirect_to(@interaction, alert: "Ya habías confirmado el cierre.")
    end

    @interaction.assign_attributes(field => Time.current)

    if @interaction.both_confirmed?
      error = close_with_credit_transfer
      if error
        # El rollback dentro de close_with_credit_transfer ya revirtió en DB
        # la confirmación + el status :completed. Reload para descartar el
        # state en memoria y evitar re-persistirlo. La confirmación queda
        # sin aplicar, así el usuario puede reintentar cuando se resuelva
        # la causa (ej.: el sender consiga saldo).
        @interaction.reload
        redirect_to @interaction, alert: error
      else
        redirect_to @interaction, notice: "¡Interacción cerrada! Ya pueden evaluarse."
      end
    else
      @interaction.save!
      redirect_to @interaction, notice: "Confirmaste el cierre. Falta la otra parte."
    end
  end

  private

  def scoped_by_filter(relation)
    @filter ? relation.where(status: @filter) : relation
  end

  def transition!(to:, from: nil, ok_notice: "Estado actualizado.")
    if from && @interaction.status != from.to_s
      return forbid("Acción no disponible para el estado actual.")
    end

    if @interaction.update(status: to)
      redirect_to @interaction, notice: ok_notice
    else
      redirect_to @interaction, alert: @interaction.errors.full_messages.to_sentence
    end
  end

  def close_with_credit_transfer
    error_msg = nil
    ActiveRecord::Base.transaction do
      @interaction.status = :completed
      @interaction.save!

      if @interaction.agreed_credits.positive?
        result = CreditTransfer.call(@interaction)
        unless result.ok?
          error_msg = "Transferencia rechazada: #{translate_credit_error(result)}"
          raise ActiveRecord::Rollback
        end
      end
    end
    error_msg
  end

  def translate_credit_error(result)
    case result.error
    when :exceeds_tx_cap       then "el monto supera el tope por transacción (máx #{result.meta[:max_allowed]} C)"
    when :insufficient_balance then "el sender no tiene saldo suficiente (disponible #{result.meta[:available]} C)"
    when :already_settled      then "esta interacción ya se procesó"
    when :zero_amount          then "el monto debe ser positivo"
    else                            "error procesando la transferencia (#{result.error})"
    end
  end

  def current_user_is_sender?
    @interaction.sender_id == Current.session.user_id
  end

  def current_user_is_receiver?
    @interaction.receiver_id == Current.session.user_id
  end

  def current_participant?
    current_user_is_sender? || current_user_is_receiver?
  end

  def require_participant!
    forbid("No participaste de esta interacción.") unless current_participant?
  end

  def forbid(msg)
    redirect_to(@interaction || root_path, alert: msg)
  end

  def set_interaction
    @interaction = Interaction.find(params[:id])
  end

  def set_post
    @post = Post.friendly.find(params[:post_id])
  end
end
