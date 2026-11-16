require "test_helper"

class DisputeMailerTest < ActionMailer::TestCase
  include Factories

  setup do
    setup_economy!
    @sender   = create_user(username: "dmsdr")
    @receiver = create_user(username: "dmrcv")
    @post     = create_post(user: @receiver)
    @interaction = create_interaction(post: @post, sender: @sender, receiver: @receiver,
                                       status: :in_progress, agreed_credits: 10)
    @dispute = Dispute.create!(interaction: @interaction, opener: @sender,
                               argument: "No se presentó a la sesión que habíamos acordado.")
  end

  test "opened va a la contraparte con el argumento" do
    mail = DisputeMailer.opened(@dispute)
    assert_equal [ @receiver.email_address ], mail.to
    assert_match(/abrió una disputa/, mail.subject)
    assert_includes mail.html_part.body.to_s, @dispute.argument
    assert_includes mail.text_part.body.to_s, @dispute.argument
  end

  test "responded va al opener con la respuesta" do
    @dispute.update!(response: "Sí me presenté, fue al revés.", responded_at: Time.current, status: :responded)

    mail = DisputeMailer.responded(@dispute)
    assert_equal [ @sender.email_address ], mail.to
    assert_includes mail.html_part.body.to_s, @dispute.response
  end

  test "resolved incluye el veredicto y la nota" do
    @dispute.update!(status: :resolved, verdict: :cancel,
                     resolution_note: "No hay evidencia suficiente.", resolved_at: Time.current)

    mail = DisputeMailer.resolved(@dispute, @sender)
    assert_equal [ @sender.email_address ], mail.to
    assert_includes mail.html_part.body.to_s, "Cancelado sin mover créditos"
    assert_includes mail.html_part.body.to_s, "No hay evidencia suficiente."
    assert_includes mail.text_part.body.to_s, "no se movieron créditos"
  end

  test "abrir y responder una disputa encolan sus emails" do
    interaction2 = create_interaction(post: @post, sender: @sender, receiver: @receiver,
                                       status: :accepted, agreed_credits: 5)
    assert_enqueued_emails 1 do
      Dispute.create!(interaction: interaction2, opener: @sender, argument: "a" * 30)
    end

    assert_enqueued_emails 1 do
      @dispute.update!(response: "Mi versión de los hechos completa.",
                       responded_at: Time.current, status: :responded)
    end
  end
end
