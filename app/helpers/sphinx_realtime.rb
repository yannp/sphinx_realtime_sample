module SphinxRealtime
  include SphinxConnect

  def self.included(klass)
    klass.send :after_create, :sphinx_insert
    klass.send :after_save, :sphinx_replace
    klass.send :after_destroy, :sphinx_delete
  end

  # these three declarations are not especially related to real-time indexes but it's easy to have it here
  attr_accessor :weight
  
  SphinxIndexes = { 
    "articles" => ["id", "title", "body", "author_name"],
    "articlecomments" => ["id", "body", "author_name", "commentable_id"],
  }
  
  def sphinx_insert
    exec_sphinx_cmd(:insert)
  end
  
  def sphinx_replace
    exec_sphinx_cmd(:replace)
  end
  
  def sphinx_delete
    exec_sphinx_cmd(:delete)
  end
  
  #### "Private" methods ####
  def sphinx_index_name
    self.class.to_s.downcase.pluralize
  end
  
  def exec_sphinx_cmd(type)
    sphinx_method_switch(type)
  rescue Exception # the connection might be down ($sphinx_client=nil or Mysql2::Error raised), so we re-connect and try again
    begin
      sphinx_connect
      sphinx_method_switch(type)
    rescue Mysql2::Error => e # There is a real error
      logger.error "Sphinx Error in #{__FILE__} line #{__LINE__}: Can't update index (#{e.message})"
      return nil
    end
  end
  
  def sphinx_method_switch(type)
    if type == :insert
      exec_sphinx_insert
    elsif type == :replace
      exec_sphinx_insert(true)
    elsif type == :delete
      exec_sphinx_delete
    end
  end
  
  def exec_sphinx_delete
    q = "DELETE FROM #{sphinx_index_name} WHERE id=#{self.id}"
    $sphinx_client.query q
    logger.info "SphinxQL (?ms) "+q
  end
  
  def exec_sphinx_insert(replace=false)
    replace ? query_title = "REPLACE" : query_title = "INSERT"
    i = sphinx_index_name
    field_list = ""
    value_list = ""
    SphinxIndexes[i].each do |f|
      field_list += "#{f},"
      value_list += "'#{$sphinx_client.escape(self.send(f))}',"
    end
    value_list.chop!
    field_list.chop!
    q = "#{query_title} INTO #{i} (#{field_list}) VALUES (#{value_list})"
    $sphinx_client.query q
    logger.info "SphinxQL (?ms) "+q
  end
end