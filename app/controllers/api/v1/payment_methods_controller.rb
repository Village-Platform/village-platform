module Api
  module V1
    class PaymentMethodsController < BaseController
      # GET /api/v1/payment_methods  -> where to send the subscription payment
      def index
        render json: { data: PaymentMethods.all }
      end
    end
  end
end
