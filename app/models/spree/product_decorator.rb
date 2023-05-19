module Spree::ProductDecorator
  include Spree::BaseHelper

  def self.prepended(base)
    base.searchkick text_middle: [:name, :producer_name, :taxon_names, :meta_keywords], settings: { number_of_replicas: 0 } unless base.respond_to?(:searchkick_index)

    def base.search_fields
      ['name^100', 'producer_name', 'taxon_names', 'meta_keywords']
    end

    def base.autocomplete(keywords, stock_locations, current_store_id)
      # if keywords && keywords != '%QUERY'
      #   Spree::Product.search(
      #     keywords,
      #     fields: search_fields,
      #     match: :text_middle,
      #     load: false,
      #     misspellings: { below: 2, edit_distance: 2 },
      #     where: search_where(stock_locations, current_store_id),
      #     ).map(&:name).map(&:strip)
      # else
      puts "keywords: #{keywords}"
        Spree::Product.search(
          keywords!= '%QUERY' ? keywords : '*',
          fields: search_fields,
          load: false,
          misspellings: { below: 2, edit_distance: 2 },
          where: search_where(stock_locations, current_store_id),
          limit: 100,
          ).map{|p| {
            n: p.name&.strip || '',
            p: p.producer_name&.strip || '',
            t: p.taxon_names.join(' '),
            k: p.meta_keywords&.strip || '',
            i: p.image_url }}
        # end
      end

      def base.search_where(stock_locations, current_store_id)
        res = {
          stock_location_ids: stock_locations,
          price: { not: nil },
          available: true
        }

          if current_store_id.present? && current_store_id != 1 && current_store_id != 2
            res[:_and] = [{store_ids: [current_store_id]}, {store_ids: { not: [2] }}]
          else
            # filtramos solo para cada tienda, excepto lomi.cl (marketplace)
            res[:store_ids] = [current_store_id] if current_store_id.present? && current_store_id != 1
  
            # filtramos lomiexpress.cl para el marketplace
            res[:store_ids] = { not: [2] } if current_store_id.present? && current_store_id != 2
          end
        res
      end

      def base.sorted
        order_params = {}
        order_params[:name] = :asc
        order_params
      end
    end

    def search_data
      stock_location_ids = stock_items.where('count_on_hand > 0 OR backorderable = TRUE')
                                      .pluck(:stock_location_id).uniq
      json = {
        name: name,
        available: !deleted? && !discontinued?,
        stock_location_ids: (stock_location_ids.blank? ? nil : stock_location_ids),
        created_at: created_at,
        updated_at: updated_at,
        price: price,
        currency: currency,
        conversions: orders.complete.count,
        producer_name: producer&.name,
        producer: producer&.id,
        taxon_ids: taxon_and_ancestors.map(&:id),
        taxon_names: taxon_and_ancestors.map{|taxon| taxon.name if taxon.depth != 0}.compact,
        meta_keywords: meta_keywords,
        store_ids: (store_ids.blank? ? nil : store_ids),
        image_url: (Rails.application.routes.url_helpers.rails_public_blob_url(default_image_for_product_or_variant(self)&.attachment) rescue '')
      }

      Spree::Property.all.each do |prop|
        json.merge!(Hash[prop.name.downcase, property(prop.name)])
      end

      Spree::Taxonomy.all.each do |taxonomy|
        json.merge!(Hash["#{taxonomy.name.downcase}_ids", taxon_by_taxonomy(taxonomy.id).map(&:id)])
      end

      json
    end

    def taxon_by_taxonomy(taxonomy_id)
      taxons.joins(:taxonomy).where(spree_taxonomies: { id: taxonomy_id })
    end
  end

  Spree::Product.prepend(Spree::ProductDecorator)

  