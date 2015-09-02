#!/usr/bin/env ruby

require 'chronic_duration'
require 'date'
require 'json'

class SlackNotificationGenerator
  def self.run
    unless ENV['SLACK_HOOK']
      puts 'you must define the "SLACK_HOOK" environment variable'
      exit 1
    end

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

    this_tag = 'HEAD'
    prev_tag = `git describe --abbrev=0 --tags`.strip

    if ARGV.select { |arg| arg == "HEAD" }.empty?
      this_tag = prev_tag
      prev_tag = `git describe --abbrev=0 --tags #{this_tag}^`.strip
    end

    server = ARGV.select { |arg| arg != "HEAD" }.first

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
    return if attachments.length == 0

    message = "*#{[ENV['SLACK_NAME'], env].compact.join(' ')} Release*"
    if server
      name = server.gsub(/^http.*\/\//, "").gsub(/\/$/, '')
      message << " (<#{server}|#{name}>)"
    end

    payload =
      {
        username: ENV['SLACK_USER'] || 'Notification',
        icon_emoji: ENV['SLACK_ICON'] || ':bell:',
        channel: ENV['SLACK_CHAN'] || '#general',
        text: message,
        attachments: attachments
      }

    `curl -X POST --data-urlencode 'payload=#{payload.to_json.gsub("'", "'\"'\"'")}' #{ENV['SLACK_HOOK']}`
  end

  def self.extract_commits(blob)
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

  def self.add_attachment(store, title, data)
    return if data.nil? || data.length == 0
    data.map! do |line|
      line.split("\n").map(&:strip).join("\n  ")
    end
    store <<
      {
        title: title,
        text: data.map { |l| "• #{l}" }.join("\n")
      }
  end

  def self.format(commit)
    commit[:authors] ||= [commit[:author]].compact
    commit[:issues] ||= [commit[:issue]].compact
    commit[:times] ||= [commit[:time]].compact
    link =
      if commit[:pull]
        if ENV['SLACK_REPO']
          "<#{ENV['SLACK_REPO']}/pull/#{commit[:pull]}|##{commit[:pull]}>"
        else
          "##{commit[:pull]}"
        end
      else
        if ENV['SLACK_REPO']
          "<#{ENV['SLACK_REPO']}/commit/#{commit[:hash]}|##{commit[:hash]}>"
        else
          "##{commit[:hash]}"
        end
      end
    issues =
      if commit[:issues].empty?
        nil
      else
        commit[:issues].map do |issue|
          if ENV['SLACK_JIRA']
            "<#{ENV['SLACK_JIRA']}/browse/#{issue}|#{issue}>"
          else
            issue
          end
        end.join(', ')
      end
    time =
      if commit[:times].empty?
        nil
      else
        seconds =
          commit[:times].map do |data|
            ChronicDuration.parse(data)
          end.reduce(:+)
        ChronicDuration.output(seconds)
      end
    extras = [issues, commit[:authors].join(', '), time].compact.join(', ')
    commit[:message] = "(no message)" if commit[:message].nil?
    if commit[:message].length > 50
      commit[:message] = commit[:message][0, 50] + "..."
    end
    <<-eos
      #{link} #{commit[:message]} (#{extras})
    eos
  end
end
