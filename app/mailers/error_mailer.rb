class ErrorMailer < ApplicationMailer
  # Casilla que recibe las alertas operativas. Se configura por entorno
  # (ALERT_EMAIL); sin ella, las alertas no se envían.
  def self.alert_recipient = ENV["ALERT_EMAIL"].presence

  # Aviso de error no manejado en producción. Recibe primitivos (no la
  # excepción) para que el job se serialice sin problemas.
  def crash(error_class:, message:, backtrace:, context:)
    return unless self.class.alert_recipient

    @error_class = error_class
    @message     = message
    @backtrace   = backtrace
    @context     = context
    mail subject: "⚠ Error en confianza.world: #{error_class}", to: self.class.alert_recipient
  end

  # Alerta de la reconciliación semanal: algún cached_balance difería del
  # ledger (ya corregido) o la suma global no da cero.
  def ledger_drift(drifted:, total_after:)
    return unless self.class.alert_recipient

    @drifted     = drifted
    @total_after = total_after
    mail subject: "⚠ Ledger de confianza.world: drift en #{drifted.size} cuenta(s)",
         to: self.class.alert_recipient
  end
end
