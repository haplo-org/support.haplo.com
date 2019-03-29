# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


require 'RedCloth'

class DocNode
  attr_accessor :name
  attr_accessor :parent
  attr_accessor :children # hash of name -> node
  attr_accessor :attributes # hash of symbol -> string
  attr_accessor :ordering
  attr_accessor :filename

  def initialize(name, parent = nil)
    @name = name
    @parent = parent
    @children = Hash.new
    @attributes = Hash.new
  end

  def title
    @attributes[:title]
  end

  def long_title
    @attributes[:long_title] || @attributes[:title]
  end

  def title_for_toc
    @attributes[:use_long_title_for_toc] ? @attributes[:long_title] : @attributes[:title]
  end

  def replace_with(node)
    node.parent = @parent
    @parent.children[self.name] = node if @parent != nil
    node.children = @children
    @children.each_value { |child| child.parent = node }
    node
  end

  def body_html
    raise "body_html not implemented"
  end

  def check_node
    # Just make sure HTML can be generated and isn't blank
    html = body_html
    if html !~ /\S/
      puts "WARNING: Generated HTML is blank for #{self.url_path}"
    end
  end

  def url_path
    @url_path = begin
      nodes = []
      scan = self
      while scan != nil
        nodes.unshift scan
        scan = scan.parent
      end
      p = nodes.map { |n| n.name } .join('/')
      p = '/' if p.length == 0
      p
    end
  end

  def sorted_children
    @children.values.sort do |a, b|
      if a.ordering == nil && b.ordering == nil
        a.title.downcase <=> b.title.downcase
      else
        (a.ordering || 99999) <=> (b.ordering || 99999)
      end
    end
  end

  # Returns a an array [kind of anchor point, heading title], or nil if it doesn't exist
  def anchor_point_info(name)
    nil
  end
end

class DocNodeWithHeaders < DocNode
  def read_file(filename)
    File.open(filename) do |f|
      while (line = f.gets) != nil
        line.chomp!
        break if line == '--'
        k, v = line.split(/\s*:\s*/, 2)
        @attributes[k.to_sym] = v
      end
      use_body(f.read)
    end
    if @attributes.has_key?(:class) && self.class.name != @attributes[:class]
      # Class name specified - try again with that node type
      klass = Kernel.const_get(@attributes[:class])
      raise "Bad name" unless klass.kind_of?(Class)
      node = klass.new(self.name)
      return node.read_file(filename)
    end
    self
  end
  def use_body(body)
    raise "Must implement use_body"
  end
end

class DocNodeTextile < DocNodeWithHeaders
  def use_body(body)
    @textile = body
  end

  # Override in derived classes
  def body_textile
    @textile
  end

  def body_html
    body = DocImages.replace_image_markers_with_html(body_textile, self.url_path)
    html = RedCloth.new(body, [:no_span_caps]).to_html
    # Anchor points for headings
    ids_used_in_template = Documentation.get_ids_used_in_template
    # 1) Search for duplicates where the long name should be used
    dup_detect = Hash.new(0)
    html.scan(/(<h[2-9][^>]*>([A-Za-z0-9\. ]+).*?<\/h\d>)/) do
      dup_detect[$2.gsub(/[^A-Za-z0-9]+/,'_')] += 1
    end
    # 2) Actually add in the anchor points, generating @anchor_point_info as we go
    ids = Hash.new
    @anchor_point_info = Hash.new
    html.gsub!(/(<h[2-9][^>]*>(.*?)<\/h\d>)/) do
      # Determine link name, and perform checks
      heading = $1
      full_text = $2.gsub(/<[^>]+>/,'').gsub(/\&\#\d+\;/,'') # remove HTML elements and entities from title, eg textile's caps span element
      # Find the bit before any special characters
      full_text =~ /\A([A-Za-z0-9\. :-]+)/
      link_name = $1.gsub(/[^A-Za-z0-9]+/,'_')
      link_name = full_text.gsub(/[^A-Za-z0-9]+/,'_') if dup_detect[link_name] > 1
      link_name.gsub!(/_+\z/,'')
      link_name += '_' if ids_used_in_template.has_key? link_name
      if ids.has_key? link_name
        # Duplicate, ignore the next ones and just return this heading unaltered
        heading
      else
        raise "Heading id '#{link_name}' in #{self.url_path} uses a generated id used by the template, even with _ appended" if ids_used_in_template.has_key? link_name
        ids[link_name] = true
        # Set the anchor point info
        kind = 'heading'
        kind = $1 if heading =~ /class="([^"]+)"/
        @anchor_point_info[link_name] = [kind, full_text.gsub(/\(.+?\)/,'()')] # collapse arguments
        # Add an anchor point into the generated HTML
        %Q!<div id="#{link_name}" class="anchor_point"></div>#{heading}!
      end
    end
    # Quick hack to make NAME() work, avoiding confusion with Textile acronym syntac ABC(Apple Bananas Carrots)
    html.gsub!('NAME (', 'NAME(')
    # Return processed HTML
    html
  end

  def anchor_point_info(name)
    # The anchor point info is generated by the body_html function
    body_html unless @anchor_point_info != nil
    # Just return the info generated bfore
    @anchor_point_info[name]
  end

  # For adding information to a page, eg from scripts
  def append_textile(more_textile)
    @textile = @textile + more_textile
    @filename = nil
  end
end

class DocNodeTextileWithTOC < DocNodeTextile
  def body_textile
    # Build the TOC
    toc = ''
    self.sorted_children.each do |node|
      toc << "[node:#{node.url_path}:#{node.title_for_toc}]\n"
    end
    # Get body from super
    body = super
    # If it's a page which ends in a END_PRELIMINARY marker, put the toc behind it, otherwise just append
    if body =~ /END_PRELIMINARY\s*\z/m
      body = body.gsub(/END_PRELIMINARY(\s*)\z/) do
        "\n\n#{toc}\n\nEND_PRELIMINARY#{$1}"
      end
    else
      body = "#{body}\n\n#{toc}"
    end
    # Return
    body
  end
end
