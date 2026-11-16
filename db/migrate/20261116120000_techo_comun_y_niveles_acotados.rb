# ECONOMIA.md v0.3 (2026-11-16): «la confianza te da crédito, no riqueza».
# - El techo de saldo pasa a ser común (parámetro `credit_ceiling`, 5.000 C).
# - Pisos y topes por nivel se acotan (100→2.000 y 50→500, antes 100→1.000.000).
# - Proponer reglas queda abierto desde el nivel 1.
# Migración de datos en SQL puro para no depender del código de la app.
class TechoComunYNivelesAcotados < ActiveRecord::Migration[8.1]
  NUEVOS = { 1 => [ 100, 50 ], 2 => [ 250, 100 ], 3 => [ 500, 200 ], 4 => [ 1_000, 350 ], 5 => [ 2_000, 500 ] }.freeze
  ANTIGUOS = { 1 => [ 100, 50 ], 2 => [ 1_000, 250 ], 3 => [ 10_000, 1_000 ], 4 => [ 100_000, 10_000 ], 5 => [ 1_000_000, 100_000 ] }.freeze

  def up
    execute <<~SQL
      INSERT INTO economic_parameters (key, value, description, created_at, updated_at)
      VALUES ('credit_ceiling', '5000',
              'Techo de saldo, el mismo para todas las personas (ECONOMIA.md § 4.1). Lo que lo supera va al fondo territorial. Solo gobernable a nivel global.',
              NOW(), NOW())
      ON CONFLICT (key, territory_id) DO NOTHING;

      UPDATE economic_parameters
         SET value = '1',
             description = 'Nivel mínimo para proponer cambios de reglas o categorías nuevas. 1 = cualquier persona con email verificado; el quórum filtra.',
             updated_at = NOW()
       WHERE key = 'proposal_rules_min_level' AND territory_id IS NULL AND value = '2';
    SQL
    aplicar_limites(NUEVOS)
  end

  def down
    execute "DELETE FROM economic_parameters WHERE key = 'credit_ceiling' AND territory_id IS NULL"
    execute "UPDATE economic_parameters SET value = '2' WHERE key = 'proposal_rules_min_level' AND territory_id IS NULL AND value = '1'"
    aplicar_limites(ANTIGUOS)
  end

  private

  # El piso incluye el bonus de padrinazgo, igual que CreditLimitCalculator.
  def aplicar_limites(tabla)
    pisos = tabla.map { |nivel, (piso, _)| "WHEN #{nivel} THEN #{piso}" }.join(" ")
    topes = tabla.map { |nivel, (_, tope)| "WHEN #{nivel} THEN #{tope}" }.join(" ")
    execute <<~SQL
      UPDATE users
         SET credit_floor = (CASE level #{pisos} END) + sponsor_bonus_floor,
             tx_cap       = CASE level #{topes} END
       WHERE level BETWEEN 1 AND 5;
    SQL
  end
end
