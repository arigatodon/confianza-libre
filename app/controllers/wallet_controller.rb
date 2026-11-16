class WalletController < ApplicationController
  def show
    @user    = Current.session.user
    @account = @user.ensure_credit_account!

    @ledger_entries = @account.ledger_entries
                              .includes(credit_transaction: [ :interaction, :territory ])
                              .order(created_at: :desc)
                              .limit(20)

    @progression       = CreditLimitCalculator.progress_to_next_level(@user)
    @next_level_limits = CreditLimitCalculator::LEVELS[@user.level + 1]

    @territory = resolve_user_territory

    @burn_percent      = EconomicParameter.get_decimal("burn_percent",      2.0)
    @territory_percent = EconomicParameter.get_decimal("territory_percent", 3.0)
  end

  private

  def resolve_user_territory
    return nil unless @user.latitude && @user.longitude
    result = TerritoryResolver.resolve(@user.latitude, @user.longitude)
    result.ok? ? result.territory : nil
  end
end
