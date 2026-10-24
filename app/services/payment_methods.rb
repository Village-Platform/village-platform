# Where firm owners send their subscription payment. Configured with ENV so numbers never live in code.
module PaymentMethods
  def self.all
    [
      { key: "instapay", name: I18n.t("payment_methods.instapay"), account: ENV["INSTAPAY_ADDRESS"] },
      { key: "vodafone_cash", name: I18n.t("payment_methods.vodafone_cash"), account: ENV["VODAFONE_CASH_NUMBER"] }
    ]
  end
end
