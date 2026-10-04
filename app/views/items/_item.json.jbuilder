json.extract! item, :id, :post_id, :url, :created_at, :updated_at
json.image_url item.image.attached? ? url_for(item.image) : nil
