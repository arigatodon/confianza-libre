namespace :credit do
  desc "Recalcula cached_balance de todas las cuentas desde el ledger. Reporta qué cambió."
  task reconcile: :environment do
    drifted = 0
    Account.find_each do |a|
      expected = BalanceReconciler.call(a)
      next if a.cached_balance == expected

      owner =
        case a.account_type
        when "user"      then "user=#{a.user&.username || a.user_id}"
        when "community" then "territory=#{a.territory&.slug || a.territory_id}"
        else                  a.account_type
        end

      diff = expected - a.cached_balance
      sign = diff.positive? ? "+" : ""
      puts "  ##{a.id} #{a.account_type.ljust(10)} #{owner.ljust(28)} #{a.cached_balance} → #{expected} (#{sign}#{diff})"
      a.update_column(:cached_balance, expected)
      drifted += 1
    end

    puts ""
    if drifted.zero?
      puts "Sin drift: todas las cuentas calzaban con el ledger."
    else
      puts "Reconciliadas #{drifted} cuenta(s)."
    end
    puts "Σ cached_balance = #{Account.sum(:cached_balance)} (debe ser 0 si la partida doble está sana)."
  end
end
