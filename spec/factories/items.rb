FactoryBot.define do
  factory :item do
    post
    sequence(:url) { |n| "https://example.com/images/#{n}.jpg" }
  end
end
