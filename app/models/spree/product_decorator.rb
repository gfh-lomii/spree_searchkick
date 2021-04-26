module Spree::ProductDecorator
  include Spree::BaseHelper

  def self.prepended(base)
    base.searchkick text_middle: [:name, :producer_name, :taxon_names, :meta_keywords], settings: { number_of_replicas: 0 } unless base.respond_to?(:searchkick_index)

    def base.search_fields
      ['name^100', 'producer_name', 'taxon_names', 'meta_keywords']
    end

    def base.autocomplete(keywords)
      if keywords && keywords != '%QUERY'
        Spree::Product.search(
          keywords,
          fields: search_fields,
          match: :text_middle,
          load: false,
          misspellings: { below: 2, edit_distance: 2 },
          where: search_where,
          ).map(&:name).map(&:strip)
      else
        Spree::Product.search(
          "*",
          fields: search_fields,
          load: false,
          misspellings: { below: 2, edit_distance: 2 },
          where: search_where,
          ).map{|p| {
            n: p.name&.strip || '',
            p: p.producer_name&.strip || '',
            t: p.taxon_names.join(' '),
            k: p.meta_keywords&.strip || '',
            i: p.image_url }}
        end
      end

      def base.search_where
        {
          stock_location_ids: { not: nil },
          price: { not: nil },
        }
      end

      def base.sorted
        order_params = {}
        order_params[:name] = :asc
        order_params
      end
    end

    def search_data
      stock_location_ids = stock_items.where('count_on_hand > 0').pluck(:stock_location_id).uniq
      json = {
        name: name,
        stock_location_ids: (stock_location_ids.blank? ? nil : stock_location_ids),
        created_at: created_at,
        updated_at: updated_at,
        price: price,
        currency: currency,
        conversions: orders.complete.count,
        producer_name: producer&.name,
        producer: producer&.id,
        taxon_ids: taxon_and_ancestors.map(&:id),
        taxon_names: taxon_and_ancestors.map{|taxon| taxon.name if taxon.taxonomy_id == 4 && taxon.depth != 0 && !taxon.name.include?(" y ")}.compact,
        meta_keywords: meta_keywords,
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
