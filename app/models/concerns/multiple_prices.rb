module MultiplePrices
  extend ActiveSupport::Concern
  included do
    store_accessor :prices, :cost_price_cents, :price_level_0_cents, :price_level_1_cents, :price_level_2_cents, :price_level_3_cents

    # TODO not break this.
    # [:price_level_0, :price_level_1, :price_level_2, :price_level_3, :cost_price].each do |price_level|
    #   # monetize "#{price_level}_cents", allow_nil: true, numericality: {greater_than_or_equal_to: 0}
    # end

  end
end