##
# This class represents an article written on the Vallelaghi.it site
class Article

  attr_reader :title, :link, :description
  
  ##
  # Creates a new article
  #
  # It initializes the title, the link and the description field, which are  
  # readable using the getter methods.
  def initialize(title, link, description)
    @title = title
    @link = link
    @description = description
  end
end