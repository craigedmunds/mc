desc 'Campaign related tasks'
command :campaigns do |c|
  c.desc 'Get the content (both html and text) for a campaign either as it would appear in the campaign archive or as the raw, original content'
  c.command :content do |s|
    s.desc 'Select view type - [archive], preview, or raw'
    s.flag :view

    s.desc 'Select the format - [html, text]'
    s.flag :output
    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", args.first)
      view = required_option(:view, options[:view], "archive")
      email = ""

      results = @mailchimp_cached.campaigns_content(:cid => cid, :options => {:view => view, :email => email})

      if options[:output] == 'html'
        puts results['html']
      elsif options[:output] == 'text'
        puts results['text']
      else
        @output.as_hash results
      end
    end
  end

  c.desc 'Create Campaign'
  c.command :create do |s|
    #TODO: support absplit, rss, auto campaign types
    s.desc 'Type of campaign to create: regular, plaintext'
    s.flag :type, :default_value => 'regular'

    s.desc 'List ID'
    s.flag [:id]

    s.desc 'Subject'
    s.flag [:subject]

    s.desc 'From email'
    s.flag ['from-email']

    s.desc 'From name'
    s.flag ['from-name']

    s.desc 'To name'
    s.flag ['to-name']

    s.desc 'Template ID'
    s.flag 'template-id'

    s.desc 'Gallery template ID'
    s.flag ['gallery-template-id']

    s.desc 'Base template ID'
    s.flag ['base-template-id']

    s.desc 'Folder ID'
    s.flag ['folder-id']

    #s.desc 'Tracking'
    #s.flag [:tracking]

    s.desc 'Title - internal name to use'
    s.flag [:title]

    s.desc 'authenticate'
    s.switch :authenticate, :negatable => true

    #s.desc 'Analytics'
    #s.flag [:analytics]

    s.desc 'Auto footer?'
    s.switch 'auto-footer'

    s.desc 'Enable inline css?'
    s.switch 'inline-css', :negatable => false

    s.desc 'Auto tweet?'
    s.switch :tweet, :negatable => false

    #s.desc 'Auto FB post'
    #s.flag 'auto-fb-post'

    s.desc 'FB comments?'
    s.switch 'fb-comments', :negatable => false

    s.desc 'Enable timewarp'
    s.switch :timewarp, :negatable => false

    s.desc 'HTML filename to load'
    s.flag 'html-filename'

    s.desc 'TXT filename to load'
    s.flag 'text-filename'

    s.desc 'segmentation options [NAME,VALUE]'
    s.flag 'seg-options'

    s.desc 'saved-segment-id VALUE'
    s.flag 'saved-segment-id'
    
    s.action do |global,options,args|
      if options[:"saved-segment-id"]
        segment_opts = {:saved_segment_id => options[:"saved-segment-id"]
      elsif options[:seg_options]
        field, value = options[:seg_options].split(",") if options[:seg_options]
        segment_conditions = [{:field => field, :op => "like", :value => value}]
        segment_opts = {:match => "all", :conditions => segment_conditions}
      
      end

      type = options[:type]

      standard_opts = {
        :list_id => required_option(:id, options[:id], global[:list]),
        :subject => required_option(:subject, options[:subject]),
        :from_email => required_option('from-email', options['from-email']),
        :from_name => required_option('from-name', options['from-name']),
        :to_name => options['to-name'],
        :template_id => options['template-id'],
        :gallery_template_id => options['gallery-template-id'],
        :base_template_id => options['base-template-id'],
        :folder => options['folder-id'],
        :inline_css => true,
        :tracking => {:opens => true, :html_clicks => true, :text_clicks => false},
        :title => options['title'],
        :authenticate => options[:authenticate],
        #:analytics
        :auto_footer => options['auto-footer'],
        :inline_css => options['inline-css'],
        :generate_text => options['generate-text'],
        :auto_tweet => options['auto-tweet'],
        :auto_fb_post => options['auto-fb-posts'],
        :fb_comments => options['fb-comments'],
        :timewarp => options[:timewarp],
        :ecomm360 => options[:ecomm360]
        #:crm_tracking
      }

      html = File.open(options['html-filename']).read if options['html-filename']
      text = File.open(options['text-filename']).read if options['text-filename']
      content = {
        :html => html,
        :text => text
      }

      type_opts = {}

      campaign = @mailchimp.campaigns_create(:type => type, :options => standard_opts, :content => content, :segment_opts => segment_opts, :type_opts => type_opts)
      puts "Created new campaign with id = #{campaign['id']}"
    end
  end

  c.desc 'Delete Campaign'
  c.command :delete do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", options[:cid])
      print "Deleting campaign #{cid}... "
      @mailchimp.campaigns_send_test(:cid=> cid)["complete"] ? puts("done!") : puts("ut oh, no can do!")
    end
  end

  c.desc 'Get the list of campaigns and their details matching the specified filters'
  c.command :list do |s|
    s.desc 'List ID'
    s.flag :list
    s.desc "Return campaigns of a specific status - 'sent', 'saved', 'paused', 'schedule', 'sending'"
    s.flag :status
    s.desc "Return campaigns of a specific type - 'regular', 'plaintext', 'absplit', 'rss', 'auto'"
    s.flag :type
    s.desc 'Number of campaigns to display'
    s.flag :limit, :default_value => 50

    # s.switch :first
    # s.flag :start, :default_value => 0
    # s.flag :sort_field, :default_value => 'create_time'
    # s.flag :sort_dir, :default_value => 'DESC'

    s.action do |global,options,args|
      #by design not including global[:list], although that goes against norm. however,
      #seems to not fit well with this command and not possible to negate it
      results = @mailchimp_cached.campaigns_list(:limit => options[:limit], :filters => {:list_id => options[:list], :status => options[:status], :type => options[:type]})
      @output.standard results['data'], :fields => [:id, :title, :status, :send_time, :emails_sent, :archive_url]
    end
  end

  c.desc 'Check to see if campaign is ready to send'
  c.command :ready do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.desc 'Use last created campaign id'
    s.switch [:lcid, 'use-last-campaign-id'], :negatable => false

    s.action do |global,options,args|
      cid = required_option(:cid, options[:cid], get_last_campaign_id(options[:lcid]))
      puts cid

      @output.standard @mailchimp_cached.campaigns_ready(:cid=> cid)
    end
  end

  c.desc 'Replicate a campaign.'
  c.command :replicate do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", args.first)

      @output.as_hash @mailchimp_cached.campaigns_replicate(:cid=> cid)
    end
  end

  c.desc 'Resume sending an AutoResponder or RSS campaign'
  c.command :resume do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", args.first)

      @output.as_raw @mailchimp_cached.campaigns_resume(:cid=> cid)
    end
  end

  c.desc 'Schedule a campaign to be sent in batches sometime in the future'
  c.command 'schedule-batch' do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.desc 'Date to schedule campaign in YYYY-MM-DD format'
    s.flag :date

    s.desc 'Time to schedule campaign at in HH:MM:SS format'
    s.flag :time

    s.desc 'Number of batches to send (2 - 26)'
    s.flag :batches, :default_value => 2

    s.desc 'Number of minutes between each batch (5, 10, 15, 20, 25, 30, 60)'
    s.flag :stagger, :default_value => 5

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", options[:cid])
      date = required_option(:date, options[:date])
      time = required_option(:time, options[:time])

      puts @mailchimp.campaigns_schedule(:cid => cid, :schedule_time => date + ' ' + time, :num_batches => options[:batches], :stagger_mins => options[:stagger])
    end
  end

  c.desc 'Schedule Campaign'
  c.command :schedule do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.desc 'Date to schedule campaign in YYYY-MM-DD format'
    s.flag :date, :default_value => (Time.now + 86400).strftime("%Y-%m-%d")

    s.desc 'Time to schedule campaign at in HH:MM:SS format'
    s.flag :time, :default_value => '08:00:00'

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", options[:cid])
      puts @mailchimp.campaigns_schedule(:cid => cid, :schedule_time => options[:date] + ' ' + options[:time])
    end
  end

  c.desc 'Allows one to test their segmentation rules before creating a campaign using them'
  c.command "segment-test" do |s|
    s.desc 'List ID'
    s.flag :id

    s.desc "Use either 'any' or 'all'"
    s.flag :match, :default_value => 'all'

    s.desc 'Condition in the format field,op,value'
    s.flag :condition

    s.action do |global,options,args|
      id = required_option(:id, options[:id], global[:list])
      match = required_option(:match, options[:match])
      condition = required_option(:condition, options[:condition])

      segment = {}
      segment['match'] = match
      field, op, value = options[:condition].split(',')
      segment['conditions'] = [{:field => field, :op => op, :value => value}]

      puts @mailchimp.campaigns_segment_test(:list_id => id, :options => segment)
    end
  end

  c.desc 'Send Campaign Now'
  c.command :send do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", options[:cid])
      print "Sending campaign #{cid}... "
      @mailchimp.campaigns_send(:cid => cid)["complete"] ? puts("done!") : puts("ut oh, no can do!")
    end
  end

  c.desc 'Send Test Campaign'
  c.command 'send-test' do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", options[:cid])
      emails = required_argument("Need to supply at least one email to send test campaign to.", args)

      print "Sending test for campaign #{cid}... "
      @mailchimp.campaigns_send_test(:cid=> cid, :test_emails => emails)["complete"] ? puts("done!") : puts("ut oh, no can do!")
    end
  end

  c.desc 'Unschedule a campaign that is scheduled to be sent in the future'
  c.command :unschedule do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", args.first)

      @output.as_raw @mailchimp_cached.campaigns_unschedule(:cid=> cid)
    end
  end

  c.desc 'Get the HTML template content sections for a campaign'
  c.command 'template-content' do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", args.first)

      @output.as_hash @mailchimp_cached.campaigns_template_content(:cid=> cid)
    end
  end

  c.desc 'Update just about any setting besides type for a campaign that has not been sent'
  c.command :update do |s|
    s.desc 'Campaign ID'
    s.flag :cid

    s.desc 'Parameter name to change'
    s.flag :name

    s.desc 'Value to set parameter to'
    s.flag :value

    s.action do |global,options,args|
      cid = required_argument("Need to supply a campaign id", args.first)
      name = required_option(:name, options[:name])
      value = required_option(:value, options[:value])

      @output.as_hash @mailchimp.campaigns_update(:cid=> cid, :name => name, :value => value)
    end
  end
end
