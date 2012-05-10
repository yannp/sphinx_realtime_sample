require "#{Rails.root}/app/helpers/sphinx_connect"
include SphinxConnect

class ActiveRecord::Base
  def self.search(options)
    t = table_name()
    SphinxConnect::sphinx_connect() if not $sphinx_client
    q = SphinxConnect::sphinx_escape options[:query]
    sphinxql_str = "SELECT * FROM #{t} WHERE match('#{$sphinx_client.escape(q)}')"
    # GROUP BY
    sphinxql_str += " OPTION field_weights=(#{options[:field_weights]})" if options and options[:field_weights]
    
    search_results = SphinxConnect::search_by_sphinxql sphinxql_str
    load_models_after_sphinx search_results
  rescue Exception => e
    Rails.logger.error "Sphinx Error in #{__FILE__} line #{__LINE__}: Can't connect to searchd (#{e.message})"
    return nil
  end
  
  def self.load_models_after_sphinx(search_results, place_kind=nil)
    return nil if not search_results
    ids = search_results.collect { |row| row["id"] }
    weight_name = nil
    place_kind ? weight_name = "my_weight" : weight_name = "weight"
    weights = search_results.collect { |row| row[weight_name].to_i }

    # find and order the models according to sphinx relevance order
    order_hash = {}
    ids.each_with_index { |id, index| order_hash[id] = index }
    ar_results = find_all_by_id(ids).sort_by { |m| order_hash[m.id] } # preloading of models
    
    # insert the weights into the models
    cnt = 0
    ar_results.each do |r|
      r.weight = weights[cnt]
      cnt += 1
    end
    return ar_results
  end
end
