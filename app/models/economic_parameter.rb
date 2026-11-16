class EconomicParameter < ApplicationRecord
  # Un parámetro es global (territory_id NULL) o un override local de un
  # territorio. La lectura resuelve: override del territorio → global → default.
  belongs_to :territory, optional: true

  validates :key,   presence: true, uniqueness: { scope: :territory_id }
  validates :value, presence: true

  # Cache en Rails.cache (Solid Cache en prod, compartido entre procesos) con
  # TTL corto: tras un rule_change ejecutado en un proceso, cualquier otro lee
  # el valor nuevo a lo sumo CACHE_TTL después, aunque no le llegue el delete.
  CACHE_KEY = "economic_parameters:all_v2"
  CACHE_TTL = 60.seconds

  class << self
    # territory: un Territory (o su id) para leer su override; nil = global.
    def get(key, default = nil, territory: nil)
      tid = territory.respond_to?(:id) ? territory.id : territory
      table = all_cached
      value = (table[[ tid, key.to_s ]] if tid)
      value ||= table[[ nil, key.to_s ]]
      value || default
    end

    def get_int(key, default = 0, territory: nil)
      v = get(key, nil, territory: territory)
      v.nil? ? default : v.to_i
    end

    def get_decimal(key, default = 0.0, territory: nil)
      v = get(key, nil, territory: territory)
      v.nil? ? default : v.to_f
    end

    def get_list(key, territory: nil)
      get(key, "", territory: territory).to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def reset_cache!
      Rails.cache.delete(CACHE_KEY)
    end

    private

    # Una sola query trae todas las filas (son pocas): la clave del hash es
    # [territory_id, key] para que get pueda resolver override → global.
    def all_cached
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        pluck(:territory_id, :key, :value).each_with_object({}) do |(tid, key, value), h|
          h[[ tid, key ]] = value
        end
      end
    end
  end

  after_commit { self.class.reset_cache! }
end
