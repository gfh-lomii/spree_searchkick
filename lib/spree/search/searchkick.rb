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
        where_query[:taxon_ids] = taxon if taxon
        where_query[:producer] = producer if producer
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
      end
    end
  end
end
