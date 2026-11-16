class AddFulltextSearch < ActiveRecord::Migration[8.1]
  # Búsqueda full-text real sobre posts y personas:
  # - `unaccent` para tolerar acentos ("gasfiter" encuentra "gásfiter").
  # - `pg_trgm` para tolerar tipeos (similitud por trigramas).
  # - Configuración de texto `spanish_unaccent`: stemming en español + unaccent,
  #   de modo que "gasfitería" y "gásfiter" comparten raíz ("gasfit").
  # - Columnas `searchable` (tsvector) GENERADAS, con pesos por campo, e índices
  #   GIN para que la búsqueda no haga seq scan.
  def up
    enable_extension "unaccent"
    enable_extension "pg_trgm"

    # La configuración es compartida; COPY de la base "spanish" y luego mapear
    # las palabras por unaccent antes del stemmer español.
    execute <<~SQL
      DROP TEXT SEARCH CONFIGURATION IF EXISTS spanish_unaccent;
      CREATE TEXT SEARCH CONFIGURATION spanish_unaccent ( COPY = spanish );
      ALTER TEXT SEARCH CONFIGURATION spanish_unaccent
        ALTER MAPPING FOR hword, hword_part, word WITH unaccent, spanish_stem;
    SQL

    # Posts: título (peso A) + descripción (peso B).
    execute <<~SQL
      ALTER TABLE posts ADD COLUMN searchable tsvector
        GENERATED ALWAYS AS (
          setweight(to_tsvector('spanish_unaccent', coalesce(title, '')), 'A') ||
          setweight(to_tsvector('spanish_unaccent', coalesce(description, '')), 'B')
        ) STORED;
    SQL
    execute "CREATE INDEX index_posts_on_searchable ON posts USING gin (searchable);"
    # Trigram sobre el título para tolerar tipeos en la parte más buscada.
    execute "CREATE INDEX index_posts_on_title_trigram ON posts USING gin (title gin_trgm_ops);"

    # Personas: usuario y titular (peso A) + bio (peso B).
    execute <<~SQL
      ALTER TABLE users ADD COLUMN searchable tsvector
        GENERATED ALWAYS AS (
          setweight(to_tsvector('spanish_unaccent', coalesce(username, '')), 'A') ||
          setweight(to_tsvector('spanish_unaccent', coalesce(headline, '')), 'A') ||
          setweight(to_tsvector('spanish_unaccent', coalesce(bio, '')), 'B')
        ) STORED;
    SQL
    execute "CREATE INDEX index_users_on_searchable ON users USING gin (searchable);"
    execute "CREATE INDEX index_users_on_username_trigram ON users USING gin (username gin_trgm_ops);"
  end

  def down
    execute "DROP INDEX IF EXISTS index_users_on_username_trigram;"
    execute "DROP INDEX IF EXISTS index_users_on_searchable;"
    execute "ALTER TABLE users DROP COLUMN IF EXISTS searchable;"
    execute "DROP INDEX IF EXISTS index_posts_on_title_trigram;"
    execute "DROP INDEX IF EXISTS index_posts_on_searchable;"
    execute "ALTER TABLE posts DROP COLUMN IF EXISTS searchable;"
    execute "DROP TEXT SEARCH CONFIGURATION IF EXISTS spanish_unaccent;"
    # Las extensiones se dejan: pueden estar en uso por otras cosas.
  end
end
