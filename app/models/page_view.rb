# Una página HTML vista. Analítica propia, sin cookies ni terceros: el
# visitante es un hash de IP + user agent + sal del día (ver .digest_for), así
# que sirve para contar únicos por día pero no para seguir a nadie en el tiempo.
class PageView < ApplicationRecord
  BOT_UA = /bot|crawl|spider|slurp|facebookexternalhit|preview|curl|wget|python|go-http|headless|lighthouse|monitor|uptime/i

  scope :between, ->(desde, hasta = Date.current) { where(visited_on: desde..hasta) }

  def self.digest_for(ip:, user_agent:, on: Date.current)
    sal = Rails.application.key_generator.generate_key("page_views/#{on.iso8601}")
    OpenSSL::HMAC.hexdigest("SHA256", sal, "#{ip}|#{user_agent}")[0, 32]
  end

  def self.bot?(user_agent)
    user_agent.blank? || user_agent.match?(BOT_UA)
  end
end
