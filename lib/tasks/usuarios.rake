namespace :usuarios do
  desc "Correo personal a verificados que no volvieron. Por defecto solo lista; ENVIAR=1 para mandar"
  task reactivar: :environment do
    enviar = ENV["ENVIAR"] == "1"
    users = User.where(status: :active, admin: false, reactivation_sent_at: nil)
                .where.not(email_verified_at: nil)
                .where(created_at: ...7.days.ago)
                .where.not(id: Session.where(updated_at: 14.days.ago..).select(:user_id))

    puts "#{enviar ? "Enviando" : "[simulación] Se enviaría"} a #{users.count} usuario(s):"
    users.find_each do |user|
      if enviar
        ReactivacionMailer.vuelve(user).deliver_now
        user.update_column(:reactivation_sent_at, Time.current)
      end
      puts "  ✓ @#{user.username} (publicaciones: #{user.posts.visible.count})"
    rescue => e
      puts "  ✗ @#{user.username}: #{e.class} — #{e.message}"
    end
    puts "Para enviar de verdad: bin/rails usuarios:reactivar ENVIAR=1" unless enviar
  end
end
