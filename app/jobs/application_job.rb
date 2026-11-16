class ApplicationJob < ActiveJob::Base
  # Fallas transitorias: reintentar con backoff en vez de perder el job.
  retry_on ActiveRecord::Deadlocked,             wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionTimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on Timeout::Error,                       wait: :polynomially_longer, attempts: 3

  # Si el registro ya no existe, el job no tiene nada que hacer.
  discard_on ActiveJob::DeserializationError
  discard_on ActiveRecord::RecordNotFound
end
