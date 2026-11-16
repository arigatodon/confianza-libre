require "test_helper"

class ErrorEmailSubscriberTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @cache      = ActiveSupport::Cache::MemoryStore.new
    @subscriber = ErrorEmailSubscriber.new(cache: @cache)
    @error      = StandardError.new("explotó algo")
    @error.set_backtrace([ "app/models/post.rb:10" ])
  end

  test "un error no manejado encola el email de alerta" do
    assert_enqueued_emails 1 do
      @subscriber.report(@error, handled: false, severity: :error, context: { foo: 1 })
    end
  end

  test "la misma clase de error se silencia dentro de la hora" do
    assert_enqueued_emails 1 do
      @subscriber.report(@error, handled: false, severity: :error, context: {})
      @subscriber.report(@error, handled: false, severity: :error, context: {})
    end
  end

  test "los errores manejados no avisan" do
    assert_no_enqueued_emails do
      @subscriber.report(@error, handled: true, severity: :warning, context: {})
    end
  end

  test "los errores de comandos operativos (runner/rake/consola) no avisan" do
    assert_no_enqueued_emails do
      @subscriber.report(@error, handled: false, severity: :error, context: {},
                         source: "application.runner.railties")
      @subscriber.report(@error, handled: false, severity: :error, context: {},
                         source: "application.rake.railties")
      @subscriber.report(@error, handled: false, severity: :error, context: {},
                         source: "application.console.railties")
    end
  end

  test "el mail de crash va a la casilla de alertas (ALERT_EMAIL) con el detalle" do
    previo = ENV["ALERT_EMAIL"]
    ENV["ALERT_EMAIL"] = "alertas@example.org"
    mail = ErrorMailer.crash(error_class: "StandardError", message: "explotó",
                             backtrace: "app/x.rb:1", context: "posts#show")
    assert_equal [ "alertas@example.org" ], mail.to
    assert_match(/StandardError/, mail.subject)
    assert_includes mail.html_part.body.to_s, "posts#show"
  ensure
    ENV["ALERT_EMAIL"] = previo
  end

  test "sin ALERT_EMAIL configurado no se envía nada" do
    previo = ENV.delete("ALERT_EMAIL")
    mail = ErrorMailer.crash(error_class: "StandardError", message: "x", backtrace: "", context: "")
    assert_nil mail.message.to
  ensure
    ENV["ALERT_EMAIL"] = previo
  end
end
