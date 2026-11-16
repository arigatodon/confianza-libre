namespace :novedades do
  desc "Envía el digest de novedades por email a usuarios activos verificados y deja la notificación in-app"
  task digest: :environment do
    # La campana apunta a la última novedad publicada (si existe).
    ultima = Announcement.published.recent.first
    users  = User.where(status: :active).where.not(email_verified_at: nil)

    puts "Enviando digest a #{users.count} usuario(s)…"
    enviados = 0

    users.find_each do |user|
      NewsMailer.novedades_digest(user).deliver_now

      if ultima && !Notification.exists?(recipient: user, notifiable: ultima, kind: "news")
        Notification.create!(
          recipient:  user,
          notifiable: ultima,
          kind:       "news",
          body:       "Novedad: #{ultima.title}. Pasa a ver qué cambió."
        )
      end

      enviados += 1
      puts "  ✓ @#{user.username} <#{user.email_address}>"
    rescue => e
      puts "  ✗ @#{user.username}: #{e.class} — #{e.message}"
    end

    puts "Listo: #{enviados}/#{users.count} enviados."
  end

  desc "Envía las novedades + link de verificación a cuentas activas sin email verificado"
  task verifica: :environment do
    users = User.where(status: :active, email_verified_at: nil)
    puts "Enviando novedades + verificación a #{users.count} usuario(s) sin verificar…"
    enviados = 0

    users.find_each do |user|
      NewsMailer.novedades_verifica(user).deliver_now
      enviados += 1
      puts "  ✓ @#{user.username} <#{user.email_address}>"
    rescue => e
      puts "  ✗ @#{user.username}: #{e.class} — #{e.message}"
    end

    puts "Listo: #{enviados}/#{users.count} enviados."
  end
end
