#!/usr/bin/env ruby

require 'net/http'
require 'json'


class Commit
	attr_accessor :issue_title, :commit_link, :commit_message, :issue_number, :associated_with

	def initialize(commit)
		number = get_issue_number(commit)
		@issue_number = number if numeric?(number)
		@issue_title = get_issue_title if @issue_number
		@commit_link = get_commit_link(commit)
		@commit_message = get_commit_message(commit)
		@associated_with = @commit_message.split(' ').first.capitalize.gsub(/:$/i, '').gsub(/(s)es$/i,'\1').gsub(/s$/i, '')
	end

	def ==(another_commit)
		@commit_message == another_commit.commit_message
	end

	def to_s
		str = ""
		str << "<p><a href=\"#{@commit_link}\">#{@issue_title||@commit_message}</a>\n"
		str << "<span class='issue'>(<a href=\"https://github.com/jquery/jquery-mobile/issues/#{@issue_number}\">Issue ##{@issue_number}</a>)</span>\n"if @issue_number
		str << " - #{@commit_message}\n" if @commit_message && @issue_number
		str << "</p>\n"
		str
	end

private
	def numeric?(obj)
		Integer(obj) rescue false
	end

	def get_issue_title
		uri = URI.parse("https://api.github.com/repos/jquery/jquery-mobile/issues/#{@issue_number}")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		request = Net::HTTP::Get.new(uri.request_uri)
		response = http.request(request)
		JSON.parse(response.body)['title']
	end

	def get_commit_message(commit)
		commit.gsub(/\*\s*(.*)\(.*/, '\1')
	end

	def get_issue_number(commit)
		commit.gsub(/.*(Closes|Closed|Fixes|Fixed|Fix)(.*issue)?\s*#?([0-9]+).*/, '\3')
	end

	def get_commit_link(commit)
		commit.gsub(/.*,\s*\[(.*)\s+\w+\]\)/, '\1')
	end

end

branch1 = ARGV[0]
branch2 = ARGV[1]

if !branch1
	puts "To use, give up to 2 arguments, these being the branches that you would like to compare, make sure to output to an html file by typing > <filename>.html"
	exit
end

branches = "remotes/origin/#{branch1}..."
if branch2
	branches << branch2
end

format_ticket='[https://github.com/jquery/jquery-mobile/issues/XXXX #XXXX]'
format_commit='[http://github.com/jquery/jquery-mobile/commit/%H %h]'
formatted_commits = `git whatchanged #{branches} --pretty=format:"* %s (#{format_ticket}, #{format_commit})"`
formatted_commits = formatted_commits.gsub(/^:.*$/, '').gsub(/^\s+$/,'').split(/(\n|\r)/).reject { |x| x =~ /\A\s*\z/ }

#<p><a href="COMMIT_LINK">ISSUE_TITLE</a> (<a href="https://github.com/jquery/jquery-mobile/issues/ISSUE_NUMBER">Issue #ISSUE_NUMBER</a>) - COMMIT_COMMENT
commits = []
formatted_commits.each do |fc|
	commits << Commit.new(fc)
end
commits.sort!{ |a,b| a.commit_message <=> b.commit_message }

File.open("#{branch1}.html", 'w') do |f|
	topic = ""
	commits.each do |commit|
		if topic != commit.associated_with
			topic = commit.associated_with
			f.write("<h3 class=\"widget-header\">#{topic}</h3>\n")
		end
		f.write(commit)
	end
end
