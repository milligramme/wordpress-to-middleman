
# Input: WordPress XML export file.
# Outputs: a series of Markdown files ready to be included in a middleman site

require 'rubygems'
require 'nokogiri' 
require 'upmark'   
require 'html2md'
require 'time'
require 'fileutils'

# SETTINGS #
WORDPRESS_XML_FILE_PATH = "#{ENV['PWD']}/wordpress.xml"  # THE LOCATION OF THE EXPORTED WORDPRESS ARCHIVE #
OUTPUT_PATH = "#{ENV['PWD']}/export/_posts/"  # THE LOCATION OF THE SAVED POSTS #
ORIGINAL_DOMAIN = "http://perpetuallybeta.com"  #  THE DOMAIN OF THE WEBSITE #
SEPARATE_CATEGORIES_FROM_TAGS = false
CONVERT_FROM_HTML = false
MARKDOWN_EXT = ".md"
FIX_OVERLAP = true # fix for overlapping sanitized name


class Parser

  def self.make_output_path
    unless File.directory?(OUTPUT_PATH)
        FileUtils.mkdir_p(OUTPUT_PATH)
        puts "Saving all files in" + OUTPUT_PATH.to_s
    end
  end

  def self.xml_to_hash
    # xml = Nokogiri::HTML(open(WORDPRESS_XML_FILE_PATH.gsub("CDATA", "")))
    f = File.open(WORDPRESS_XML_FILE_PATH)
    xml = Nokogiri::XML(f)
    posts = xml.css("item")
    
    posts.each do |post|

      # Parsing Post Frontmatter
      # ------------------------------------
      
      original_url = post.css("link").text
      
      title = post.css("title").text
      title.gsub!(":", "-")
      begin
      	post_date = post.xpath("wp:post_date").first.inner_text
      rescue Exception => e
        p e
      end
      
      if post_date.nil?
        created_at = "1970-01-01 00:00:00"
      else
      	created_at = Date.parse(post_date).to_s
      end
      
      tags = ""
      categories = ""
      category_xml = post.xpath("category")

      if SEPARATE_CATEGORIES_FROM_TAGS == true
        category_xml.each do |category|
          if category.css("@domain").to_s == "category"
            categories += category.css("@nicename").text + ", "
          else
            tags += category.css("@nicename").text + ", "
          end
        end
      else
        category_xml.each do |category|
          tags += category.css("@nicename").text + ", "
        end
      end

      # Parsing Post Content
      # ------------------------------------
      # content = post.at_xpath(".//content:encoded").to_s
      content = post.at_xpath(".//content:encoded").inner_text

      # Cleaning up the HTML output of content
      # content.gsub!("<encoded>", " ")
      # content.gsub!("</encoded>", " ")
      # content.gsub!("&gt;", " ")
      # content.gsub("<![CDATA[", " ")
      # content.gsub!("]];", " ")
      # content.gsub!("]]>;", " ")
      
      # Converting HTML output to Markdown

      # do a crude test for html tags
      if CONVERT_FROM_HTML && /</ =~ content && />/ =~ content
        content.gsub!(/(\r?\n\r?\n)/, "XXXXXXXXXX") # preserve double newline as token
        content.gsub!(/\n(<.+>)/, "<br><br>\\1") # add newline before html tags
        md_content = Html2Md.new(content)
        content = md_content.parse
        content.gsub!(/(XXXXXXXXXX)+/, "\n\n") # remove token and replace with double newline
      end

      content.gsub! /\n\s*\n/, "\n\n" # collapse newlines

      if !(created_at.nil? || title.nil? || post_date.nil? || content.nil?)
        output_filename = OUTPUT_PATH + created_at + "-" + sanitize_filename(title) + rand_hex_suffix(FIX_OVERLAP) + MARKDOWN_EXT
        puts output_filename

        file_content = "---" + "\n"
        file_content += "title: " + title + "\n"
        file_content += "date: " + created_at + "\n"
        file_content += "tags: " + tags + "\n"
        file_content += "orginal_url: " + original_url + "\n"
        if SEPARATE_CATEGORIES_FROM_TAGS == true
          file_content += "categories: " + categories + "\n" unless categories.empty?
        end
        file_content += "---" + "\n"
        file_content += content

        # Saving File
        # ------------------------------------
        File.open(output_filename, "w") do |f|     
          f.write(file_content)
        end
      end
    end
  end

  def self.sanitize_filename(filename)
    filename.gsub(/[^\w\s_-]+/, '')
            .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
            .gsub(/\s+/, '_')
            .downcase
  end

  def self.rand_hex_suffix(add=false)
    require "securerandom"
    return add ? "_" + SecureRandom.hex(2) : ""
  end

end

Parser.make_output_path
Parser.xml_to_hash


