# Raised by a policy when the user owns the record but needs a current subscription to manage it.
# A NotAuthorizedError, so it is still a 403; ErrorHandling answers it with the
# subscription_required code so the app can offer a renewal instead of a dead end.
class SubscriptionRequired < Pundit::NotAuthorizedError; end
