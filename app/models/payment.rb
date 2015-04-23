class Payment < ActiveRecord::Base
  belongs_to :user

  def total
    Money.new(read_attribute(:total), 'GBP')
  end
end
