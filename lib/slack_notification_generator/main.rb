#!/usr/bin/env ruby

require 'date'
require 'json'

# TODO: fail unless ENV['SLACK_HOOK'] is defined

env =
  case ENV['CI_BRANCH']
  when 'master'
    'Production'
  when 'develop'
    'Staging'
  when /^release/
    'Release'
  else
    'Development'
  end

changelog = []

# get the most recent tag in the current branch
this_tag = 'HEAD'
prev_tag = `git describe --abbrev=0 --tags`.strip

# use the previous tag if we've told it to
if false
  this_tag = prev_tag
  prev_tag = `git describe --abbrev=0 --tags #{this_tag}^`.strip
end

def extract_commits(blob)
  commits = []
  commit = nil
  blob.split("\n").map(&:strip).each do |line|
    case line
    when /^commit ([0-9a-f]+)$/
      commits << commit unless commit.nil?
      commit = { hash: $1[0..6], skip: false }
    when /^Author: ([a-zA-Z]+)/
      commit[:author] = $1.downcase
    when /^Date: +(.*)$/
      commit[:date] = Date.parse($1)
    when /^([A-Z]+-[0-9]+)/
      commit[:issue] = $1
      if line =~ /#time +([0-9][^\s]*)/
        commit[:time] = $1
      end
    else
      commit[:message] ||= line unless line.empty?
      commit[:skip] = true if line =~ /\[skip ci\]/
    end
  end
  commits << commit unless commit.nil?
  commits
end

def add_attachment(store, title, data)
  return if data.nil? || data.length == 0
  # TODO: use UTF symbol for bullet point
  data.map! do |line|
    line.split("\n").map(&:strip).join("\n  ")
  end
  store <<
    {
      title: title,
      text: data.map { |l| "* #{l}" }.join("\n")
    }
end

def format(commit)
  commit[:authors] ||= [commit[:author]].compact
  commit[:issues] ||= [commit[:issue]].compact
  commit[:times] ||= [commit[:time]].compact
  link =
    if commit[:pull]
      if ENV['SLACK_REPO']
        "<[#{ENV['SLACK_REPO']}/pull/#{commit[:pull]}|##{commit[:pull]}>"
      else
        "##{commit[:pull]}"
      end
    else
      if ENV['SLACK_REPO']
        "<[#{ENV['SLACK_REPO']}/commit/#{commit[:hash]}|##{commit[:hash]}>"
      else
        "##{commit[:hash]}"
      end
    end
  issues =
    commit[:issues].map do |issue|
      if ENV['SLACK_JIRA']
        "<[#{ENV['SLACK_JIRA']}/browse/#{issue}|#{issue}"
      else
        issue
      end
    end.join(', ')
  issues ||= "(no issues)"
  time = "(no time)"
  <<-eos
    #{commit[:date]} #{commit[:message]} (#{link})
    #{issues} | #{commit[:authors].join(', ')} | #{time}
  eos
end

commits = []
commit = nil
blob = `git log --merges #{this_tag} ^#{prev_tag}`
blob.split("\n").map(&:strip).each do |line|
  case line
  when /^commit ([0-9a-f]+)$/
    commits << commit unless commit.nil?
    commit = { hash: $1[0..6] }
  when /^Merge: ([a-f0-9]+) ([a-f0-9]+)/
    commit[:range] = ($1..$2)
  when /^Author: ([a-zA-Z]+)/
  when /^Date: +(.*)$/
    commit[:date] = Date.parse($1)
  when /^Merge pull request #([0-9]*) /
    commit[:pull] = $1
  else
    commit[:message] ||= line unless line.empty?
  end
end
commits << commit unless commit.nil?

pull_requests = []
commit_filter = {}
commits.each do |commit|
  next unless commit[:pull]
  blob = `git log --no-merges #{commit[:range].last} ^#{commit[:range].first}`
  commit[:authors] = []
  commit[:issues] = []
  commit[:times] = []
  extract_commits(blob).each do |child|
    commit_filter[child[:hash]] = true
    commit[:authors] << child[:author]
    commit[:issues] << child[:issue] if child[:issue]
    commit[:times] << child[:time] if child[:time]
  end
  commit[:authors].sort!.uniq!
  commit[:issues].sort!.uniq!
  pull_requests << commit
end
pull_requests.map! { |commit| format(commit) }

blob = `git log --no-merges #{this_tag} ^#{prev_tag}`
other_commits = []
extract_commits(blob).each do |commit|
  next if commit_filter[commit[:hash]] || commit[:skip]
  other_commits << commit
end
other_commits.map! { |commit| format(commit) }

attachments = []
add_attachment(attachments, "Pull Requests", pull_requests)
add_attachment(attachments, "Other Commits", other_commits)
exit if attachments.length == 0

payload =
  {
    username: ENV['SLACK_USER'] || 'Notification',
    icon_emoji: ENV['SLACK_ICON'] || ':bell:',
    channel: ENV['SLACK_CHAN'] || '#general',
    text: "*#{[ENV['SLACK_NAME'], env].compact.join(' ')} Release*",
    attachments: attachments
  }

# submit payload to Slack
puts payload.to_json