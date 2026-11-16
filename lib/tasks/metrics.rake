namespace :metrics do
  desc "Métrica norte de la Fase 2.2: % de pedidos que reciben ≥1 interacción en 72h."
  task pedidos_match: :environment do
    ventana = (ENV["DAYS"] || "30").to_i.days
    desde   = ventana.ago

    # Sólo pedidos con edad suficiente para haber completado su ventana de 72h.
    pedidos = Post.pedidos.where(created_at: desde..72.hours.ago)
    total   = pedidos.count

    if total.zero?
      puts "Sin pedidos elegibles en los últimos #{(ventana / 1.day).to_i} días (necesitan ≥72h de antigüedad)."
      next
    end

    con_interaccion = pedidos.select do |p|
      p.interactions.where(created_at: ..(p.created_at + 72.hours)).exists?
    end.size

    pct = (con_interaccion.to_f / total * 100).round(1)
    puts "Pedidos elegibles: #{total}"
    puts "Con ≥1 interacción en 72h: #{con_interaccion}"
    puts "Métrica norte 2.2: #{pct}%"
  end
end
