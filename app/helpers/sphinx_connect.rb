module SphinxConnect
  def sphinx_connect
    sphinx_ports = {"production" => 9312, "development" => 9313, "test" => 9314}
    # Tricking the mysql2 gem to actually connect to searchd, so only the port and host matter here
    $sphinx_client = Mysql2::Client.new(:port => sphinx_ports[Rails.env], :host => "127.0.0.1", :username => "root", :password => "", :database => "dummy")
  end
  
  def search_by_sphinxql(sphinxql_str)
    match_sentence = sphinxql_str.match(/match\(\'(.*)\'\)/).captures[0]
    match_sentence = sphinx_escape match_sentence
    sphinxql_str.gsub!(/match\(\'.*\'\)/, "match('"+match_sentence+"')")
    # collecting matching documents ids and weights
    begin
      search_results = exec_sphinx_select(sphinxql_str)
    rescue Exception # the connection might be down ($sphinx_client=nil or Mysql2::Error raised), so we re-connect and try again
      begin
        sphinx_connect # re-connect
        search_results = exec_sphinx_select(sphinxql_str) # try again
      rescue Mysql2::Error => e # There is a real error
        Rails.logger.error "  Sphinx Error in #{__FILE__} line #{__LINE__}: Can't retrieve data because '#{e.message}' on #{sphinxql_str}"
        return nil
      end
    end
    return search_results
  end
  
  def exec_sphinx_select(sphinxql_str)
    search_results = $sphinx_client.query sphinxql_str
    Rails.logger.info "  #{search_results.count} Results SphinxQL (?ms) "+sphinxql_str
    return search_results
  end
  
  def sphinx_escape(str)
    str.gsub!(/[\:\=\+\(\)\,\;\.\%\$_\<\>\@\#\!]/, "")
    str.match(/^\|*(.*?)\|*$/).captures[0]
  end
end