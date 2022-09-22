module Spree
  module Search
    class Searchkick < Spree::Core::Search::Base
      def retrieve_products
        @products = base_elasticsearch
      end

      def base_elasticsearch
        puts where_query
        curr_page = page || 1
        Spree::Product.search(
          keyword_query,
          fields: Spree::Product.search_fields,
          match: :word,
          misspellings: { below: 2, edit_distance: 2 },
          where: where_query,
          aggs: aggregations,
          smart_aggs: true,
          order: sorted,
          page: curr_page,
          per_page: per_page,
        )
      end

      def where_query
        where_query = {
          stock_location_ids: { not: nil },
          currency: current_currency,
          price: { not: nil },
          available: true
        }
        where_query[:taxon_ids] = { all: taxon_ids } if taxon_ids.any?
        where_query[:producer] = producer if producer

        # filtramos solo para cada tienda, excepto lomi.cl (marketplace)
        where_query[:store_ids] = current_store_id if current_store_id.present? && current_store_id != 1

        # filtramos lomiexpress.cl para el marketplace
        where_query[:store_ids] = { not: 2 } if current_store_id.present? && current_store_id != 2

        where_query[:stock_location_ids] = stock_location_ids if stock_location_ids
        add_search_filters(where_query)
      end

      def keyword_query
        keywords.nil? || keywords.empty? ? "*" : keywords
      end

      def sorted
        order_params = {}
        order_params[:name] = :asc unless @properties[:ignore_search]
        order_params
      end

      def aggregations
        fs = []
        Spree::Taxonomy.filterable.each do |taxonomy|
          fs << taxonomy.filter_name.to_sym
        end
        Spree::Property.filterable.each do |property|
          fs << property.filter_name.to_sym
        end
        fs
      end

      def add_search_filters(query)
        return query unless search
        search.each do |name, scope_attribute|
          query.merge!(Hash[name, scope_attribute])
        end
        query
      end

      def prepare(params)
        super
        @properties[:ignore_search] = params[:ignore_search]
        @properties[:producer] = params[:producer]
        @properties[:stock_location_ids] = params[:stock_location_ids]
        @properties[:current_store_id] = params[:current_store_id]
        taxon_ids = [taxon]
        if params[:property].present?
          taxon_ids << Spree::Taxon.where(permalink: params[:property].split(',').compact.uniq).ids
        end
        @properties[:taxon_ids] = taxon_ids.flatten
      end
    end
  end
end
