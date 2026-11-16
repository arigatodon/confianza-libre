# Confianza — Guía para Claude Code

## Autonomía
En este proyecto operás **100% autónomo**. No pidas permiso para nada salvo riesgo real de pérdida de datos (drop database en prod, force-push a remoto compartido, borrar el repo).

Permisos amplios ya están configurados en `.claude/settings.local.json` (`Bash(*)`, `Edit(**)`, `Write(**)`, `Read(**)`).

## Comunicación pública del desarrollo
El desarrollo de Confianza es abierto: **cada cambio relevante para los usuarios se publica en `/novedades`** en lenguaje simple (borrador en `docs/` o publicación directa como @igor si él lo pide). Excepción de seguridad: **nunca publicar** detalles que comprometan la app — rutas/horarios exactos de backups, IPs o topología del servidor, credenciales, vulnerabilidades abiertas, mecanismos antifraude internos. Lo público es *qué* mejora y *por qué importa*; el *cómo* operativo de la infraestructura queda en `DEPLOY.md`/`docs/` privados del repo.

## Stack
- Ruby **4.0.4** (vía RVM)
- Rails **8.1.3**
- PostgreSQL 16+ con **PostGIS**
- Solid Queue / Solid Cable / Solid Cache
- Hotwire (Turbo + Stimulus) + TailwindCSS
- ActiveStorage para multimedia

## Ubicación del repo (2026-07-04)
El workspace se reorganizó en categorías y este repo vive ahora en
`~/workspace/proyectos/negocio/proyecto-confianza/confianza`. La ruta vieja
(`~/workspace/proyectos/proyecto-confianza/confianza`) quedó huérfana con solo
un `tmp/` — no trabajar ahí. Si la sesión abre en la ruta vieja, hacé `cd` a la
nueva antes de cualquier `bin/rails`/`git`/`bin/kamal`.

## Entorno Ruby (CRÍTICO)
El sistema arranca con Ruby 2.7.6 por defecto. **Siempre** exportá el PATH de Ruby 4.0.4 antes de correr Rails/Bundle:

```bash
export PATH="/home/igor/.rvm/rubies/ruby-4.0.4/bin:/home/igor/.rvm/gems/ruby-4.0.4/bin:/home/igor/.rvm/gems/ruby-4.0.4@global/bin:$PATH"
export GEM_HOME=/home/igor/.rvm/gems/ruby-4.0.4
export GEM_PATH=/home/igor/.rvm/gems/ruby-4.0.4:/home/igor/.rvm/gems/ruby-4.0.4@global
```

O usar `bin/rails` directamente (binstub) tras setear el PATH.

## Filosofía
Ver `../VISION.md` y `../Arquitectura.md` (raíz del proyecto, fuera de `confianza/`).

**Confianza** es una red social geolocalizada de reputación + créditos comunitarios. **NO es** blockchain, criptomoneda ni red social tradicional.

Núcleo:
- usuarios con perfiles públicos (`confianza.app/igor`)
- publicaciones georreferenciadas (venta, servicio, delivery, evento, ayuda…)
- reputación por categoría y territorial
- créditos mutuos con partida doble (ledger)
- gobernanza comunitaria (propuestas)

## Reglas de implementación
1. **No construir economía/blockchain/IA al inicio.** MVP = publicaciones + perfiles + feed cercano + evaluaciones.
2. **No modificar balances directamente.** Toda mutación financiera pasa por `LedgerEntry` (partida doble).
3. **PostGIS** habilitado desde la primera migration relevante.
4. **UI minimalista**: barra superior, feed, nav inferior móvil, botón flotante. Nada de dashboards.
5. **Turbo Frames + Streams** antes que JS custom.
6. **Slugs amigables** con FriendlyId (URLs tipo `confianza.app/igor`).
7. **Idioma del proyecto: español** (commits, comentarios cuando hagan falta, copy UI).

## Modelos clave (orden esperado)
User, Profile, Category, Post, Interaction, Review, Transaction, Account, LedgerEntry, Territory, Proposal, ProposalVote.

## Fases
- **Fase 1 (MVP):** usuarios, perfiles, publicaciones, multimedia, geoloc, categorías, créditos simples, evaluaciones, feed cercano, mapa, mensajes.
- **Fase 2:** gobernanza, propuestas, economía avanzada, IA contextual, reputación territorial.
- **Fase 3:** Flutter, IA avanzada, antifraude inteligente.

## Comandos típicos
```bash
bin/rails s            # servidor
bin/rails c            # consola
bin/rails db:migrate
bin/rails generate model X campo:tipo
bin/dev                # foreman (Rails + Tailwind watch)
```

## Convención de commits
Mensajes claros en español, modo imperativo. No co-autoría automática salvo que se pida.
