class TerritoryResolver
  # Resuelve (lat, lng) → Territory.
  # Lazy: si el territorio no existe en DB, lo crea desde Geocoder.
  # Restringido a economic_parameters.allowed_countries (MVP: "CL").
  #
  # Uso:
  #   result = TerritoryResolver.resolve(lat, lng)
  #   if result.ok?
  #     result.territory  # => #<Territory ...>
  #   else
  #     result.error      # => :country_blocked | :no_geocoder_result | ...
  #   end

  CACHE_TTL = 30.days
  PRECISION = 3 # ~100 m de granularidad

  Result = Struct.new(:territory, :error, keyword_init: true) do
    def ok?              = territory.present?
    def country_blocked? = error == :country_blocked
  end

  def self.resolve(lat, lng)
    new(lat, lng).resolve
  end

  attr_reader :lat, :lng

  def initialize(lat, lng)
    @lat = lat&.to_f
    @lng = lng&.to_f
  end

  def resolve
    return Result.new(error: :missing_coords) if lat.nil? || lng.nil?
    return Result.new(error: :invalid_coords) if (lat.zero? && lng.zero?) || lat.abs > 90 || lng.abs > 180

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { geocode_and_build }
  rescue => e
    Rails.logger.warn("[TerritoryResolver] #{e.class}: #{e.message} (lat=#{lat}, lng=#{lng})")
    Result.new(error: :geocoder_error)
  end

  private

  def cache_key
    "territory_resolver:#{lat.round(PRECISION)},#{lng.round(PRECISION)}"
  end

  def geocode_and_build
    geo = Geocoder.search([ lat, lng ]).first
    return Result.new(error: :no_geocoder_result) unless geo

    country_code = (geo.country_code || geo.data.dig("address", "country_code")).to_s.upcase
    return Result.new(error: :country_blocked) unless allowed_country?(country_code)

    admin1 = extract_admin1(geo)
    admin2 = extract_admin2(geo)
    return Result.new(error: :insufficient_data) if admin2.blank?

    territory = Territory
                  .where(country_code: country_code, admin1: admin1, admin2: admin2)
                  .first_or_create! do |t|
      t.name      = admin2
      t.source    = "admin"
      t.latitude  = lat
      t.longitude = lng
    end

    territory.ensure_community_account!

    Result.new(territory: territory)
  end

  def allowed_country?(code)
    EconomicParameter.get_list("allowed_countries").map(&:upcase).include?(code)
  end

  # Región / provincia / departamento.
  def extract_admin1(geo)
    addr = geo.data["address"] || {}
    geo.state.presence || addr["state"] || addr["region"] || addr["province"]
  end

  # Comuna / municipio / ciudad. Nominatim varía el campo según país.
  def extract_admin2(geo)
    addr = geo.data["address"] || {}
    addr["city"] || addr["town"] || addr["municipality"] || addr["county"] ||
      addr["village"] || addr["suburb"] || addr["district"]
  end
end
