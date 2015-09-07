class Payment < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  def total
    Money.new(read_attribute(:total), 'GBP')
  end
end
