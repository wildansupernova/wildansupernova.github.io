module Jekyll
  module HeaderNumbering
    def self.number_headers(content)
      # Initialize counters
      h1_count = 0
      h2_count = 0
      h3_count = 0
      h4_count = 0
      h5_count = 0
      h6_count = 0

      # Process each line - fixed regex syntax
      content.gsub(/^(\#{1,6})\s+(.+)$/) do |match|
        level = $1.length
        title = $2.strip
        
        # Skip if the header already has numbering (contains digits and dots at the start)
        next match if title.match(/^\d+(\.\d+)*\.?\s/)
        
        case level
        when 1
          h1_count += 1
          h2_count = 0
          h3_count = 0
          h4_count = 0
          h5_count = 0
          h6_count = 0
          "# #{h1_count}. #{title}"
        when 2
          h2_count += 1
          h3_count = 0
          h4_count = 0
          h5_count = 0
          h6_count = 0
          "## #{h1_count}.#{h2_count} #{title}"
        when 3
          h3_count += 1
          h4_count = 0
          h5_count = 0
          h6_count = 0
          "### #{h1_count}.#{h2_count}.#{h3_count} #{title}"
        when 4
          h4_count += 1
          h5_count = 0
          h6_count = 0
          "#### #{h1_count}.#{h2_count}.#{h3_count}.#{h4_count} #{title}"
        when 5
          h5_count += 1
          h6_count = 0
          "##### #{h1_count}.#{h2_count}.#{h3_count}.#{h4_count}.#{h5_count} #{title}"
        when 6
          h6_count += 1
          "###### #{h1_count}.#{h2_count}.#{h3_count}.#{h4_count}.#{h5_count}.#{h6_count} #{title}"
        else
          match
        end
      end
    end
  end

  # Hook to process posts before rendering
  Jekyll::Hooks.register :posts, :pre_render do |post|
    if post.data['auto_number_headers'] == true
      post.content = HeaderNumbering.number_headers(post.content)
    end
  end

  # Hook to process pages before rendering
  Jekyll::Hooks.register :pages, :pre_render do |page|
    if page.data['auto_number_headers'] == true
      page.content = HeaderNumbering.number_headers(page.content)
    end
  end
end
